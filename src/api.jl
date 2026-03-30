# REST + WebSocket API for the React frontend.

"""
    ChargerSnapshot

Immutable point-in-time snapshot of a ChargerState for JSON serialization.
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
    service_name::String = ""
    victron_registered::Bool = false
end

"""Snapshot a ChargerState into a ChargerSnapshot."""
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

"""Snapshot all chargers into a JSON-serializable array."""
function _get_charger_snapshots(state::BridgeState)
    return lock(state.lock) do
        ChargerSnapshot[
            _snapshot_charger(cs, get(state.devices, id, nothing)) for
            (id, cs) in state.chargers
        ]
    end
end

"""Convert a ChargerSnapshot to a Dict for JSON."""
function _snapshot_to_dict(s::ChargerSnapshot)
    return Dict{String,Any}(
        "id" => s.id,
        "vendor" => s.vendor,
        "model" => s.model,
        "serialNumber" => s.serial_number,
        "firmware" => s.firmware,
        "ocppStatus" => string(s.ocpp_status),
        "errorCode" => s.error_code,
        "powerW" => s.power_w,
        "currentA" => s.current_a,
        "energyWh" => s.energy_wh,
        "l1PowerW" => s.l1_power_w,
        "l2PowerW" => s.l2_power_w,
        "l3PowerW" => s.l3_power_w,
        "activeTransactionId" => s.active_transaction_id,
        "transactionStartTime" =>
            s.transaction_start_time !== nothing ?
            Dates.format(s.transaction_start_time, dateformat"yyyy-mm-ddTHH:MM:SSZ") :
            nothing,
        "idTag" => s.id_tag,
        "connectedAt" => Dates.format(s.connected_at, dateformat"yyyy-mm-ddTHH:MM:SSZ"),
        "lastSeen" => Dates.format(s.last_seen, dateformat"yyyy-mm-ddTHH:MM:SSZ"),
        "serviceName" => s.service_name,
        "victronRegistered" => s.victron_registered,
    )
end

# ── MIME type helper ──
const _MIME_TYPES = Dict(
    ".html" => "text/html",
    ".js" => "application/javascript",
    ".css" => "text/css",
    ".json" => "application/json",
    ".png" => "image/png",
    ".svg" => "image/svg+xml",
    ".ico" => "image/x-icon",
    ".woff" => "font/woff",
    ".woff2" => "font/woff2",
)

function _mime_type(path::String)
    ext = lowercase(splitext(path)[2])
    return get(_MIME_TYPES, ext, "application/octet-stream")
end

# ── JSON response helpers ──
function _json_response(data; status = 200)
    body = JSON.json(data)
    return HTTP.Response(
        status,
        ["Content-Type" => "application/json", "Access-Control-Allow-Origin" => "*"];
        body = body,
    )
end

function _error_response(message::String; status = 400)
    return _json_response(Dict("error" => message); status)
end

# ── Route handlers ──

function _handle_chargers(state::BridgeState, req::HTTP.Request)
    snapshots = _get_charger_snapshots(state)
    return _json_response([_snapshot_to_dict(s) for s in snapshots])
end

function _handle_charger_by_id(state::BridgeState, req::HTTP.Request)
    # Extract ID from path: /api/chargers/{id}
    parts = HTTP.URIs.splitpath(split(req.target, "?")[1])
    id = length(parts) >= 3 ? parts[3] : ""
    if isempty(id)
        return _error_response("Missing charger ID"; status = 400)
    end

    snapshots = _get_charger_snapshots(state)
    idx = findfirst(s -> s.id == id, snapshots)
    if idx === nothing
        return _error_response("Charger not found"; status = 404)
    end
    return _json_response(_snapshot_to_dict(snapshots[idx]))
end

function _handle_config(state::BridgeState, _req::HTTP.Request)
    config = state.config
    return _json_response(
        Dict(
            "ocppHost" => config.ocpp_host,
            "ocppPort" => config.ocpp_port,
            "ocppVersion" => config.ocpp_version,
            "mqttHost" => config.mqtt_host,
            "mqttPort" => config.mqtt_port,
            "mqttClientId" => config.mqtt_client_id,
            "heartbeatInterval" => config.heartbeat_interval,
            "autoAuthorize" => config.auto_authorize,
            "configPath" => config.config_path,
            "chargers" => [
                Dict(
                    "chargePointId" => c.charge_point_id,
                    "serviceName" => c.service_name,
                    "enabled" => c.enabled,
                ) for c in config.chargers
            ],
        ),
    )
end

function _handle_config_reload(state::BridgeState, _req::HTTP.Request)
    config = state.config
    try
        new_config = load_config(config.config_path)
        config.heartbeat_interval = new_config.heartbeat_interval
        config.auto_authorize = new_config.auto_authorize
        config.chargers = new_config.chargers
        return _json_response(Dict("status" => "ok", "message" => "Config reloaded"))
    catch e
        return _error_response("Reload failed: $e"; status = 500)
    end
end

function _handle_sessions(state::BridgeState, req::HTTP.Request)
    params = HTTP.URIs.queryparams(HTTP.URI(req.target))
    charger_id = get(params, "charger", nothing)
    txs = list_transactions(; charger_id, limit = 100)
    rows = Any[]
    for tx in txs
        push!(
            rows,
            Dict(
                "id" => tx.id,
                "chargerId" => tx.charger_id,
                "connectorId" => tx.connector_id,
                "idTag" => tx.id_tag,
                "startTime" => tx.start_time,
                "stopTime" => tx.stop_time === missing ? nothing : tx.stop_time,
                "meterStart" => tx.meter_start,
                "meterStop" => tx.meter_stop === missing ? nothing : tx.meter_stop,
                "energyWh" => tx.energy_wh === missing ? nothing : tx.energy_wh,
                "status" => tx.status,
            ),
        )
    end
    return _json_response(rows)
end

function _handle_logs(state::BridgeState, _req::HTTP.Request)
    events = recent_events(; limit = 200)
    rows = Any[]
    for e in events
        push!(
            rows,
            Dict(
                "timestamp" => e.timestamp,
                "chargerId" => e.charger_id === missing ? nothing : e.charger_id,
                "level" => e.level,
                "message" => e.message,
            ),
        )
    end
    return _json_response(rows)
end

function _handle_status(state::BridgeState, _req::HTTP.Request)
    n_chargers = lock(state.lock) do
        length(state.chargers)
    end
    return _json_response(
        Dict(
            "ocppConnected" => true,
            "mqttConnected" => state.mqtt_client !== nothing,
            "chargersOnline" => n_chargers,
            "configPath" => state.config.config_path,
            "dbPath" => state.db_path,
        ),
    )
end

function _handle_meter_history(state::BridgeState, req::HTTP.Request)
    parts = HTTP.URIs.splitpath(split(req.target, "?")[1])
    id = length(parts) >= 3 ? parts[3] : ""
    if isempty(id)
        return _error_response("Missing charger ID"; status = 400)
    end

    history = lock(state.lock) do
        get(state.meter_history, id, MeterSample[])
    end

    rows = Any[]
    for s in history
        push!(
            rows,
            Dict(
                "timestamp" => Dates.format(s.timestamp, dateformat"yyyy-mm-ddTHH:MM:SSZ"),
                "powerW" => s.power_w,
                "currentA" => s.current_a,
                "l1PowerW" => s.l1_power_w,
                "l2PowerW" => s.l2_power_w,
                "l3PowerW" => s.l3_power_w,
            ),
        )
    end
    return _json_response(rows)
end

# ── Static file serving ──

function _serve_static(req::HTTP.Request)
    # Extract the URL path (strip query string)
    uri_path = split(req.target, "?")[1]
    if uri_path == "/" || uri_path == ""
        uri_path = "/index.html"
    end
    # Remove leading slash for joinpath
    rel_path = lstrip(uri_path, '/')

    frontend_dir = joinpath(dirname(@__DIR__), "frontend", "dist")
    filepath = joinpath(frontend_dir, rel_path)

    # Security: prevent path traversal
    if isfile(filepath) && !startswith(realpath(filepath), realpath(frontend_dir))
        return HTTP.Response(403, "Forbidden")
    end

    if isfile(filepath)
        body = read(filepath)
        return HTTP.Response(200, ["Content-Type" => _mime_type(filepath)]; body)
    end

    # SPA fallback: serve index.html for any non-file path
    index_path = joinpath(frontend_dir, "index.html")
    if isfile(index_path)
        body = read(index_path)
        return HTTP.Response(200, ["Content-Type" => "text/html"]; body)
    end

    return HTTP.Response(404, "Not Found")
end

# ── WebSocket handler ──

function _handle_websocket(state::BridgeState, ws::HTTP.WebSockets.WebSocket)
    try
        while isopen(ws)
            snapshots = _get_charger_snapshots(state)
            msg = JSON.json(
                Dict(
                    "type" => "chargers",
                    "data" => [_snapshot_to_dict(s) for s in snapshots],
                ),
            )
            write(ws, msg)
            sleep(2)
        end
    catch e
        e isa EOFError && return
        e isa Base.IOError && return
    end
end

# ── API server startup ──

"""
    start_api!(state::BridgeState; port=8080)

