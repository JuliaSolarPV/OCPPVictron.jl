"""
    log_event!(; charger_id, level, message)

Insert an event into the event log.
"""
function log_event!(;
    charger_id::Union{String,Nothing} = nothing,
    level::String = "info",
    message::String,
)
    db = get_db()
    DBInterface.execute(
        db,
        """INSERT INTO event_log (timestamp, charger_id, level, message)
           VALUES (?, ?, ?, ?)""",
        [_now_iso(), charger_id, level, message],
    )
    return nothing
end

"""
    recent_events(; charger_id=nothing, level=nothing, limit=200) → Vector{NamedTuple}

Get recent events from the log.
"""
function recent_events(;
    charger_id::Union{String,Nothing} = nothing,
    level::Union{String,Nothing} = nothing,
    limit::Int = 200,
)
    db = get_db()
    clauses = String[]
    params = Any[]
    if charger_id !== nothing
        push!(clauses, "charger_id = ?")
        push!(params, charger_id)
    end
    if level !== nothing
        push!(clauses, "level = ?")
        push!(params, level)
    end
    where = isempty(clauses) ? "" : "WHERE " * join(clauses, " AND ")
    push!(params, limit)
    return _collect_rows(
        DBInterface.execute(
            db,
            "SELECT * FROM event_log $where ORDER BY timestamp DESC LIMIT ?",
            params,
        ),
    )
end

"""
    prune_events!(; keep_days=30) → nothing

Delete events older than `keep_days` days.
"""
function prune_events!(; keep_days::Int = 30)
    db = get_db()
    cutoff = Dates.format(now(UTC) - Day(keep_days), dateformat"yyyy-mm-ddTHH:MM:SSZ")
    DBInterface.execute(db, "DELETE FROM event_log WHERE timestamp < ?", [cutoff])
    return nothing
end
