"""
    ChargerState

Per-charger state accumulated from OCPP messages. Updated in-place by handlers.
"""
Base.@kwdef mutable struct ChargerState
    id::String

    # Identity (from BootNotification)
    vendor::Union{String,Nothing} = nothing
    model::Union{String,Nothing} = nothing
    serial_number::Union{String,Nothing} = nothing
    firmware::Union{String,Nothing} = nothing

    # Status (from StatusNotification)
    ocpp_status::Symbol = :Unavailable
    error_code::Union{String,Nothing} = nothing

    # Metering (from MeterValues)
    power_w::Float64 = 0.0
    current_a::Float64 = 0.0
    energy_wh::Float64 = 0.0
    l1_power_w::Float64 = 0.0
    l2_power_w::Float64 = 0.0
    l3_power_w::Float64 = 0.0

    # Transaction tracking
    active_transaction_id::Union{Int,Nothing} = nothing
    transaction_start_time::Union{DateTime,Nothing} = nothing
    transaction_meter_start::Union{Int,Nothing} = nothing
    id_tag::Union{String,Nothing} = nothing

    # Timestamps
    connected_at::DateTime = now(UTC)
    last_seen::DateTime = now(UTC)
end

"""
    VictronDevice

Registration state for one charger on the Victron dbus (via dbus-mqtt-devices).
"""
Base.@kwdef mutable struct VictronDevice
    service_name::String
    device_type::String = "evcharger"
    portal_id::Union{String,Nothing} = nothing
    device_instance::Union{Int,Nothing} = nothing
    topic_path_w::Union{String,Nothing} = nothing
    registered::Bool = false
end

"""
    BridgeState

Central bridge state. Owns all live data and references.
"""
mutable struct BridgeState
    chargers::Dict{String,ChargerState}
    devices::Dict{String,VictronDevice}
    central_system::OCPPServer.CentralSystem
    mqtt_client::Any
    config::BridgeConfig
    tx_counter::Int
    lock::ReentrantLock
end
