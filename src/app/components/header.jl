"""Build the header bar with status indicators and theme toggle."""
function build_header(app_state::AppState)
    theme_btn = Button("Toggle Theme")
    on(theme_btn.value) do _
        app_state.theme[] = app_state.theme[] == :light ? :dark : :light
    end

    page_title = map(app_state.active_page) do page
        titles = Dict(
            :dashboard => "Dashboard",
            :config => "Configuration",
            :logs => "Logs",
            :sessions => "Sessions",
        )
        get(titles, page, "OCPPVictron")
    end

    metrics = map(app_state.chargers) do chargers
        n = length(chargers)
        charging = count(c -> c.ocpp_status == :Charging, chargers)
        power = round(sum(c.power_w for c in chargers; init = 0.0) / 1000; digits = 1)
        DOM.span(
            DOM.span(
                "$n online"; style = "color:#22c55e;font-weight:600;font-size:13px;"
            ),
            DOM.span(
                " · $charging charging";
                style = "color:#3b82f6;font-weight:600;font-size:13px;",
            ),
            DOM.span(
                " · $power kW"; style = "color:var(--text-muted);font-size:13px;"
            );
            style = "margin-left:20px;",
        )
    end

    return DOM.div(
        DOM.div(
            DOM.h1(page_title; style = "font-size:24px;font-weight:700;display:inline;"),
            metrics;
            style = "display:flex;align-items:center;",
        ),
        DOM.div(theme_btn; style = "flex-shrink:0;");
        style = "display:flex;justify-content:space-between;align-items:center;padding-bottom:16px;margin-bottom:20px;border-bottom:1px solid var(--border);",
    )
end
