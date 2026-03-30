"""
    ChargerSnapshot

Immutable snapshot of ChargerState for Observable reactivity.
Bonito needs copy-on-write; this bridges the mutable ChargerState.
"""
Base.@kwdef struct ChargerSnapshot
    id::String
    vendor::Union{String,Nothing} = nothing
    model::Union{String,Nothing} = nothing
    serial_number::Union{String,Nothing} = nothing
    firmware::Union{String,Nothing} = nothing
    ocpp_status::Symbol = :Unavailable
    error_code::Union{String,Nothing} = nothing
    power_w::Float64 = 0.0
    current_a::Float64 = 0.0
    energy_wh::Float64 = 0.0
    l1_power_w::Float64 = 0.0
    l2_power_w::Float64 = 0.0
    l3_power_w::Float64 = 0.0
    active_transaction_id::Union{Int,Nothing} = nothing
    transaction_start_time::Union{DateTime,Nothing} = nothing
    id_tag::Union{String,Nothing} = nothing
    connected_at::DateTime = now(UTC)
    last_seen::DateTime = now(UTC)
    # Victron info
    service_name::String = ""
    victron_registered::Bool = false
end

"""
    AppEventEntry

A single event entry for the live event log UI.
"""
Base.@kwdef struct AppEventEntry
    timestamp::DateTime = now(UTC)
    level::Symbol = :info
    source::String = "system"
    message::String = ""
end

"""
    AppState

UI state wrapping BridgeState with Observables for Bonito reactivity.
"""
mutable struct AppState
    chargers::Observable{Vector{ChargerSnapshot}}
    selected_charger::Observable{Union{String,Nothing}}
    active_page::Observable{Symbol}
    events::Observable{Vector{AppEventEntry}}
    theme::Observable{Symbol}
    active_tx_count::Observable{Int}
    bridge_state::BridgeState
    db_path::String
end

"""
    create_app_state(bridge_state::BridgeState, db_path::String) → AppState

Create the initial AppState wrapping a BridgeState.
"""
function create_app_state(bridge_state::BridgeState, db_path::String)
    return AppState(
        Observable(ChargerSnapshot[]),
        Observable{Union{String,Nothing}}(nothing),
        Observable(:dashboard),
        Observable(AppEventEntry[]),
        Observable(:light),
        Observable(0),
        bridge_state,
        db_path,
    )
end

"""
    _snapshot_charger(cs::ChargerState, device::Union{VictronDevice,Nothing}) → ChargerSnapshot

Create an immutable snapshot of a ChargerState.
"""
function _snapshot_charger(cs::ChargerState, device::Union{VictronDevice,Nothing})
    return ChargerSnapshot(;
        id = cs.id,
        vendor = cs.vendor,
        model = cs.model,
        serial_number = cs.serial_number,
        firmware = cs.firmware,
        ocpp_status = cs.ocpp_status,
        error_code = cs.error_code,
        power_w = cs.power_w,
        current_a = cs.current_a,
        energy_wh = cs.energy_wh,
        l1_power_w = cs.l1_power_w,
        l2_power_w = cs.l2_power_w,
        l3_power_w = cs.l3_power_w,
        active_transaction_id = cs.active_transaction_id,
        transaction_start_time = cs.transaction_start_time,
        id_tag = cs.id_tag,
        connected_at = cs.connected_at,
        last_seen = cs.last_seen,
        service_name = device !== nothing ? device.service_name : "",
        victron_registered = device !== nothing ? device.registered : false,
    )
end

"""
    _periodic_charger_snapshot(app_state::AppState; interval=1)

Periodically snapshot BridgeState.chargers into the Observable.
"""
function _periodic_charger_snapshot(app_state::AppState; interval = 2)
    # Wait for Bonito to finish initializing before pushing Observable updates
    sleep(5)
    while true
        sleep(interval)
        try
            snapshots = lock(app_state.bridge_state.lock) do
                ChargerSnapshot[
                    _snapshot_charger(
                        cs, get(app_state.bridge_state.devices, id, nothing)
                    ) for
                    (id, cs) in app_state.bridge_state.chargers
                ]
            end

            # Only update Observable if the data actually changed
            # (avoids unnecessary DOM rebuilds that cause 404 errors)
            old = app_state.chargers[]
            changed = length(old) != length(snapshots)
            if !changed
                for (o, n) in zip(old, snapshots)
                    if o.id != n.id || o.ocpp_status != n.ocpp_status ||
                       o.power_w != n.power_w || o.energy_wh != n.energy_wh ||
                       o.current_a != n.current_a
                        changed = true
                        break
                    end
                end
            end

            if changed
                app_state.chargers[] = snapshots
            end

            # Update active transaction count
            if app_state.bridge_state.db_path !== nothing
                try
                    new_count = count_active_transactions()
                    if new_count != app_state.active_tx_count[]
                        app_state.active_tx_count[] = new_count
                    end
                catch
                end
            end
        catch e
            e isa InterruptException && rethrow()
        end
    end
end

"""
    push_app_event!(app_state::AppState, level::Symbol, source::String, message::String)

Push an event to the UI event log Observable.
"""
function push_app_event!(
    app_state::AppState,
    level::Symbol,
    source::String,
    message::String,
)
    entry = AppEventEntry(; timestamp = now(UTC), level, source, message)
    events = copy(app_state.events[])
    pushfirst!(events, entry)
    app_state.events[] = events[1:min(500, length(events))]
    return nothing
end
