# MQTT integration with Victron Venus OS via dbus-mqtt-devices protocol.

"""
    connect_mqtt!(state::BridgeState)

Connect to the Venus OS MQTT broker and subscribe to the DBus response topic.
"""
function connect_mqtt!(state::BridgeState)
    config = state.config
    client, connection = MQTTClient.MakeConnection(
        config.mqtt_host,
        config.mqtt_port;
        client_id = config.mqtt_client_id,
    )
    MQTTClient.connect(client, connection)
    state.mqtt_client = client

    # Subscribe to DBus registration responses
    dbus_topic = "device/$(config.mqtt_client_id)/DBus"
    MQTTClient.subscribe(
        client,
        dbus_topic,
        (topic, payload) -> _on_dbus_response!(state, topic, payload);
        qos = MQTTClient.QOS_1,
    )

    @info "MQTT connected" host = config.mqtt_host port = config.mqtt_port
    return nothing
end

"""
    _on_dbus_response!(state::BridgeState, topic, payload)

Handle the DBus registration response from dbus-mqtt-devices.
Populates portal_id, device_instance, and topic_path_w for each service.
"""
function _on_dbus_response!(state::BridgeState, _topic, payload)
    msg = JSON.parse(String(payload))
    lock(state.lock) do
        for (cp_id, device) in state.devices
            svc = device.service_name
            if haskey(msg, "deviceInstance") && haskey(msg["deviceInstance"], svc)
                device.portal_id = get(msg, "portalId", nothing)
                device.device_instance = msg["deviceInstance"][svc]
                device.topic_path_w = msg["topicPath"][svc]["W"]
                device.registered = true
                @info "Victron device registered" charge_point_id = cp_id service = svc device_instance =
                    device.device_instance
            end
        end
    end
    return nothing
end

"""
    register_device!(state::BridgeState, charger_id::String)

Register (or re-register) a charger as a Victron dbus evcharger device.
Publishes the full services dict including ALL currently active devices.
"""
function register_device!(state::BridgeState, charger_id::String)
    state.mqtt_client === nothing && return

    services = Dict{String,String}()
    lock(state.lock) do
        for (_, device) in state.devices
            services[device.service_name] = device.device_type
        end
    end

    config = state.config
    status_topic = "device/$(config.mqtt_client_id)/Status"
    status_payload = JSON.json(
        Dict(
            "clientId" => config.mqtt_client_id,
            "connected" => 1,
            "version" => "v1.0 OCPPVictron.jl",
            "services" => services,
        ),
    )
    MQTTClient.publish(
        state.mqtt_client,
        status_topic,
        status_payload;
        qos = MQTTClient.QOS_1,
    )
    @info "Published Victron registration" trigger = charger_id services = keys(services)
    return nothing
end

"""
    publish_charger_state!(state::BridgeState, charger_id::String)

Publish all current Victron attributes for a charger to its dbus topic path.
Skips silently if the device is not yet registered.
"""
function publish_charger_state!(state::BridgeState, charger_id::String)
    state.mqtt_client === nothing && return

    charger = lock(state.lock) do
        get(state.chargers, charger_id, nothing)
    end
    charger === nothing && return

    device = lock(state.lock) do
        get(state.devices, charger_id, nothing)
    end
    device === nothing && return
    device.registered || return

    attrs = victron_attributes(charger)
    for (attr, value) in attrs
        topic = "$(device.topic_path_w)/$(attr)"
        payload = JSON.json(Dict("value" => value))
        MQTTClient.publish(state.mqtt_client, topic, payload)
    end
    return nothing
end

"""
    unregister_device!(state::BridgeState, charger_id::String)

Remove a charger from the Victron dbus. Re-publishes the services dict
without this charger, or publishes connected=0 if no devices remain.
"""
function unregister_device!(state::BridgeState, charger_id::String)
    state.mqtt_client === nothing && return

    # Collect remaining services (excluding the one being removed)
    services = Dict{String,String}()
    lock(state.lock) do
        for (cp_id, device) in state.devices
            cp_id == charger_id && continue
            services[device.service_name] = device.device_type
        end
    end

    config = state.config
    status_topic = "device/$(config.mqtt_client_id)/Status"

    connected = isempty(services) ? 0 : 1
    status_payload = JSON.json(
        Dict(
            "clientId" => config.mqtt_client_id,
            "connected" => connected,
            "version" => "v1.0 OCPPVictron.jl",
            "services" => services,
        ),
    )
    MQTTClient.publish(
        state.mqtt_client,
        status_topic,
        status_payload;
        qos = MQTTClient.QOS_1,
    )
    return nothing
end

"""
    disconnect_mqtt!(state::BridgeState)

Unregister all devices and disconnect from the MQTT broker cleanly.
"""
function disconnect_mqtt!(state::BridgeState)
    state.mqtt_client === nothing && return

    # Publish disconnected status
    config = state.config
    status_topic = "device/$(config.mqtt_client_id)/Status"
    status_payload = JSON.json(
        Dict(
            "clientId" => config.mqtt_client_id,
            "connected" => 0,
            "version" => "v1.0 OCPPVictron.jl",
            "services" => Dict{String,String}(),
        ),
    )
    MQTTClient.publish(
        state.mqtt_client,
        status_topic,
        status_payload;
        qos = MQTTClient.QOS_1,
    )

    sleep(0.5)  # allow message to be sent
    MQTTClient.disconnect(state.mqtt_client)
    state.mqtt_client = nothing
    @info "MQTT disconnected"
    return nothing
end
