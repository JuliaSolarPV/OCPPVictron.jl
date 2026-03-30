"""Build a live power time-series chart for a charger."""
function build_power_chart(app_state::AppState, charger_id::String)
    fig = Figure(; size = (550, 280))
    ax = Axis(fig[1, 1]; title = "Power", xlabel = "Seconds ago", ylabel = "kW")

    data = map(app_state.chargers) do _
        history = lock(app_state.bridge_state.lock) do
            get(app_state.bridge_state.meter_history, charger_id, MeterSample[])
        end
        n = length(history)
        if n == 0
            return (Float64[], Float64[], Float64[], Float64[], Float64[])
        end
        xs = Float64[-(n - i) for i = 1:n]
        total = Float64[s.power_w / 1000 for s in history]
        l1 = Float64[s.l1_power_w / 1000 for s in history]
        l2 = Float64[s.l2_power_w / 1000 for s in history]
        l3 = Float64[s.l3_power_w / 1000 for s in history]
        return (xs, total, l1, l2, l3)
    end

    xs = map(d -> d[1], data)
    total = map(d -> d[2], data)
    l1 = map(d -> d[3], data)
    l2 = map(d -> d[4], data)
    l3 = map(d -> d[5], data)

    lines!(ax, xs, total; color = :steelblue, linewidth = 2, label = "Total")
    lines!(ax, xs, l1; color = :red, linewidth = 1, label = "L1")
    lines!(ax, xs, l2; color = :green, linewidth = 1, label = "L2")
    lines!(ax, xs, l3; color = :orange, linewidth = 1, label = "L3")

    return Card(fig)
end
