"""
    register_ocpp_handlers!(cs::OCPPServer.CentralSystem, state::BridgeState)

Register all OCPP message handlers on the CentralSystem.

Pattern: `on!()` builds the fast OCPP response. `after!()` updates ChargerState
and publishes to Victron via MQTT.
"""
function register_ocpp_handlers!(cs::OCPPServer.CentralSystem, state::BridgeState)

    # ── BootNotification ──
    OCPPServer.on!(cs, "BootNotification") do session, req
        session.metadata["vendor"] = req.charge_point_vendor
        session.metadata["model"] = req.charge_point_model
        OCPPData.V16.BootNotificationResponse(;
            current_time = _now_iso(),
            interval = state.config.heartbeat_interval,
            status = OCPPData.V16.RegistrationAccepted,
        )
    end

    OCPPServer.after!(cs, "BootNotification") do session, req, _resp
        lock(state.lock) do
            charger = get(state.chargers, session.id, nothing)
            if charger !== nothing
                charger.vendor = req.charge_point_vendor
                charger.model = req.charge_point_model
                charger.serial_number = _opt_field(req, :charge_point_serial_number)
                charger.firmware = _opt_field(req, :firmware_version)
                charger.last_seen = now(UTC)
            end
        end
    end

    # ── Heartbeat ──
    OCPPServer.on!(cs, "Heartbeat") do _session, _req
        OCPPData.V16.HeartbeatResponse(; current_time = _now_iso())
    end

    OCPPServer.after!(cs, "Heartbeat") do session, _req, _resp
        lock(state.lock) do
            charger = get(state.chargers, session.id, nothing)
            if charger !== nothing
                charger.last_seen = now(UTC)
            end
        end
    end

    # ── Authorize ──
    OCPPServer.on!(cs, "Authorize") do _session, _req
        status = if state.config.auto_authorize
            OCPPData.V16.AuthorizationAccepted
        else
            OCPPData.V16.AuthorizationInvalid
        end
        OCPPData.V16.AuthorizeResponse(;
            id_tag_info = OCPPData.V16.IdTagInfo(; status = status),
        )
    end

    # ── StatusNotification ──
    OCPPServer.on!(cs, "StatusNotification") do _session, _req
        OCPPData.V16.StatusNotificationResponse()
    end

    OCPPServer.after!(cs, "StatusNotification") do session, req, _resp
        lock(state.lock) do
            charger = get(state.chargers, session.id, nothing)
            if charger !== nothing
                charger.ocpp_status = Symbol(string(req.status))
                ec = _opt_field(req, :error_code)
                charger.error_code = ec !== nothing ? string(ec) : nothing
                charger.last_seen = now(UTC)
            end
        end
        publish_charger_state!(state, session.id)
    end

    # ── MeterValues ──
    OCPPServer.on!(cs, "MeterValues") do _session, _req
        OCPPData.V16.MeterValuesResponse()
    end

    OCPPServer.after!(cs, "MeterValues") do session, req, _resp
        lock(state.lock) do
            charger = get(state.chargers, session.id, nothing)
            if charger !== nothing
                meter_values = something(req.meter_value, [])
                update_from_meter_values!(charger, meter_values)
                charger.last_seen = now(UTC)
            end
        end
        publish_charger_state!(state, session.id)
    end

    # ── StartTransaction ──
    OCPPServer.on!(cs, "StartTransaction") do _session, req
        tx_id = lock(state.lock) do
            state.tx_counter += 1
            state.tx_counter
        end
        status = if state.config.auto_authorize
            OCPPData.V16.AuthorizationAccepted
        else
            OCPPData.V16.AuthorizationInvalid
        end
        OCPPData.V16.StartTransactionResponse(;
            transaction_id = tx_id,
            id_tag_info = OCPPData.V16.IdTagInfo(; status = status),
        )
    end

    OCPPServer.after!(cs, "StartTransaction") do session, req, resp
        lock(state.lock) do
            charger = get(state.chargers, session.id, nothing)
            if charger !== nothing
                charger.active_transaction_id = resp.transaction_id
                charger.transaction_start_time = now(UTC)
                charger.transaction_meter_start = req.meter_start
                charger.id_tag = req.id_tag
                charger.ocpp_status = :Charging
                charger.last_seen = now(UTC)
            end
        end
        publish_charger_state!(state, session.id)
        @info "Transaction started" charger = session.id tx_id = resp.transaction_id
    end

    # ── StopTransaction ──
    OCPPServer.on!(cs, "StopTransaction") do _session, _req
        OCPPData.V16.StopTransactionResponse()
    end

    OCPPServer.after!(cs, "StopTransaction") do session, req, _resp
        lock(state.lock) do
            charger = get(state.chargers, session.id, nothing)
            if charger !== nothing
                if charger.transaction_meter_start !== nothing
                    charger.energy_wh =
                        Float64(req.meter_stop - charger.transaction_meter_start)
                end
                charger.active_transaction_id = nothing
                charger.transaction_start_time = nothing
                charger.transaction_meter_start = nothing
                charger.id_tag = nothing
                charger.ocpp_status = :Available
                charger.last_seen = now(UTC)
            end
        end
        publish_charger_state!(state, session.id)
        @info "Transaction stopped" charger = session.id tx_id = req.transaction_id
    end

    # ── DataTransfer ──
    OCPPServer.on!(cs, "DataTransfer") do _session, _req
        OCPPData.V16.DataTransferResponse(; status = OCPPData.V16.DataTransferAccepted)
    end

    # ── DiagnosticsStatusNotification ──
    OCPPServer.on!(cs, "DiagnosticsStatusNotification") do _session, _req
        OCPPData.V16.DiagnosticsStatusNotificationResponse()
    end

    # ── FirmwareStatusNotification ──
    OCPPServer.on!(cs, "FirmwareStatusNotification") do _session, _req
        OCPPData.V16.FirmwareStatusNotificationResponse()
    end

    return nothing
end

"""Safely get an optional field, returning nothing if absent."""
function _opt_field(obj, field::Symbol)
    hasproperty(obj, field) ? getproperty(obj, field) : nothing
end
