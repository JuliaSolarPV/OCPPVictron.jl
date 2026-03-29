@testsnippet IntegrationSetup begin
    using OCPPVictron
    using OCPPClient
    using OCPPData
    using OCPPServer
    using Dates

    """
    Start the OCPPVictron bridge without MQTT (for testing OCPP side only).
    Returns (state, port) where port is the OCPP server port.
    """
    function start_test_bridge(; port = 0)
        dir = mktempdir()
        config_path = joinpath(dir, "test.toml")

        config = OCPPVictron.BridgeConfig(; ocpp_port = port, config_path = config_path)
        OCPPVictron.save_config!(config)

        # Reload to match normal startup path
        config = OCPPVictron.load_config(config_path)

        cs = OCPPServer.CentralSystem(;
            port = config.ocpp_port,
            supported_versions = [Symbol(config.ocpp_version)],
        )

        state = OCPPVictron.BridgeState(
            Dict{String,OCPPVictron.ChargerState}(),
            Dict{String,OCPPVictron.VictronDevice}(),
            cs,
            nothing,  # no MQTT in tests
            config,
            0,
            ReentrantLock(),
        )

        OCPPVictron.register_ocpp_handlers!(cs, state)
        OCPPVictron.wire_events!(state)

        # Start OCPP server
        @async OCPPServer.start!(cs)
        sleep(0.5)  # let server bind

        # Get actual port
        actual_port = cs.config.port
        return state, actual_port, dir
    end

    function stop_test_bridge(state)
        try
            OCPPServer.stop!(state.central_system)
        catch
        end
    end

    function wait_for_cp(cp, target_status; timeout = 10.0)
        deadline = time() + timeout
        while cp.status != target_status && time() < deadline
            sleep(0.05)
        end
        return cp.status == target_status
    end
end

@testitem "Charger connects and auto-approved in config" tags = [:integration, :slow] setup =
    [IntegrationSetup] begin
    state, port, dir = start_test_bridge(; port = 9100)
    try
        cp = OCPPClient.ChargePoint(
            "test-wb-01",
            "ws://127.0.0.1:$port/ocpp";
            reconnect = false,
        )
        @async OCPPClient.connect!(cp)
        @test wait_for_cp(cp, :connected)

        # Boot
        resp = OCPPClient.boot_notification(
            cp;
            charge_point_vendor = "TestVendor",
            charge_point_model = "TestModel",
        )
        @test resp.status == OCPPData.V16.RegistrationAccepted

        sleep(0.3)

        # Verify charger was auto-approved in config
        @test length(state.config.chargers) == 1
        @test state.config.chargers[1].charge_point_id == "test-wb-01"
        @test state.config.chargers[1].service_name == "ev1"

        # Verify config persisted to disk
        loaded = OCPPVictron.load_config(joinpath(dir, "test.toml"))
        @test length(loaded.chargers) == 1
        @test loaded.chargers[1].charge_point_id == "test-wb-01"

        # Verify charger state
        @test haskey(state.chargers, "test-wb-01")
        cs = state.chargers["test-wb-01"]
        @test cs.vendor == "TestVendor"
        @test cs.model == "TestModel"

        # Verify VictronDevice created
        @test haskey(state.devices, "test-wb-01")
        @test state.devices["test-wb-01"].service_name == "ev1"

        OCPPClient.disconnect!(cp)
        sleep(0.3)

        # After disconnect, charger removed from live state
        @test !haskey(state.chargers, "test-wb-01")
        @test !haskey(state.devices, "test-wb-01")
    finally
        stop_test_bridge(state)
    end
end

@testitem "Multiple chargers get unique service names" tags = [:integration, :slow] setup =
    [IntegrationSetup] begin
    state, port, dir = start_test_bridge(; port = 9101)
    try
        cp1 = OCPPClient.ChargePoint("wb-A", "ws://127.0.0.1:$port/ocpp"; reconnect = false)
        cp2 = OCPPClient.ChargePoint("wb-B", "ws://127.0.0.1:$port/ocpp"; reconnect = false)

        @async OCPPClient.connect!(cp1)
        @test wait_for_cp(cp1, :connected)
        OCPPClient.boot_notification(
            cp1;
            charge_point_vendor = "V1",
            charge_point_model = "M1",
        )
        sleep(0.2)

        @async OCPPClient.connect!(cp2)
        @test wait_for_cp(cp2, :connected)
        OCPPClient.boot_notification(
            cp2;
            charge_point_vendor = "V2",
            charge_point_model = "M2",
        )
        sleep(0.2)

        # Both chargers in state
        @test haskey(state.chargers, "wb-A")
        @test haskey(state.chargers, "wb-B")

        # Unique service names
        @test state.devices["wb-A"].service_name == "ev1"
        @test state.devices["wb-B"].service_name == "ev2"

        # Both in config
        @test length(state.config.chargers) == 2

        OCPPClient.disconnect!(cp1)
        OCPPClient.disconnect!(cp2)
    finally
        stop_test_bridge(state)
    end
