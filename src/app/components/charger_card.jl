"""Get the CSS class for a status badge."""
function _badge_class(status::Symbol)
    if status == :Available || status == :Preparing
        "ov-badge ov-badge-available"
    elseif status == :Charging
        "ov-badge ov-badge-charging"
    elseif status in (:SuspendedEVSE, :SuspendedEV, :Finishing)
        "ov-badge ov-badge-suspended"
    elseif status == :Faulted
        "ov-badge ov-badge-faulted"
    else
        "ov-badge ov-badge-unavailable"
    end
end

"""Build a single charger card HTML string."""
function _charger_card_html(c::ChargerSnapshot)
    power_kw = round(c.power_w / 1000; digits = 2)
    energy_kwh = round(c.energy_wh / 1000; digits = 1)
    charging_time = if c.transaction_start_time !== nothing
        secs = round(Int, (now(UTC) - c.transaction_start_time).value / 1000)
        mins, s = divrem(secs, 60)
        hrs, m = divrem(mins, 60)
        lpad(hrs, 2, '0') * ":" * lpad(m, 2, '0') * ":" * lpad(s, 2, '0')
    else
        "--:--:--"
    end

    badge_cls = _badge_class(c.ocpp_status)
    status_str = string(c.ocpp_status)

    l1 = round(c.l1_power_w / 1000; digits = 1)
    l2 = round(c.l2_power_w / 1000; digits = 1)
    l3 = round(c.l3_power_w / 1000; digits = 1)

    tag_str = c.id_tag !== nothing ? c.id_tag : ""
    svc_str = c.service_name

    return """
    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;">
        <span style="font-weight:600;font-size:15px;">$(c.id)</span>
        <span class="$badge_cls">$status_str</span>
    </div>
    <div style="text-align:center;margin:16px 0;">
        <span class="ov-metric-large">$power_kw</span>
        <span class="ov-metric-unit">kW</span>
    </div>
    <div class="ov-metric-row" style="justify-content:center;">
        <div class="ov-metric-item">
            <span class="ov-metric-value">$(round(c.current_a; digits=1)) A</span>
            <span class="ov-metric-label">Current</span>
        </div>
        <div class="ov-metric-item">
            <span class="ov-metric-value">$energy_kwh kWh</span>
            <span class="ov-metric-label">Energy</span>
        </div>
        <div class="ov-metric-item">
            <span class="ov-metric-value">$charging_time</span>
            <span class="ov-metric-label">Time</span>
        </div>
    </div>
    <div class="ov-phase-row" style="justify-content:center;margin-top:8px;">
        <span>L1: $(l1) kW</span>
        <span>L2: $(l2) kW</span>
        <span>L3: $(l3) kW</span>
    </div>
    <div style="display:flex;justify-content:space-between;margin-top:12px;font-size:12px;color:var(--text-muted);">
        <span>$(tag_str)</span>
        <span>$svc_str</span>
    </div>
    """
end
