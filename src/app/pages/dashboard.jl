"""Build the Dashboard page — charger cards grid or detail view."""
function build_dashboard(app_state::AppState)
    content = map(app_state.selected_charger, app_state.chargers) do selected, chargers
        if selected !== nothing
            build_charger_detail(app_state, selected)
        else
            _build_grid(app_state, chargers)
        end
    end

    return DOM.div(content)
end

"""Build the charger cards grid."""
function _build_grid(app_state::AppState, chargers::Vector{ChargerSnapshot})
    if isempty(chargers)
        return Card(
            Col(
                DOM.h3("No chargers connected"),
                DOM.p(
                    "Connect an OCPP charger to see it here.";
                    style = "color:var(--text-muted);margin-top:8px;",
                );
                align_items = "center",
            );
            padding = "40px",
        )
    end

    # Summary stats
    total_power = sum(c.power_w for c in chargers; init = 0.0)
    n_charging = count(c -> c.ocpp_status == :Charging, chargers)
    total_energy = sum(c.energy_wh for c in chargers; init = 0.0)

    stats = Row(
        _stat_card("$(length(chargers))", "Online"),
        _stat_card("$n_charging", "Charging"; color = "#3b82f6"),
        _stat_card("$(round(total_power / 1000; digits=1)) kW", "Total Power"),
        _stat_card("$(round(total_energy / 1000; digits=1)) kWh", "Total Energy");
        gap = "16px",
        height = "auto",
    )

    # Charger cards — each is a clickable Card
    cards = Any[]
    for c in chargers
        btn = Button(""; style = nothing)
        on(btn.value) do _
            app_state.selected_charger[] = c.id
        end
        card_html = _charger_card_html(c)
        card = Card(
            Col(DOM.div(; innerHTML = card_html), btn);
            style = Styles(
                CSS("cursor" => "pointer"),
                CSS(":hover", "border-color" => "#2563eb"),
            ),
        )
        push!(cards, card)
    end

    grid = Grid(
        cards...;
        columns = "repeat(auto-fill, minmax(320px, 1fr))",
        gap = "16px",
        height = "auto",
    )

    return Col(stats, grid; gap = "16px", height = "auto")
end

"""Build a stat card for the summary row."""
function _stat_card(value::String, label::String; color::String = "var(--text)")
    return Card(
        Col(
            DOM.div(value; style = "font-size:24px;font-weight:700;color:$color;"),
            DOM.div(
                label;
                style = "font-size:12px;color:var(--text-muted);text-transform:uppercase;letter-spacing:0.5px;margin-top:4px;",
            );
            align_items = "center",
        ),
    )
end
