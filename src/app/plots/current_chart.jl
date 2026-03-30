"""Build a live current time-series chart for a charger."""
function build_current_chart(app_state::AppState, charger_id::String)
    fig = Figure(; size = (550, 280))
    ax = Axis(fig[1, 1]; title = "Current", xlabel = "Seconds ago", ylabel = "A")

    data = map(app_state.chargers) do _
        history = lock(app_state.bridge_state.lock) do
            get(app_state.bridge_state.meter_history, charger_id, MeterSample[])
        end
        n = length(history)
        if n == 0
            return (Float64[], Float64[])
        end
        xs = Float64[-(n - i) for i = 1:n]
        ys = Float64[s.current_a for s in history]
        return (xs, ys)
    end

    xs = map(d -> d[1], data)
    ys = map(d -> d[2], data)

    lines!(ax, xs, ys; color = :steelblue, linewidth = 2)

    return Card(fig)
end
