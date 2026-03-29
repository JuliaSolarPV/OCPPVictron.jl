# Pure functions for translating OCPP state to Victron dbus attributes.
# No IO, no side effects.

"""
    OCPP_TO_VICTRON_STATUS

Mapping from OCPP ChargePointStatus symbols to Victron EV charger status codes.
Victron codes: 0=Disconnected, 1=Connected, 2=Charging, 3=Charged.
"""
const OCPP_TO_VICTRON_STATUS = Dict{Symbol,Int}(
    :Available => 1,
    :Preparing => 1,
    :Charging => 2,
    :SuspendedEVSE => 3,
    :SuspendedEV => 3,
    :Finishing => 3,
    :Reserved => 1,
    :Unavailable => 0,
    :Faulted => 0,
)

"""
    victron_status(ocpp_status::Symbol) → Int

Map an OCPP ChargePointStatus to a Victron EV charger status code.
"""
function victron_status(ocpp_status::Symbol)::Int
    return get(OCPP_TO_VICTRON_STATUS, ocpp_status, 0)
end

"""
    victron_attributes(charger::ChargerState) → Dict{String,Any}

Convert a ChargerState into the set of Victron dbus attributes to publish.
Keys are attribute paths (e.g. "Ac/Power"), values are numbers.
"""
function victron_attributes(charger::ChargerState)::Dict{String,Any}
    charging_time = if charger.transaction_start_time !== nothing
        round(Int, (now(UTC) - charger.transaction_start_time).value / 1000)
    else
        0
    end

    return Dict{String,Any}(
        "Status" => victron_status(charger.ocpp_status),
        "Ac/Power" => round(charger.power_w; digits = 1),
        "Ac/L1/Power" => round(charger.l1_power_w; digits = 1),
        "Ac/L2/Power" => round(charger.l2_power_w; digits = 1),
        "Ac/L3/Power" => round(charger.l3_power_w; digits = 1),
        "Current" => round(charger.current_a; digits = 1),
        "Ac/Energy/Forward" => round(charger.energy_wh; digits = 1),
        "ChargingTime" => charging_time,
    )
end

"""
    update_from_meter_values!(charger::ChargerState, meter_value_list)

Parse OCPP MeterValues sampled values and update ChargerState fields.
Handles unit conversion (kW→W, kWh→Wh).

`meter_value_list` is the `req.meter_value` field from a MeterValuesRequest —
a vector of MeterValue objects, each containing a `sampled_value` vector.
"""
function update_from_meter_values!(charger::ChargerState, meter_value_list)
    for mv in meter_value_list
        sampled = if hasproperty(mv, :sampled_value)
            something(mv.sampled_value, [])
        else
            []
        end
        for sv in sampled
            _apply_sampled_value!(charger, sv)
        end
    end
    return nothing
end

"""Apply a single SampledValue to the ChargerState."""
function _apply_sampled_value!(charger::ChargerState, sv)
    raw = tryparse(Float64, string(sv.value))
    raw === nothing && return

    measurand = string(_get_field(sv, :measurand, "Energy.Active.Import.Register"))
    unit = string(_get_field(sv, :unit, _default_unit(measurand)))
    phase = _get_field(sv, :phase, nothing)
    phase_str = phase !== nothing ? string(phase) : nothing

    value = _convert_to_base_unit(raw, unit)

    if measurand == "Power.Active.Import"
        _apply_power!(charger, value, phase_str)
    elseif measurand == "Current.Import"
        charger.current_a = value
    elseif measurand == "Energy.Active.Import.Register"
        charger.energy_wh = value
    end

    return nothing
end

"""Apply power value, distributing to total and per-phase fields."""
function _apply_power!(charger::ChargerState, value::Float64, phase)
    if phase === nothing || phase == ""
        charger.power_w = value
    elseif phase == "L1" || phase == "L1-N"
        charger.l1_power_w = value
    elseif phase == "L2" || phase == "L2-N"
        charger.l2_power_w = value
    elseif phase == "L3" || phase == "L3-N"
        charger.l3_power_w = value
    end
    return nothing
end

"""Convert a value to base units (W or Wh)."""
function _convert_to_base_unit(value::Float64, unit::String)::Float64
    if unit == "kW" || unit == "kWh"
        return value * 1000.0
    end
    return value
end

"""Default unit for a measurand if not specified."""
function _default_unit(measurand::String)::String
    if startswith(measurand, "Power")
        return "W"
    elseif startswith(measurand, "Current")
        return "A"
    elseif startswith(measurand, "Energy")
        return "Wh"
    elseif startswith(measurand, "Voltage")
        return "V"
    end
    return "Wh"
end

"""Safely get an optional field from a dynamic struct."""
function _get_field(obj, field::Symbol, default)
    if hasproperty(obj, field)
        val = getproperty(obj, field)
        return val === nothing ? default : val
    end
    return default
end
