module OCPPVictron

using Dates
using JSON
using TOML
using MQTTClient
using OCPPServer
using OCPPData
using SQLite
using DBInterface
using Observables
using Bonito
using Bonito: DOM
using WGLMakie

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

# App (Bonito UI)
include("app/state.jl")
include("app/app.jl")
include("app/sidebar.jl")
include("app/components/header.jl")
include("app/components/charger_card.jl")
include("app/components/charger_detail.jl")
include("app/plots/power_chart.jl")
include("app/plots/current_chart.jl")
include("app/pages/dashboard.jl")
include("app/pages/config_page.jl")
include("app/pages/logs_page.jl")
include("app/pages/sessions_page.jl")

"""
    start(; config_path="ocppvictron.toml", kwargs...) → BridgeState

Start the OCPP-to-Victron bridge.

Loads (or creates) the config file, starts the OCPP WebSocket server,
and connects to the Venus OS MQTT broker. Chargers that connect via OCPP
will appear as EV charger devices on the Victron system.

Any keyword arguments override values from the config file.
"""
function start(;
    config_path::String = "ocppvictron.toml",
    web_port::Int = 8080,
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
        nothing,  # db_path set below if frontend enabled
        ReentrantLock(),
    )

    # 4. Register OCPP handlers
    register_ocpp_handlers!(cs, state)

    # 5. Wire events
    wire_events!(state)

    # 6. Connect MQTT (optional — continues without it if broker unavailable)
    mqtt_ok = try
        connect_mqtt!(state)
        true
    catch e
        @warn "MQTT unavailable ($(config.mqtt_host):$(config.mqtt_port)), continuing without Victron integration"
        false
    end

    # 7. Initialize database
    init_db!(; path = db_path)
    state.db_path = db_path

    # 8. Activate WGLMakie and start OCPP server
    WGLMakie.activate!()
    @async OCPPServer.start!(cs)

    # 9. Create app state and start web server
    app_state = create_app_state(state, db_path)
    @async _periodic_charger_snapshot(app_state)

    # Push startup events to the log
    push_app_event!(app_state, :info, "system", "OCPPVictron bridge starting")
    push_app_event!(
        app_state,
        :info,
        "system",
        "OCPP server listening on ws://$(config.ocpp_host):$(config.ocpp_port)/ocpp/<id>",
    )
    if mqtt_ok
        push_app_event!(
            app_state,
            :info,
            "system",
            "MQTT connected to $(config.mqtt_host):$(config.mqtt_port)",
        )
    else
        push_app_event!(
            app_state,
            :warn,
            "system",
            "MQTT broker unavailable at $(config.mqtt_host):$(config.mqtt_port)",
        )
    end
    push_app_event!(app_state, :info, "system", "Database initialized at $(db_path)")

    app = create_app(app_state)
    server = Bonito.Server(app, "0.0.0.0", web_port)

    push_app_event!(
        app_state,
        :info,
        "system",
        "Dashboard available at http://localhost:$(web_port)",
    )

    @info "OCPPVictron bridge running"
    @info "  OCPP server: ws://$(config.ocpp_host):$(config.ocpp_port)/ocpp/<charger_id>"
    @info "  MQTT broker: $(config.mqtt_host):$(config.mqtt_port) $(mqtt_ok ? "(connected)" : "(unavailable)")"
    @info "  Dashboard:   http://localhost:$(web_port)"
    @info "  Config file: $(config.config_path)"

    return nothing
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
