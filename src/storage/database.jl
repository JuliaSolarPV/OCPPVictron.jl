"""Thread-local database connection."""
const _DB_REF = Ref{Union{SQLite.DB,Nothing}}(nothing)
const _DB_PATH = Ref{String}("")

const _SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS transactions (
    id              INTEGER PRIMARY KEY,
    charger_id      TEXT NOT NULL,
    connector_id    INTEGER,
    id_tag          TEXT,
    start_time      TEXT NOT NULL,
    stop_time       TEXT,
    meter_start     INTEGER,
    meter_stop      INTEGER,
    energy_wh       REAL,
    status          TEXT NOT NULL DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS meter_values (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    transaction_id  INTEGER,
    charger_id      TEXT NOT NULL,
    timestamp       TEXT NOT NULL,
    power_w         REAL,
    current_a       REAL,
    energy_wh       REAL
);

CREATE TABLE IF NOT EXISTS event_log (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp       TEXT NOT NULL,
    charger_id      TEXT,
    level           TEXT NOT NULL DEFAULT 'info',
    message         TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_transactions_charger ON transactions(charger_id);
CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status);
CREATE INDEX IF NOT EXISTS idx_transactions_time ON transactions(start_time);
CREATE INDEX IF NOT EXISTS idx_meter_values_tx ON meter_values(transaction_id);
CREATE INDEX IF NOT EXISTS idx_event_log_time ON event_log(timestamp);
"""

"""
    init_db!(; path="ocppvictron.sqlite") → SQLite.DB

Initialize the SQLite database, creating tables if needed.
"""
function init_db!(; path::String = "ocppvictron.sqlite")
    _DB_PATH[] = path
    db = SQLite.DB(path)
    _DB_REF[] = db

    for stmt in split(_SCHEMA_SQL, ";")
        s = strip(stmt)
        isempty(s) && continue
        DBInterface.execute(db, s)
    end

    return db
end

"""
    max_transaction_id() → Int

Return the highest transaction ID in the database (for initializing the counter).
"""
function max_transaction_id()
    db = get_db()
    rows = _collect_rows(
        DBInterface.execute(db, "SELECT COALESCE(MAX(id), 0) as max_id FROM transactions"),
    )
    val = first(rows).max_id
    return (val === missing || val === nothing) ? 0 : Int(val)
end

"""Return the active database connection."""
function get_db()
    db = _DB_REF[]
    db === nothing && error("Database not initialized — call init_db!() first")
    return db
end

"""Materialize SQLite query results into a Vector of NamedTuples."""
function _collect_rows(result)
    rows = NamedTuple[]
    for row in result
        names = propertynames(row)
        values = Tuple(getproperty(row, n) for n in names)
        push!(rows, NamedTuple{Tuple(names)}(values))
    end
    return rows
end
