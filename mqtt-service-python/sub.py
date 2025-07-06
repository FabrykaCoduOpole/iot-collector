from awscrt import mqtt, http
from awsiot import mqtt_connection_builder
import sys
import threading
import json
import time
from datetime import datetime
import os
from dotenv import load_dotenv
import psycopg2
from psycopg2.extras import Json
from flask import Flask, jsonify, Response
from prometheus_client import Counter, Gauge, generate_latest, CONTENT_TYPE_LATEST
from utils.command_line_utils import CommandLineUtils
import socket

# Ładowanie zmiennych środowiskowych
load_dotenv()

# Konfiguracja Flask
app = Flask(__name__)
port = int(os.getenv('PORT', 3002))  # Zmień domyślny port na 3002

# Konfiguracja Prometheus
message_counter = Counter(
    'mqtt_messages_total',
    'Total MQTT messages received',
    ['topic', 'device_id']
)

# Dodatkowe metryki Prometheus
temperature_gauge = Gauge('iot_device_temperature_celsius', 'Current temperature reported by device', ['device_id'])
humidity_gauge = Gauge('iot_device_humidity_percent', 'Current humidity reported by device', ['device_id'])
last_seen_timestamp = Gauge('iot_device_last_seen_timestamp', 'Unix timestamp of last received message', ['device_id'])
salmon_stress_index = Gauge('salmon_stress_index', 'Stress index for salmon based on temperature and humidity', ['device_id'])

# Funkcja do obliczania indeksu stresu łososia
def calculate_salmon_stress(temperature, humidity):
    """
    Przykładowa formuła: zakładamy, że stres rośnie powyżej 18°C i wilgotności powyżej 50%
    """
    temp_factor = max(0, (temperature - 18) / 10)   # 0–1 w zakresie 18–28°C
    humidity_factor = max(0, (humidity - 50) / 50)  # 0–1 w zakresie 50–100%
    stress = (temp_factor + humidity_factor) / 2    # prosty uśredniony indeks
    return round(min(stress, 1.0), 2)

# Konfiguracja bazy danych
db_url = os.getenv('DATABASE_URL')
db_conn = None
db_available = True

def get_db_connection():
    global db_conn, db_available
    if not db_available:
        raise Exception("Database connection is not available")
    
    if db_conn is None or db_conn.closed:
        db_conn = psycopg2.connect(db_url)
    return db_conn

# Inicjalizacja bazy danych
def initialize_database():
    global db_available
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Tworzenie tabeli sensor_data, jeśli nie istnieje
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS sensor_data (
                id SERIAL PRIMARY KEY,
                device_id VARCHAR(50) NOT NULL,
                topic VARCHAR(100) NOT NULL,
                data JSONB NOT NULL,
                timestamp TIMESTAMP NOT NULL
            )
        ''')
        
        # Tworzenie indeksów
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_sensor_data_device_id ON sensor_data(device_id)
        ''')
        
        cursor.execute('''
            CREATE INDEX IF NOT EXISTS idx_sensor_data_timestamp ON sensor_data(timestamp)
        ''')
        
        conn.commit()
        cursor.close()
        print("Database initialized successfully")
    except Exception as e:
        db_available = False
        print(f"Warning: Could not initialize database: {e}")
        print("Continuing without database connection...")

# Parsowanie argumentów wiersza poleceń
cmdData = CommandLineUtils.parse_sample_input_pubsub()

received_count = 0
received_all_event = threading.Event()
mqtt_connection = None
mqtt_connected = False

def on_connection_interrupted(connection, error, **kwargs):
    global mqtt_connected
    mqtt_connected = False
    print(f"Connection interrupted. error: {error}")

def on_connection_resumed(connection, return_code, session_present, **kwargs):
    global mqtt_connected
    mqtt_connected = True
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

