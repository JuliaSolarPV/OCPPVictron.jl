"""
    create_transaction!(; charger_id, connector_id, id_tag, meter_start, timestamp, tx_id) → Int

Create a new transaction record and return the transaction ID.
"""
function create_transaction!(;
    charger_id::String,
    connector_id::Int,
    id_tag::String,
    meter_start::Int,
    timestamp::String,
    tx_id::Int,
)
    db = get_db()
    DBInterface.execute(
        db,
        """INSERT INTO transactions
           (id, charger_id, connector_id, id_tag, start_time, meter_start, status)
           VALUES (?, ?, ?, ?, ?, ?, 'active')""",
        [tx_id, charger_id, connector_id, id_tag, timestamp, meter_start],
    )
    return tx_id
end

"""
    complete_transaction!(; transaction_id, meter_stop, timestamp, reason) → nothing

Mark a transaction as completed with final meter reading.
"""
function complete_transaction!(;
    transaction_id::Int,
    meter_stop::Int,
    timestamp::String,
    reason::Union{String,Nothing} = nothing,
)
    db = get_db()
    rows = _collect_rows(
        DBInterface.execute(
            db,
            "SELECT meter_start FROM transactions WHERE id = ?",
            [transaction_id],
        ),
    )
    energy = if !isempty(rows) && rows[1].meter_start !== missing
        Float64(meter_stop - rows[1].meter_start)
    else
        0.0
    end
    DBInterface.execute(
        db,
        """UPDATE transactions
           SET stop_time = ?, meter_stop = ?, energy_wh = ?, status = 'completed'
           WHERE id = ?""",
        [timestamp, meter_stop, energy, transaction_id],
    )
    return nothing
end

"""
    list_transactions(; charger_id=nothing, status=nothing, limit=50) → Vector{NamedTuple}

List transactions with optional filtering.
"""
function list_transactions(;
    charger_id::Union{String,Nothing} = nothing,
    status::Union{String,Nothing} = nothing,
    limit::Int = 50,
)
    db = get_db()
    clauses = String[]
    params = Any[]
    if charger_id !== nothing
        push!(clauses, "charger_id = ?")
        push!(params, charger_id)
    end
    if status !== nothing
        push!(clauses, "status = ?")
        push!(params, status)
    end
    where = isempty(clauses) ? "" : "WHERE " * join(clauses, " AND ")
    push!(params, limit)
    return _collect_rows(
        DBInterface.execute(
            db,
            "SELECT * FROM transactions $where ORDER BY start_time DESC LIMIT ?",
            params,
        ),
    )
end

"""Count currently active transactions."""
function count_active_transactions()
    db = get_db()
    rows = _collect_rows(
        DBInterface.execute(
            db,
            "SELECT COUNT(*) as cnt FROM transactions WHERE status = 'active'",
        ),
    )
    val = first(rows).cnt
    return (val === missing || val === nothing) ? 0 : Int(val)
end
