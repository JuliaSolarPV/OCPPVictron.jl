"""Build the Logs page — real-time log viewer."""
function build_logs_page(app_state::AppState)
    clear_btn = Bonito.Button("Clear")
    on(clear_btn.value) do _
        app_state.events[] = AppEventEntry[]
    end

    log_content = map(app_state.events) do events
        if isempty(events)
            return DOM.div(
                "No log entries yet.";
                class = "ov-log-area",
                style = "text-align:center;padding:20px;color:#64748b;",
            )
        end

        rows = String[]
        for e in events
            ts = Dates.format(e.timestamp, dateformat"HH:MM:SS.sss")
            level_color = if e.level == :info
                "#22c55e"
            elseif e.level == :warn
                "#f59e0b"
            else
                "#ef4444"
            end
            level_str = uppercase(string(e.level))

            push!(
                rows,
                """<div style="padding:1px 0;">
                    <span style="color:#64748b;">$ts</span>
                    <span style="color:$level_color;font-weight:bold;margin:0 6px;">[$level_str]</span>
                    <span style="color:#3b82f6;">[$(e.source)]</span>
                    <span style="color:#e2e8f0;">$(e.message)</span>
                </div>""",
            )
        end

        DOM.div(; innerHTML = join(rows), class = "ov-log-area")
    end

    return Col(
        Card(Row(clear_btn); style = Styles("padding" => "12px 20px")),
        log_content;
        gap = "16px",
    )
end
