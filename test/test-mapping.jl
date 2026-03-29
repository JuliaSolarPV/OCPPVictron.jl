@testitem "victron_status maps OCPP statuses correctly" tags = [:unit, :fast] begin
    using OCPPVictron

    # Connected (1)
    @test OCPPVictron.victron_status(:Available) == 1
    @test OCPPVictron.victron_status(:Preparing) == 1
    @test OCPPVictron.victron_status(:Reserved) == 1

    # Charging (2)
    @test OCPPVictron.victron_status(:Charging) == 2

    # Charged (3)
    @test OCPPVictron.victron_status(:SuspendedEVSE) == 3
    @test OCPPVictron.victron_status(:SuspendedEV) == 3
    @test OCPPVictron.victron_status(:Finishing) == 3

    # Disconnected (0)
    @test OCPPVictron.victron_status(:Unavailable) == 0
    @test OCPPVictron.victron_status(:Faulted) == 0

    # Unknown defaults to 0
    @test OCPPVictron.victron_status(:SomethingUnknown) == 0
end

@testitem "victron_attributes returns correct keys and values" tags = [:unit, :fast] begin
    using OCPPVictron
    using Dates

    charger = OCPPVictron.ChargerState(;
        id = "test-charger",
        ocpp_status = :Charging,
        power_w = 7200.0,
        current_a = 31.3,
        energy_wh = 5000.0,
        l1_power_w = 2400.0,
        l2_power_w = 2400.0,
        l3_power_w = 2400.0,
        transaction_start_time = now(UTC) - Second(120),
    )

    attrs = OCPPVictron.victron_attributes(charger)

    @test attrs["Status"] == 2  # Charging
    @test attrs["Ac/Power"] == 7200.0
    @test attrs["Current"] == 31.3
    @test attrs["Ac/Energy/Forward"] == 5000.0
    @test attrs["Ac/L1/Power"] == 2400.0
    @test attrs["Ac/L2/Power"] == 2400.0
    @test attrs["Ac/L3/Power"] == 2400.0
    @test attrs["ChargingTime"] >= 119  # at least 119 seconds (timing tolerance)
    @test attrs["ChargingTime"] <= 122
end

@testitem "victron_attributes with no transaction" tags = [:unit, :fast] begin
    using OCPPVictron

    charger = OCPPVictron.ChargerState(; id = "idle-charger", ocpp_status = :Available)

    attrs = OCPPVictron.victron_attributes(charger)
    @test attrs["Status"] == 1
    @test attrs["ChargingTime"] == 0
    @test attrs["Ac/Power"] == 0.0
end

@testitem "update_from_meter_values! parses power and energy" tags = [:unit, :fast] begin
    using OCPPVictron

    charger = OCPPVictron.ChargerState(; id = "test")

    # Simulate MeterValue with SampledValues as NamedTuples
    # (matches how OCPPData dynamic types behave with hasproperty/getproperty)
    meter_values = [(
        timestamp = "2024-01-01T00:00:00Z",
        sampled_value = [
            (value = "7200", measurand = "Power.Active.Import", unit = "W"),
            (value = "31.3", measurand = "Current.Import", unit = "A"),
            (value = "5.0", measurand = "Energy.Active.Import.Register", unit = "kWh"),
            (value = "2400", measurand = "Power.Active.Import", unit = "W", phase = "L1-N"),
        ],
    ),]

    OCPPVictron.update_from_meter_values!(charger, meter_values)

    @test charger.power_w == 7200.0
    @test charger.current_a == 31.3
    @test charger.energy_wh == 5000.0  # 5.0 kWh → 5000 Wh
    @test charger.l1_power_w == 2400.0
end

@testitem "update_from_meter_values! handles kW unit conversion" tags = [:unit, :fast] begin
    using OCPPVictron

    charger = OCPPVictron.ChargerState(; id = "test")

    meter_values = [(
        timestamp = "2024-01-01T00:00:00Z",
        sampled_value = [(value = "7.2", measurand = "Power.Active.Import", unit = "kW"),],
    )]

    OCPPVictron.update_from_meter_values!(charger, meter_values)
    @test charger.power_w == 7200.0
end

@testitem "update_from_meter_values! handles missing optional fields" tags = [:unit, :fast] begin
    using OCPPVictron

    charger = OCPPVictron.ChargerState(; id = "test")

    # SampledValue with only value field (no measurand, no unit, no phase)
    # Should default to Energy.Active.Import.Register in Wh
    meter_values =
        [(timestamp = "2024-01-01T00:00:00Z", sampled_value = [(value = "1234",)])]

    OCPPVictron.update_from_meter_values!(charger, meter_values)
    @test charger.energy_wh == 1234.0
end
