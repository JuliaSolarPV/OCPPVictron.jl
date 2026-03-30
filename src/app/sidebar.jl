const _NAV_BUTTON_STYLE = Styles(
    CSS(
        "background" => "transparent",
        "border" => "none",
        "color" => "#cbd5e1",
        "font-size" => "14px",
        "padding" => "10px 20px",
        "width" => "100%",
        "text-align" => "left",
        "cursor" => "pointer",
    ),
    CSS(":hover", "color" => "white", "background" => "rgba(255,255,255,0.05)"),
)

"""Build the sidebar navigation component."""
function build_sidebar(app_state::AppState)
    nav_items = [
        (:dashboard, "Dashboard"),
        (:config, "Configuration"),
        (:logs, "Logs"),
        (:sessions, "Sessions"),
    ]

    buttons = Any[]
    for (page, label) in nav_items
        btn = Button(label; style = _NAV_BUTTON_STYLE)
        on(btn.value) do _
            app_state.active_page[] = page
        end
        indicator = map(app_state.active_page) do active
            if active == page
                DOM.div(
                    btn;
                    style = "border-left:3px solid #2563eb;background:rgba(37,99,235,0.15);",
                )
            else
                DOM.div(btn; style = "border-left:3px solid transparent;")
            end
        end
        push!(buttons, indicator)
    end

    # Connection status pinned to bottom via margin-top:auto
    connection_status = map(app_state.chargers) do chargers
        n = length(chargers)
        dot_color = n > 0 ? "#22c55e" : "#6b7280"
        label = n > 0 ? "$n charger$(n == 1 ? "" : "s") online" : "No chargers"
        DOM.div(
            DOM.span(;
                style = "display:inline-block;width:8px;height:8px;border-radius:50%;background:$dot_color;margin-right:6px;",
            ),
            label;
            style = "font-size:12px;color:#94a3b8;padding:12px 20px;margin-top:auto;",
        )
    end

    # Use a plain flex column — NOT Bonito Col (which sets height:100% and adds grid)
    return DOM.div(
        DOM.div(
            "OCPPVictron";
            style = "color:white;font-size:18px;font-weight:700;padding:16px 20px 12px;border-bottom:1px solid rgba(255,255,255,0.1);",
        ),
        DOM.div(buttons...; style = "padding-top:4px;"),
        connection_status;
        style = "width:220px;background:var(--bg-sidebar);display:flex;flex-direction:column;min-height:100vh;border-right:1px solid rgba(255,255,255,0.1);",
    )
end
