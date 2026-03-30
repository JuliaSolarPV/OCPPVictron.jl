module OCPPVictron

using Dates
using JSON
using TOML
using HTTP
using MQTTClient
using OCPPServer
using OCPPData
using SQLite
using DBInterface

export start, stop!

# Helpers
_now_iso() = Dates.format(now(UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ")

# Config
include("config.jl")

# Types
include("types.jl")

# OCPP → Victron mapping (pure functions)
include("mapping.jl")

# Victron MQTT integration
include("victron_mqtt.jl")

# OCPP handlers
include("handlers.jl")

# Event wiring
include("wiring.jl")

# Storage (SQLite)
include("storage/database.jl")
include("storage/transactions.jl")
include("storage/meter_values.jl")
include("storage/event_log.jl")

# REST + WebSocket API
include("api.jl")

"""
    start(; config_path="ocppvictron.toml", api_port=8080, db_path="ocppvictron.sqlite", kwargs...)

Start the OCPP-to-Victron bridge with REST/WebSocket API.

Loads (or creates) the config file, starts the OCPP WebSocket server,
connects to the Venus OS MQTT broker, and starts the HTTP API server.
"""
function start(;
    config_path::String = "ocppvictron.toml",
    api_port::Int = 8080,
    db_path::String = "ocppvictron.sqlite",
    kwargs...,
)
    # 1. Load or create config
    config = load_config(config_path)

    # Override config with kwargs
    for (k, v) in kwargs
        if hasproperty(config, k)
            setproperty!(config, k, v)
        end
    end

    # 2. Create OCPP server
    cs = OCPPServer.CentralSystem(;
        host = config.ocpp_host,
        port = config.ocpp_port,
        supported_versions = [Symbol(config.ocpp_version)],
    )

    # 3. Create bridge state
    state = BridgeState(
        Dict{String,ChargerState}(),
        Dict{String,VictronDevice}(),
        cs,
        nothing,  # mqtt_client set by connect_mqtt!
        config,
        0,        # tx_counter
        Dict{String,Vector{MeterSample}}(),
        nothing,  # db_path
        ReentrantLock(),
    )

    # 4. Register OCPP handlers
    register_ocpp_handlers!(cs, state)

    # 5. Wire events
    wire_events!(state)

    # 6. Connect MQTT (optional)
    mqtt_ok = try
        connect_mqtt!(state)
        true
    catch
        @warn "MQTT unavailable ($(config.mqtt_host):$(config.mqtt_port)), continuing without Victron integration"
        false
    end

    # 7. Initialize database and sync tx counter
    init_db!(; path = db_path)
    state.db_path = db_path
    state.tx_counter = max_transaction_id()

    # 8. Start OCPP server
    @async OCPPServer.start!(cs)

    # 9. Start REST/WebSocket API
    start_api!(state; port = api_port)

    @info "OCPPVictron bridge running"
    @info "  OCPP server: ws://$(config.ocpp_host):$(config.ocpp_port)/ocpp/<charger_id>"
    @info "  MQTT broker: $(config.mqtt_host):$(config.mqtt_port) $(mqtt_ok ? "(connected)" : "(unavailable)")"
    @info "  API server:  http://localhost:$(api_port)"
    @info "  Config file: $(config.config_path)"

    return nothing
end

"""
    stop!(state::BridgeState)

Stop the OCPP-to-Victron bridge.
"""
function stop!(state::BridgeState)
    disconnect_mqtt!(state)
    OCPPServer.stop!(state.central_system)
    @info "OCPPVictron bridge stopped"
    return nothing
end

end # module
