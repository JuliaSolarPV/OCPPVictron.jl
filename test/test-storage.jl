@testitem "init_db! creates tables" tags = [:unit, :fast] begin
    using OCPPVictron

    mktempdir() do dir
        path = joinpath(dir, "test.sqlite")
        db = OCPPVictron.init_db!(; path)
        @test db isa OCPPVictron.SQLite.DB
        @test isfile(path)
    end
end

@testitem "create and complete transaction" tags = [:unit, :fast] begin
    using OCPPVictron

    mktempdir() do dir
        path = joinpath(dir, "test.sqlite")
        OCPPVictron.init_db!(; path)

        tx_id = OCPPVictron.create_transaction!(;
            charger_id = "wb-01",
            connector_id = 1,
            id_tag = "USER01",
            meter_start = 1000,
            timestamp = "2024-01-01T00:00:00Z",
            tx_id = 1,
        )
        @test tx_id == 1

        # List active
        txs = OCPPVictron.list_transactions(; status = "active")
        @test length(txs) == 1
        @test txs[1].charger_id == "wb-01"
        @test txs[1].id_tag == "USER01"

        @test OCPPVictron.count_active_transactions() == 1

        # Complete
        OCPPVictron.complete_transaction!(;
            transaction_id = 1,
            meter_stop = 2500,
            timestamp = "2024-01-01T01:00:00Z",
        )

        txs = OCPPVictron.list_transactions(; status = "completed")
        @test length(txs) == 1
        @test txs[1].energy_wh == 1500.0
        @test OCPPVictron.count_active_transactions() == 0
    end
end

@testitem "insert and query meter values" tags = [:unit, :fast] begin
    using OCPPVictron

    mktempdir() do dir
        path = joinpath(dir, "test.sqlite")
        OCPPVictron.init_db!(; path)

        OCPPVictron.insert_meter_value!(;
            charger_id = "wb-01",
            timestamp = "2024-01-01T00:00:00Z",
            power_w = 7200.0,
            current_a = 31.3,
            energy_wh = 5000.0,
        )

        vals = OCPPVictron.get_meter_values(; charger_id = "wb-01")
        @test length(vals) == 1
        @test vals[1].power_w == 7200.0
        @test vals[1].current_a == 31.3
    end
end

@testitem "log and query events" tags = [:unit, :fast] begin
    using OCPPVictron

    mktempdir() do dir
        path = joinpath(dir, "test.sqlite")
        OCPPVictron.init_db!(; path)

        OCPPVictron.log_event!(;
            charger_id = "wb-01",
            level = "info",
            message = "Charger connected",
        )
        OCPPVictron.log_event!(;
            charger_id = "wb-01",
            level = "warn",
            message = "Heartbeat delayed",
        )

        events = OCPPVictron.recent_events()
        @test length(events) == 2

        warn_events = OCPPVictron.recent_events(; level = "warn")
        @test length(warn_events) == 1
        @test warn_events[1].message == "Heartbeat delayed"
    end
end

@testitem "MeterSample ring buffer" tags = [:unit, :fast] begin
    using OCPPVictron
    using Dates

    history = Dict{String,Vector{OCPPVictron.MeterSample}}()

    # Push samples
    for i = 1:10
        sample =
            OCPPVictron.MeterSample(now(UTC), Float64(i * 1000), Float64(i), 0.0, 0.0, 0.0)
        OCPPVictron.push_meter_sample!(history, "wb-01", sample)
    end

    @test length(history["wb-01"]) == 10

    # Push beyond buffer size
    for i = 1:OCPPVictron.METER_HISTORY_SIZE
        sample = OCPPVictron.MeterSample(now(UTC), 0.0, 0.0, 0.0, 0.0, 0.0)
        OCPPVictron.push_meter_sample!(history, "wb-01", sample)
    end

    @test length(history["wb-01"]) == OCPPVictron.METER_HISTORY_SIZE
end
