# Example: Simulate an EV charger connecting to the OCPPVictron bridge
#
# This script uses OCPPClient.jl to simulate a charger that:
#   1. Connects to the bridge via OCPP 1.6
#   2. Sends BootNotification
#   3. Reports Available status
#   4. Authorizes a tag, starts a transaction
#   5. Sends periodic MeterValues (power ramp up → hold → ramp down)
#   6. Stops the transaction
#   7. Disconnects
#
# Usage:
#   1. Start the bridge:  julia -e 'using OCPPVictron; OCPPVictron.start(; mqtt_host="127.0.0.1")'
#   2. Run this script:   julia --project=examples examples/simulate_charger.jl
#
# Or for local testing without MQTT, run the integration test instead.

using OCPPClient
using OCPPData
using Dates

const BRIDGE_URL = get(ENV, "OCPP_URL", "ws://127.0.0.1:9000")
const CHARGER_ID = get(ENV, "CHARGER_ID", "wallbox-sim-01")

function simulate_charging_session()
    println("=== OCPPVictron Charger Simulator ===")
    println("Connecting to $BRIDGE_URL as $CHARGER_ID...")

    cp = OCPPClient.ChargePoint(CHARGER_ID, "$BRIDGE_URL/ocpp"; reconnect = false)

    # Subscribe to events for logging
    OCPPClient.subscribe!(cp) do event
        if event isa OCPPClient.Connected
            println("  [event] Connected")
        elseif event isa OCPPClient.Disconnected
            println("  [event] Disconnected ($(event.reason))")
        end
    end

    # Connect
    conn_task = @async OCPPClient.connect!(cp)
    deadline = time() + 10.0
    while cp.status != :connected && time() < deadline
        sleep(0.1)
    end
    if cp.status != :connected
        println("ERROR: Could not connect to bridge")
        return
    end

    # 1. BootNotification
    println("\n--- BootNotification ---")
    resp = OCPPClient.boot_notification(
        cp;
        charge_point_vendor = "JuliaSolarPV",
        charge_point_model = "SimWallbox-7kW",
    )
    println("  Status: $(resp.status), Heartbeat interval: $(resp.interval)s")

    # 2. StatusNotification → Available
    println("\n--- StatusNotification: Available ---")
    OCPPClient.status_notification(
        cp;
        connector_id = 1,
        status = OCPPData.V16.ChargePointAvailable,
        error_code = OCPPData.V16.NoError,
    )
    println("  Reported Available")

    sleep(1)

    # 3. Authorize
    println("\n--- Authorize ---")
    resp = OCPPClient.authorize(cp; id_tag = "DEMO_USER")
    println("  Authorization: $(resp.id_tag_info.status)")

    # 4. StartTransaction
    println("\n--- StartTransaction ---")
    resp = OCPPClient.start_transaction(
        cp;
        connector_id = 1,
        id_tag = "DEMO_USER",
        meter_start = 0,
    )
    tx_id = resp.transaction_id
    println("  Transaction ID: $tx_id")

    # 5. StatusNotification → Charging
    OCPPClient.status_notification(
        cp;
        connector_id = 1,
        status = OCPPData.V16.ChargePointCharging,
        error_code = OCPPData.V16.NoError,
    )
    println("  Status: Charging")

    # 6. Simulate charging with MeterValues
    println("\n--- Charging Session ---")
    powers = [0, 1500, 3000, 5000, 7200, 7200, 7200, 7200, 5000, 3000, 1500, 0]
    energy_wh = 0.0

    for (i, power) in enumerate(powers)
        current = round(power / 230; digits = 1)
        energy_wh += power * 2.0 / 3600.0  # 2-second intervals

        sampled = OCPPData.V16.SampledValue[]
        push!(
            sampled,
            OCPPData.V16.SampledValue(;
                value = string(power),
                measurand = "Power.Active.Import",
                unit = "W",
            ),
        )
        push!(
            sampled,
            OCPPData.V16.SampledValue(;
                value = string(current),
                measurand = "Current.Import",
                unit = "A",
            ),
        )
        push!(
            sampled,
            OCPPData.V16.SampledValue(;
                value = string(round(energy_wh; digits = 1)),
                measurand = "Energy.Active.Import.Register",
                unit = "Wh",
            ),
        )

        mv = OCPPData.V16.MeterValue(;
            timestamp = Dates.format(now(UTC), dateformat"yyyy-mm-ddTHH:MM:SSZ"),
            sampled_value = sampled,
        )
        OCPPClient.meter_values(cp; connector_id = 1, meter_value = [mv])

        status = power > 0 ? "Charging" : "Idle"
        println(
            "  Step $i/$(length(powers)): $(power)W  $(current)A  $(round(energy_wh; digits=1))Wh  $status",
        )
        sleep(2)
    end

    # 7. StopTransaction
    println("\n--- StopTransaction ---")
    OCPPClient.stop_transaction(
        cp;
        transaction_id = tx_id,
        meter_stop = round(Int, energy_wh),
    )
    println("  Transaction stopped. Energy delivered: $(round(energy_wh; digits=1)) Wh")

    # 8. StatusNotification → Available
    OCPPClient.status_notification(
        cp;
        connector_id = 1,
        status = OCPPData.V16.ChargePointAvailable,
        error_code = OCPPData.V16.NoError,
    )
    println("  Status: Available")

    sleep(1)

    # 9. Disconnect
    println("\n--- Disconnecting ---")
    OCPPClient.disconnect!(cp)
    println("Done!")
end

simulate_charging_session()