end

@testitem "Full charging session updates state correctly" tags = [:integration, :slow] setup =
    [IntegrationSetup] begin
    state, port, dir = start_test_bridge(; port = 9102)
    try
        cp = OCPPClient.ChargePoint(
            "charge-test",
            "ws://127.0.0.1:$port/ocpp";
            reconnect = false,
        )
        @async OCPPClient.connect!(cp)
        @test wait_for_cp(cp, :connected)

        # Boot
        OCPPClient.boot_notification(
            cp;
            charge_point_vendor = "TestCo",
            charge_point_model = "Wallbox7",
        )
        sleep(0.2)

        # StatusNotification: Available
        OCPPClient.status_notification(
            cp;
            connector_id = 1,
            status = OCPPData.V16.ChargePointAvailable,
            error_code = OCPPData.V16.NoError,
        )
        sleep(0.2)
        cs = state.chargers["charge-test"]
        @test cs.ocpp_status == :Available

        # StartTransaction
        resp = OCPPClient.start_transaction(
            cp;
            connector_id = 1,
            id_tag = "USER01",
            meter_start = 0,
        )
        tx_id = resp.transaction_id
        @test tx_id > 0
        sleep(0.2)

        cs = state.chargers["charge-test"]
        @test cs.active_transaction_id == tx_id
        @test cs.id_tag == "USER01"
        @test cs.ocpp_status == :Charging

        # StatusNotification: Charging
        OCPPClient.status_notification(
            cp;
            connector_id = 1,
            status = OCPPData.V16.ChargePointCharging,
            error_code = OCPPData.V16.NoError,
        )
        sleep(0.2)
        cs = state.chargers["charge-test"]
        @test cs.ocpp_status == :Charging

        # MeterValues
        sampled = [
            OCPPData.V16.SampledValue(;
                value = "7200",
                measurand = OCPPData.V16.MeasurandPowerActiveImport,
                unit = OCPPData.V16.UnitW,
            ),
            OCPPData.V16.SampledValue(;
                value = "31.3",
                measurand = OCPPData.V16.MeasurandCurrentImport,
                unit = OCPPData.V16.UnitA,
            ),
            OCPPData.V16.SampledValue(;
                value = "1500",
                measurand = OCPPData.V16.MeasurandEnergyActiveImportRegister,
                unit = OCPPData.V16.UnitWh,
            ),
        ]
        mv = OCPPData.V16.MeterValue(;
            timestamp = Dates.format(now(UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ"),
            sampled_value = sampled,
        )
        OCPPClient.meter_values(cp; connector_id = 1, meter_value = [mv])
        sleep(0.2)

        cs = state.chargers["charge-test"]
        @test cs.power_w == 7200.0
        @test cs.current_a == 31.3
        @test cs.energy_wh == 1500.0

        # Verify Victron attribute mapping
        attrs = OCPPVictron.victron_attributes(cs)
        @test attrs["Status"] == 2  # Charging
        @test attrs["Ac/Power"] == 7200.0
        @test attrs["Current"] == 31.3
        @test attrs["Ac/Energy/Forward"] == 1500.0
        @test attrs["ChargingTime"] > 0

        # StopTransaction
        OCPPClient.stop_transaction(cp; transaction_id = tx_id, meter_stop = 1500)
        sleep(0.2)

        cs = state.chargers["charge-test"]
        @test cs.active_transaction_id === nothing
        @test cs.ocpp_status == :Available
        @test cs.energy_wh == 1500.0  # meter_stop - meter_start

        OCPPClient.disconnect!(cp)
    finally
        stop_test_bridge(state)
    end
end

@testitem "Heartbeat updates last_seen" tags = [:integration, :slow] setup =
    [IntegrationSetup] begin
    state, port, dir = start_test_bridge(; port = 9103)
    try
        cp = OCPPClient.ChargePoint(
            "hb-test",
            "ws://127.0.0.1:$port/ocpp";
            reconnect = false,
        )
        @async OCPPClient.connect!(cp)
        @test wait_for_cp(cp, :connected)

        OCPPClient.boot_notification(
            cp;
            charge_point_vendor = "V",
            charge_point_model = "M",
        )
        sleep(0.2)

        before = state.chargers["hb-test"].last_seen
        sleep(0.1)

        resp = OCPPClient.heartbeat(cp)
        @test hasproperty(resp, :current_time)
        sleep(0.2)

        after = state.chargers["hb-test"].last_seen
        @test after > before

        OCPPClient.disconnect!(cp)
    finally
        stop_test_bridge(state)
    end
end
