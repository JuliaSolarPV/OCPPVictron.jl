"""
    ChargerConfig

Configuration for a single known charger.
"""
Base.@kwdef struct ChargerConfig
    charge_point_id::String
    service_name::String            # ev1, ev2, ...
    enabled::Bool = true
end

"""
    BridgeConfig

Configuration for the OCPP-to-Victron bridge. Loaded from / saved to a TOML file.
"""
Base.@kwdef mutable struct BridgeConfig
    # Bridge settings
    ocpp_host::String = "0.0.0.0"
    ocpp_port::Int = 9000
    ocpp_version::String = "v16"
    mqtt_host::String = "127.0.0.1"
    mqtt_port::Int = 1883
    mqtt_client_id::String = "ocppvictron"
    heartbeat_interval::Int = 300
    auto_authorize::Bool = true

    # Known chargers (grows as new chargers connect and are auto-approved)
    chargers::Vector{ChargerConfig} = ChargerConfig[]

    # Path to the TOML file
    config_path::String = "ocppvictron.toml"
end

"""
    load_config(path::String="ocppvictron.toml") → BridgeConfig

Load configuration from a TOML file. If the file does not exist, creates a
default config file and returns the defaults.
"""
function load_config(path::String = "ocppvictron.toml")
    if !isfile(path)
        @info "Config file not found, creating default" path
        config = BridgeConfig(; config_path = path)
        save_config!(config)
        return config
    end

    data = TOML.parsefile(path)
    bridge = get(data, "bridge", Dict{String,Any}())

    charger_list = ChargerConfig[]
    for c in get(data, "chargers", [])
        push!(
            charger_list,
            ChargerConfig(;
                charge_point_id = c["charge_point_id"],
                service_name = c["service_name"],
                enabled = get(c, "enabled", true),
            ),
        )
    end

    return BridgeConfig(;
        ocpp_host = get(bridge, "ocpp_host", "0.0.0.0"),
        ocpp_port = get(bridge, "ocpp_port", 9000),
        ocpp_version = get(bridge, "ocpp_version", "v16"),
        mqtt_host = get(bridge, "mqtt_host", "127.0.0.1"),
        mqtt_port = get(bridge, "mqtt_port", 1883),
        mqtt_client_id = get(bridge, "mqtt_client_id", "ocppvictron"),
        heartbeat_interval = get(bridge, "heartbeat_interval", 300),
        auto_authorize = get(bridge, "auto_authorize", true),
        chargers = charger_list,
        config_path = path,
    )
end

"""
    save_config!(config::BridgeConfig)

Write the current configuration to the TOML file at `config.config_path`.
"""
function save_config!(config::BridgeConfig)
    data = Dict{String,Any}(
        "bridge" => Dict{String,Any}(
            "ocpp_host" => config.ocpp_host,
            "ocpp_port" => config.ocpp_port,
            "ocpp_version" => config.ocpp_version,
            "mqtt_host" => config.mqtt_host,
            "mqtt_port" => config.mqtt_port,
            "mqtt_client_id" => config.mqtt_client_id,
            "heartbeat_interval" => config.heartbeat_interval,
            "auto_authorize" => config.auto_authorize,
        ),
        "chargers" => [
            Dict{String,Any}(
                "charge_point_id" => c.charge_point_id,
                "service_name" => c.service_name,
                "enabled" => c.enabled,
            ) for c in config.chargers
        ],
    )
    open(config.config_path, "w") do io
        TOML.print(io, data)
    end
    return nothing
end

"""
    find_charger(config::BridgeConfig, charge_point_id::String) → Union{ChargerConfig, Nothing}

Look up a charger by its charge point ID.
"""
function find_charger(
    config::BridgeConfig,
    charge_point_id::String,
)::Union{ChargerConfig,Nothing}
    idx = findfirst(c -> c.charge_point_id == charge_point_id, config.chargers)
    return idx === nothing ? nothing : config.chargers[idx]
end

"""
    next_service_name(config::BridgeConfig) → String

Return the next available service name (ev1, ev2, ...).
"""
function next_service_name(config::BridgeConfig)::String
    max_n = 0
    for c in config.chargers
        m = match(r"^ev(\d+)$", c.service_name)
        if m !== nothing
            max_n = max(max_n, parse(Int, m.captures[1]))
        end
    end
    return "ev$(max_n + 1)"
end

"""
    add_charger!(config::BridgeConfig, charge_point_id::String) → ChargerConfig

Auto-approve a new charger: assign the next service name, append to config,
save to disk, and log.
"""
function add_charger!(config::BridgeConfig, charge_point_id::String)::ChargerConfig
    existing = find_charger(config, charge_point_id)
    existing !== nothing && return existing

    svc = next_service_name(config)
    entry = ChargerConfig(; charge_point_id = charge_point_id, service_name = svc)
    push!(config.chargers, entry)
    save_config!(config)
    @info "New charger auto-approved" charge_point_id service_name = svc
    return entry
end
