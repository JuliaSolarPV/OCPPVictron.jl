@testitem "load_config creates default file when missing" tags = [:unit, :fast] begin
    using OCPPVictron

    mktempdir() do dir
        path = joinpath(dir, "test.toml")
        config = OCPPVictron.load_config(path)

        @test isfile(path)
        @test config.ocpp_port == 9000
        @test config.mqtt_host == "127.0.0.1"
        @test config.mqtt_port == 1883
        @test config.auto_authorize == true
        @test isempty(config.chargers)
        @test config.config_path == path
    end
end

@testitem "save_config! and load_config round-trip" tags = [:unit, :fast] begin
    using OCPPVictron

    mktempdir() do dir
        path = joinpath(dir, "test.toml")
        config = OCPPVictron.BridgeConfig(;
            ocpp_port = 9001,
            mqtt_host = "10.0.0.1",
            mqtt_port = 1884,
            heartbeat_interval = 120,
            auto_authorize = false,
            chargers = [
                OCPPVictron.ChargerConfig(;
                    charge_point_id = "wb-01",
                    service_name = "ev1",
                    enabled = true,
                ),
                OCPPVictron.ChargerConfig(;
                    charge_point_id = "wb-02",
                    service_name = "ev2",
                    enabled = false,
                ),
            ],
            config_path = path,
        )
        OCPPVictron.save_config!(config)

        loaded = OCPPVictron.load_config(path)
        @test loaded.ocpp_port == 9001
        @test loaded.mqtt_host == "10.0.0.1"
        @test loaded.mqtt_port == 1884
        @test loaded.heartbeat_interval == 120
        @test loaded.auto_authorize == false
        @test length(loaded.chargers) == 2
        @test loaded.chargers[1].charge_point_id == "wb-01"
        @test loaded.chargers[1].service_name == "ev1"
        @test loaded.chargers[1].enabled == true
        @test loaded.chargers[2].charge_point_id == "wb-02"
        @test loaded.chargers[2].enabled == false
    end
end

@testitem "next_service_name increments correctly" tags = [:unit, :fast] begin
    using OCPPVictron

    # Empty config → ev1
    config = OCPPVictron.BridgeConfig()
    @test OCPPVictron.next_service_name(config) == "ev1"

    # With ev1 → ev2
    push!(
        config.chargers,
        OCPPVictron.ChargerConfig(; charge_point_id = "a", service_name = "ev1"),
    )
    @test OCPPVictron.next_service_name(config) == "ev2"

    # With ev1 and ev3 → ev4 (fills gaps? no, takes max+1)
    push!(
        config.chargers,
        OCPPVictron.ChargerConfig(; charge_point_id = "b", service_name = "ev3"),
    )
    @test OCPPVictron.next_service_name(config) == "ev4"
end

@testitem "find_charger returns correct result" tags = [:unit, :fast] begin
    using OCPPVictron

    config = OCPPVictron.BridgeConfig(;
        chargers = [
            OCPPVictron.ChargerConfig(; charge_point_id = "wb-01", service_name = "ev1"),
        ],
    )

    found = OCPPVictron.find_charger(config, "wb-01")
    @test found !== nothing
    @test found.service_name == "ev1"

    @test OCPPVictron.find_charger(config, "nonexistent") === nothing
end

@testitem "add_charger! auto-approves and persists" tags = [:unit, :fast] begin
    using OCPPVictron

    mktempdir() do dir
        path = joinpath(dir, "test.toml")
        config = OCPPVictron.BridgeConfig(; config_path = path)
        OCPPVictron.save_config!(config)

        entry = OCPPVictron.add_charger!(config, "new-charger")
        @test entry.charge_point_id == "new-charger"
        @test entry.service_name == "ev1"
        @test entry.enabled == true
        @test length(config.chargers) == 1

        # Adding same ID again returns existing
        entry2 = OCPPVictron.add_charger!(config, "new-charger")
        @test entry2.service_name == "ev1"
        @test length(config.chargers) == 1

        # Second charger gets ev2
        entry3 = OCPPVictron.add_charger!(config, "another-charger")
        @test entry3.service_name == "ev2"
        @test length(config.chargers) == 2

        # Verify persisted to disk
        loaded = OCPPVictron.load_config(path)
        @test length(loaded.chargers) == 2
    end
end
