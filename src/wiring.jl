"""
    wire_events!(state::BridgeState)

Subscribe to OCPPServer events and connect them to the bridge logic.
Handles auto-approval of new chargers and Victron device lifecycle.
"""
function wire_events!(state::BridgeState)
    OCPPServer.subscribe!(state.central_system) do event
        _handle_event!(state, event)
    end
end

function _handle_event!(state::BridgeState, event::OCPPServer.ChargePointConnected)
    cp_id = event.charge_point_id

    # Auto-approve: add to config if not already known
    charger_config = find_charger(state.config, cp_id)
    if charger_config === nothing
        charger_config = add_charger!(state.config, cp_id)
    end

    if !charger_config.enabled
        @info "Charger disabled in config, skipping Victron registration" charge_point_id =
            cp_id
        return nothing
    end

    # Create live state
    charger_state = ChargerState(; id = cp_id, connected_at = event.timestamp)
    device = VictronDevice(; service_name = charger_config.service_name)

    lock(state.lock) do
        state.chargers[cp_id] = charger_state
        state.devices[cp_id] = device
    end

    # Register on Victron dbus
    register_device!(state, cp_id)
    @info "Charger connected" charge_point_id = cp_id service = charger_config.service_name
    return nothing
end

function _handle_event!(state::BridgeState, event::OCPPServer.ChargePointDisconnected)
    cp_id = event.charge_point_id

    # Unregister from Victron dbus
    unregister_device!(state, cp_id)

    lock(state.lock) do
        delete!(state.chargers, cp_id)
        delete!(state.devices, cp_id)
    end

    @info "Charger disconnected" charge_point_id = cp_id reason = event.reason
    return nothing
end

function _handle_event!(state::BridgeState, event::OCPPServer.HandlerError)
    @warn "OCPP handler error" charge_point_id = event.charge_point_id action = event.action error =
        event.error
    return nothing
end

# Catch-all for events we don't explicitly handle
function _handle_event!(::BridgeState, ::OCPPServer.OCPPEvent)
    return nothing
end