def save_message_to_db(topic, payload_str):
    global db_available
    try:
        # Parsowanie wiadomości JSON
        payload = json.loads(payload_str)
        device_id = payload.get('deviceId')
        
        if not device_id:
            print("Warning: Message does not contain deviceId field")
            return
        
        # Aktualizacja metryk Prometheus
        message_counter.labels(topic=topic, device_id=device_id).inc()
        
        # Aktualizacja metryk dla temperatury i wilgotności
        if 'temperature' in payload:
            temperature = float(payload['temperature'])
            temperature_gauge.labels(device_id=device_id).set(temperature)
            
        if 'humidity' in payload:
            humidity = float(payload['humidity'])
            humidity_gauge.labels(device_id=device_id).set(humidity)
        
        # Aktualizacja czasu ostatniego widzenia urządzenia
        last_seen_timestamp.labels(device_id=device_id).set(int(time.time()))
        
        # Obliczanie i aktualizacja indeksu stresu łososia
        if 'temperature' in payload and 'humidity' in payload:
            stress = calculate_salmon_stress(float(payload['temperature']), float(payload['humidity']))
            salmon_stress_index.labels(device_id=device_id).set(stress)
        
        # Zapisanie do bazy danych
        if db_available:
            try:
                conn = get_db_connection()
                cursor = conn.cursor()
                
                cursor.execute(
                    'INSERT INTO sensor_data (device_id, topic, data, timestamp) VALUES (%s, %s, %s, %s)',
                    (device_id, topic, Json(payload), datetime.now())
                )
                
                conn.commit()
                cursor.close()
                
                print(f"Stored data from {device_id}")
            except Exception as e:
                print(f"Warning: Could not save to database: {e}")
                print(f"Message would have been saved: {payload}")
        else:
            print(f"Database not available. Message would have been saved: {payload}")
    except json.JSONDecodeError:
        print(f"Error: Could not parse message as JSON: {payload_str}")
    except Exception as e:
        print(f"Error processing message: {e}")

def on_message_received(topic, payload, dup, qos, retain, **kwargs):
    payload_str = payload.decode('utf-8')
    print(f"Received message from topic '{topic}': {payload_str}")
    
    # Zapisanie wiadomości do bazy danych
    save_message_to_db(topic, payload_str)
    
    global received_count
    received_count += 1
    if cmdData.input_count != 0 and received_count >= cmdData.input_count:
        received_all_event.set()

def on_connection_success(connection, callback_data):
    global mqtt_connected
    mqtt_connected = True
    print(f"Connection Successful: return code {callback_data.return_code}, session present: {callback_data.session_present}")

def on_connection_failure(connection, callback_data):
    global mqtt_connected
    mqtt_connected = False
    print(f"Connection failed: {callback_data.error}")

def on_connection_closed(connection, callback_data):
    global mqtt_connected
    mqtt_connected = False
    print("Connection closed")

# Endpointy Flask
@app.route('/metrics')
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

@app.route('/health')
def health():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'mqtt': 'connected' if mqtt_connected else 'disconnected',
        'database': 'connected' if db_available else 'disconnected'
    })

def start_mqtt_client():
    global mqtt_connection
    
    proxy_options = None
    if cmdData.input_proxy_host and cmdData.input_proxy_port != 0:
        proxy_options = http.HttpProxyOptions(
            host_name=cmdData.input_proxy_host,
            port=cmdData.input_proxy_port
        )

    # Konfiguracja klienta MQTT
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
    print(f"Subscribing to topic '{message_topic}'...")
    subscribe_future, _ = mqtt_connection.subscribe(
        topic=message_topic,
        qos=mqtt.QoS.AT_LEAST_ONCE,
        callback=on_message_received
    )

    subscribe_result = subscribe_future.result()
    print(f"Subscribed with QoS: {subscribe_result['qos']}")

def find_available_port(start_port, max_attempts=10):
    """Znajdź dostępny port, zaczynając od start_port"""
    for port_offset in range(max_attempts):
        test_port = start_port + port_offset
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            sock.bind(('0.0.0.0', test_port))
            sock.close()
            return test_port
        except socket.error:
            continue
    raise RuntimeError(f"Could not find an available port after {max_attempts} attempts")

def main():
    # Inicjalizacja bazy danych
    initialize_database()
    
    # Uruchomienie klienta MQTT w osobnym wątku
    mqtt_thread = threading.Thread(target=start_mqtt_client)
    mqtt_thread.daemon = True
    mqtt_thread.start()
    
    # Znajdź dostępny port
    global port
    try:
        port = find_available_port(port)
    except RuntimeError as e:
        print(f"Error: {e}")
        print("Using a random high port instead")
        port = find_available_port(8000)
    
    # Uruchomienie serwera Flask
    print(f"MQTT service running on port {port}")
    app.run(host='0.0.0.0', port=port)

if __name__ == '__main__':
    main()
