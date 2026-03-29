module OCPPVictron

using Dates
using JSON
using TOML
using MQTTClient
using OCPPServer
using OCPPData

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

"""
    start(; config_path="ocppvictron.toml", kwargs...) → BridgeState

Start the OCPP-to-Victron bridge.

Loads (or creates) the config file, starts the OCPP WebSocket server,
and connects to the Venus OS MQTT broker. Chargers that connect via OCPP
will appear as EV charger devices on the Victron system.

Any keyword arguments override values from the config file.
"""
function start(; config_path::String = "ocppvictron.toml", kwargs...)
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
        ReentrantLock(),
    )

    # 4. Register OCPP handlers
    register_ocpp_handlers!(cs, state)

    # 5. Wire events
    wire_events!(state)

    # 6. Connect MQTT
    connect_mqtt!(state)

    # 7. Start OCPP server
    @async OCPPServer.start!(cs)

    @info "OCPPVictron bridge running"
    @info "  OCPP server: ws://$(config.ocpp_host):$(config.ocpp_port)/ocpp/<charger_id>"
    @info "  MQTT broker: $(config.mqtt_host):$(config.mqtt_port)"
    @info "  Config file: $(config.config_path)"

    return state
end

"""
    stop!(state::BridgeState)

Stop the OCPP-to-Victron bridge. Disconnects MQTT and stops the OCPP server.
"""
function stop!(state::BridgeState)
    disconnect_mqtt!(state)
    OCPPServer.stop!(state.central_system)
    @info "OCPPVictron bridge stopped"
    return nothing
end

end # module