Start the HTTP API server with REST endpoints, WebSocket, and static file serving.
"""
function start_api!(state::BridgeState; port::Int = 8080)
    # HTTP request handler
    function handle_request(req::HTTP.Request)
        target = req.target

        # CORS preflight
        if req.method == "OPTIONS"
            return HTTP.Response(
                204,
                [
                    "Access-Control-Allow-Origin" => "*",
                    "Access-Control-Allow-Methods" => "GET, POST, OPTIONS",
                    "Access-Control-Allow-Headers" => "Content-Type",
                ],
            )
        end

        resp = if startswith(target, "/api/chargers/") && occursin("/history", target)
            _handle_meter_history(state, req)
        elseif startswith(target, "/api/chargers/")
            _handle_charger_by_id(state, req)
        elseif target == "/api/chargers"
            _handle_chargers(state, req)
        elseif target == "/api/config"
            _handle_config(state, req)
        elseif target == "/api/config/reload" && req.method == "POST"
            _handle_config_reload(state, req)
        elseif startswith(target, "/api/sessions")
            _handle_sessions(state, req)
        elseif startswith(target, "/api/logs")
            _handle_logs(state, req)
        elseif target == "/api/status"
            _handle_status(state, req)
        else
            _serve_static(req)
        end

        # Add CORS header
        push!(resp.headers, "Access-Control-Allow-Origin" => "*")
        return resp
    end

    @async HTTP.listen("0.0.0.0", port) do http
        target = http.message.target

        # WebSocket upgrade for /api/ws
        if target == "/api/ws"
            HTTP.WebSockets.upgrade(http) do ws
                _handle_websocket(state, ws)
            end
            return
        end

        # Regular HTTP
        resp = handle_request(http.message)
        for (k, v) in resp.headers
            HTTP.setheader(http, k => v)
        end
        HTTP.setstatus(http, resp.status)
        HTTP.startwrite(http)
        write(http, resp.body)
    end

    @info "API server started on port $port"
    return nothing
end
