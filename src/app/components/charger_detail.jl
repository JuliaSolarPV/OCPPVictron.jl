"""Build the charger detail view (full page takeover)."""
function build_charger_detail(app_state::AppState, charger_id::String)
    back_btn = Button("Back to Overview")
    on(back_btn.value) do _
        app_state.selected_charger[] = nothing
    end

    charger_info = map(app_state.chargers) do chargers
        idx = findfirst(c -> c.id == charger_id, chargers)
        if idx === nothing
            return Card(DOM.p("Charger $charger_id disconnected."))
        end
        c = chargers[idx]

        identity = Card(
            Col(
                Row(
                    DOM.h3(c.id),
                    DOM.span(string(c.ocpp_status); class = _badge_class(c.ocpp_status));
                    justify_content = "space-between",
                    align_items = "center",
                    height = "auto",
                ),
                Grid(
                    Labeled(DOM.span(something(c.vendor, "Unknown")), "Vendor"),
                    Labeled(DOM.span(something(c.model, "Unknown")), "Model"),
                    Labeled(DOM.span(something(c.serial_number, "N/A")), "Serial"),
                    Labeled(DOM.span(something(c.firmware, "N/A")), "Firmware");
                    columns = "1fr 1fr",
                    gap = "8px",
                    height = "auto",
                );
                gap = "12px",
                height = "auto",
            ),
        )

        power_kw = round(c.power_w / 1000; digits = 2)
        energy_kwh = round(c.energy_wh / 1000; digits = 1)

        metrics = Card(
            Row(
                Labeled(
                    DOM.span("$power_kw kW"; style = "font-size:28px;font-weight:700;"),
                    "Power",
                ),
                Labeled(
                    DOM.span(
                        "$(round(c.current_a; digits=1)) A";
                        style = "font-size:20px;font-weight:600;",
                    ),
                    "Current",
                ),
                Labeled(
                    DOM.span("$energy_kwh kWh"; style = "font-size:20px;font-weight:600;"),
                    "Energy",
                );
                gap = "24px",
                justify_content = "center",
                height = "auto",
            ),
        )

        victron_color = c.victron_registered ? "#22c55e" : "#6b7280"
        victron_label = c.victron_registered ? "Registered" : "Not registered"

        victron = Card(
            Col(
                DOM.h3("Victron Integration"; style = "font-size:15px;"),
                Row(
                    Labeled(DOM.span(c.service_name), "Service"),
                    Labeled(
                        DOM.span(
                            victron_label;
                            style = "color:$victron_color;font-weight:600;",
                        ),
                        "Status",
                    );
                    gap = "24px",
                    height = "auto",
                );
                gap = "8px",
                height = "auto",
            ),
        )

        Col(identity, metrics, victron; gap = "16px", height = "auto")
    end

    power_chart = build_power_chart(app_state, charger_id)
    current_chart = build_current_chart(app_state, charger_id)
    charts =
        Grid(power_chart, current_chart; columns = "1fr 1fr", gap = "16px", height = "auto")

    controls = _build_controls(app_state, charger_id)

    return Col(back_btn, charger_info, charts, controls; gap = "16px", height = "auto")
end

"""Build the controls panel for a charger detail view."""
function _build_controls(app_state::AppState, charger_id::String)
    result_text = Observable("")

    current_slider = Bonito.Slider(6:32)
    current_slider.value[] = 16

    slider_label = map(current_slider.value) do v
        "$(v) A"
    end

    apply_btn = Button("Apply Limit")
    on(apply_btn.value) do _
        amps = current_slider.value[]
        result_text[] = "Set charging current to $(amps)A"
        _send_charger_command!(
            app_state,
            charger_id,
            result_text,
            "SetChargingProfile",
            Dict(
                "connectorId" => 1,
                "csChargingProfiles" => Dict(
                    "chargingProfileId" => 1,
                    "stackLevel" => 0,
                    "chargingProfilePurpose" => "TxDefaultProfile",
                    "chargingProfileKind" => "Relative",
                    "chargingSchedule" => Dict(
                        "chargingRateUnit" => "A",
                        "chargingSchedulePeriod" =>
                            [Dict("startPeriod" => 0, "limit" => Float64(amps))],
                    ),
                ),
            ),
        )
    end

    reset_btn = Button("Hard Reset")
    on(reset_btn.value) do _
        _send_charger_command!(
            app_state,
            charger_id,
            result_text,
            "Reset",
            Dict("type" => "Hard"),
        )
    end

    return Card(
        Col(
            DOM.h3("Controls"),
            Grid(
                Col(
                    Labeled(current_slider, "Current Limit"),
                    DOM.span(slider_label; style = "font-weight:600;"),
                    apply_btn;
                    gap = "8px",
                    height = "auto",
                ),
                Col(
                    DOM.div("Actions"; style = "font-size:13px;color:var(--text-muted);"),
                    reset_btn;
                    gap = "8px",
                    height = "auto",
                );
                columns = "1fr 1fr",
                gap = "16px",
                height = "auto",
            ),
            DOM.div(
                result_text;
                style = "font-size:13px;color:#3b82f6;font-family:monospace;",
            );
            gap = "12px",
            height = "auto",
        ),
    )
end

"""Send an OCPP command to a charger."""
function _send_charger_command!(
    app_state::AppState,
    charger_id::String,
    result_text::Observable,
    action::String,
    payload::Dict,
)
    cs = app_state.bridge_state.central_system
    if !OCPPServer.is_connected(cs, charger_id)
        result_text[] = "Charger $charger_id is offline"
        return
    end
    @async try
        session = OCPPServer.get_session(cs, charger_id)
        resp = OCPPServer.send_call(session, action, payload; timeout = 10.0)
        result_text[] = "$action -> $(JSON.json(resp))"
    catch e
        result_text[] = "$action failed: $e"
    end
end
