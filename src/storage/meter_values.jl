"""
    insert_meter_value!(; charger_id, timestamp, power_w, current_a, energy_wh, transaction_id)

Insert a meter value record.
"""
function insert_meter_value!(;
    charger_id::String,
    timestamp::String,
    power_w::Float64 = 0.0,
    current_a::Float64 = 0.0,
    energy_wh::Float64 = 0.0,
    transaction_id::Union{Int,Nothing} = nothing,
)
    db = get_db()
    DBInterface.execute(
        db,
        """INSERT INTO meter_values
           (transaction_id, charger_id, timestamp, power_w, current_a, energy_wh)
           VALUES (?, ?, ?, ?, ?, ?)""",
        [transaction_id, charger_id, timestamp, power_w, current_a, energy_wh],
    )
    return nothing
end

"""
    get_meter_values(; charger_id, limit=300) → Vector{NamedTuple}

Get recent meter values for a charger.
"""
function get_meter_values(; charger_id::String, limit::Int = 300)
    db = get_db()
    return _collect_rows(
        DBInterface.execute(
            db,
            """SELECT * FROM meter_values
               WHERE charger_id = ?
               ORDER BY timestamp DESC LIMIT ?""",
            [charger_id, limit],
        ),
    )
end
