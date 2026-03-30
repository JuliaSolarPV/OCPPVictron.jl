"""Build the Sessions page — charging session history."""
function build_sessions_page(app_state::AppState)
    sessions_content = map(app_state.active_tx_count, app_state.chargers) do _, _
        txs = try
            list_transactions(; limit = 100)
        catch
            NamedTuple[]
        end

        if isempty(txs)
            return DOM.p(
                "No charging sessions recorded yet.";
                style = "color:var(--text-muted);text-align:center;padding:20px;",
            )
        end

        # Build a Tables.jl-compatible structure for Bonito.Table
        rows = [
            (
                Start = something(tx.start_time, ""),
                End = (tx.stop_time === missing || tx.stop_time === nothing) ? "" :
                      tx.stop_time,
                Charger = something(tx.charger_id, ""),
                Tag = (tx.id_tag === missing || tx.id_tag === nothing) ? "" : tx.id_tag,
                Energy = if tx.energy_wh !== missing && tx.energy_wh !== nothing
                    "$(round(tx.energy_wh / 1000; digits=2)) kWh"
                else
                    "-"
                end,
                Status = something(tx.status, "unknown"),
            ) for tx in txs
        ]

        Bonito.Table(rows)
    end

    return Card(sessions_content)
end
