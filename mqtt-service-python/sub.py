from awscrt import mqtt, http
from awsiot import mqtt_connection_builder
import sys
import threading
from utils.command_line_utils import CommandLineUtils

cmdData = CommandLineUtils.parse_sample_input_pubsub()

received_count = 0
received_all_event = threading.Event()


def on_connection_interrupted(connection, error, **kwargs):
    print(f"Connection interrupted. error: {error}")


def on_connection_resumed(connection, return_code, session_present, **kwargs):
    print(f"Connection resumed. return_code: {return_code} session_present: {session_present}")
    if return_code == mqtt.ConnectReturnCode.ACCEPTED and not session_present:
        print("Session did not persist. Resubscribing to existing topics...")
        resubscribe_future, _ = connection.resubscribe_existing_topics()
        resubscribe_future.add_done_callback(on_resubscribe_complete)


def on_resubscribe_complete(resubscribe_future):
    resubscribe_results = resubscribe_future.result()
    print(f"Resubscribe results: {resubscribe_results}")
    for topic, qos in resubscribe_results['topics']:
        if qos is None:
            sys.exit(f"Server rejected resubscribe to topic: {topic}")


def save_message_to_db(topic, payload):
    pass

def on_message_received(topic, payload, dup, qos, retain, **kwargs):
    print(f"Received message from topic '{topic}': {payload}")
    save_message_to_db(topic, payload)
    global received_count
    received_count += 1
    if cmdData.input_count != 0 and received_count >= cmdData.input_count:
        received_all_event.set()


def on_connection_success(connection, callback_data):
    print(f"Connection Successful: return code {callback_data.return_code}, session present: {callback_data.session_present}")


def on_connection_failure(connection, callback_data):
    print(f"Connection failed: {callback_data.error}")


def on_connection_closed(connection, callback_data):
    print("Connection closed")


if __name__ == '__main__':
    proxy_options = None
    if cmdData.input_proxy_host and cmdData.input_proxy_port != 0:
        proxy_options = http.HttpProxyOptions(
            host_name=cmdData.input_proxy_host,
            port=cmdData.input_proxy_port
        )

    mqtt_connection = mqtt_connection_builder.mtls_from_path(
        endpoint=cmdData.input_endpoint,
        port=cmdData.input_port,
        cert_filepath=cmdData.input_cert,
        pri_key_filepath=cmdData.input_key,
        ca_filepath=cmdData.input_ca,
        on_connection_interrupted=on_connection_interrupted,
        on_connection_resumed=on_connection_resumed,
        client_id=cmdData.input_clientId,
        clean_session=False,
        keep_alive_secs=30,
        http_proxy_options=proxy_options,
        on_connection_success=on_connection_success,
        on_connection_failure=on_connection_failure,
        on_connection_closed=on_connection_closed
    )

    print(f"Connecting to {cmdData.input_endpoint} with client ID '{cmdData.input_clientId}'...")
    mqtt_connection.connect().result()
    print("Connected!")

    message_topic = cmdData.input_topic
    message_count = cmdData.input_count

    print(f"Subscribing to topic '{message_topic}'...")
    subscribe_future, _ = mqtt_connection.subscribe(
        topic=message_topic,
        qos=mqtt.QoS.AT_LEAST_ONCE,
        callback=on_message_received
    )

    subscribe_result = subscribe_future.result()
    print(f"Subscribed with QoS: {subscribe_result['qos']}")

    if message_count == 0:
        print("Listening indefinitely for messages. Press Ctrl+C to exit.")
        try:
            while True:
                threading.Event().wait(1)
        except KeyboardInterrupt:
            print("Interrupted by user.")
    else:
        print(f"Waiting to receive {message_count} message(s)...")
        received_all_event.wait()
        print(f"{received_count} message(s) received.")

    print("Disconnecting...")
    mqtt_connection.disconnect().result()
    print("Disconnected.")



"""
To run, use this: 
    python3 sub.py \
    --endpoint a2s082f26l8xct-ats.iot.us-east-1.amazonaws.com \
    --ca_file certs/root-CA.crt \
    --cert certs/iot-collector-dev-sample-sensor.cert.pem \
    --key certs/iot-collector-dev-sample-sensor.private.key \
    --client_id basicPubSub \
    --topic sdk/test/python \
    --count 0
"""