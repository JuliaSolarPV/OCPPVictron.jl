"""Build the Configuration page."""
function build_config_page(app_state::AppState)
    config = app_state.bridge_state.config
    result_text = Observable("")

    # ── Bridge Settings ──
    bridge_info = Card(
        Col(
            DOM.h3("Bridge Settings"),
            Grid(
                Labeled(DOM.span(config.ocpp_host), "OCPP Host"),
                Labeled(DOM.span(string(config.ocpp_port)), "OCPP Port"),
                Labeled(DOM.span(config.ocpp_version), "Version"),
                Labeled(DOM.span(string(config.heartbeat_interval) * "s"), "Heartbeat"),
                Labeled(DOM.span(config.mqtt_host), "MQTT Host"),
                Labeled(DOM.span(string(config.mqtt_port)), "MQTT Port"),
                Labeled(DOM.span(config.mqtt_client_id), "Client ID"),
                Labeled(DOM.span(config.auto_authorize ? "Yes" : "No"), "Auto-authorize");
                columns = "1fr 1fr",
                gap = "12px",
                height = "auto",
            );
            gap = "12px",
            height = "auto",
        ),
    )

    # ── Chargers Table ──
    chargers_content = map(app_state.chargers) do _
        if isempty(config.chargers)
            return DOM.p(
                "No chargers configured yet. They are auto-added when they connect.";
                style = "color:var(--text-muted);",
            )
        end

        rows = [
            (
                ID = c.charge_point_id,
                Service = c.service_name,
                Enabled = c.enabled ? "Yes" : "No",
            ) for c in config.chargers
        ]

        Bonito.Table(rows)
    end

    chargers_section = Card(
        Col(
            DOM.h3("Known Chargers"),
            DOM.p(
                "Chargers are auto-added when they first connect.";
                style = "color:var(--text-muted);font-size:13px;",
            ),
            chargers_content;
            gap = "8px",
            height = "auto",
        ),
    )

    # ── Reload ──
    reload_btn = Button("Reload Config")
    on(reload_btn.value) do _
        try
            new_config = load_config(config.config_path)
            config.heartbeat_interval = new_config.heartbeat_interval
            config.auto_authorize = new_config.auto_authorize
            config.chargers = new_config.chargers
            result_text[] = "Config reloaded from $(config.config_path)"
        catch e
            result_text[] = "Reload failed: $e"
        end
    end

    config_info = Card(
        Col(
            Row(
                DOM.span(
                    "Config: $(config.config_path)";
                    style = "color:var(--text-muted);font-size:13px;",
                ),
                reload_btn;
                justify_content = "space-between",
                align_items = "center",
                height = "auto",
            ),
            DOM.div(
                result_text;
                style = "font-size:13px;color:#3b82f6;font-family:monospace;",
            );
            gap = "8px",
            height = "auto",
        ),
    )

    return Col(bridge_info, chargers_section, config_info; gap = "16px", height = "auto")
end
