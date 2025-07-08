import argparse
from awscrt import io

class CommandLineUtils:
    @staticmethod
    def parse_sample_input_pubsub():
        parser = argparse.ArgumentParser(description="Send and receive messages through an MQTT connection.")
        parser.add_argument('--endpoint', required=True, help="Your AWS IoT custom endpoint, not including a port.")
        parser.add_argument('--ca_file', help="File path to root certificate authority.")
        parser.add_argument('--cert', help="File path to certificate.")
        parser.add_argument('--key', help="File path to private key.")
        parser.add_argument('--client_id', default='mqtt-service', help="MQTT client ID.")
        parser.add_argument('--topic', default='sensors/+/data', help="Topic to subscribe to.")
        parser.add_argument('--count', default=0, type=int, help="Number of messages to receive before exiting. 0 = unlimited.")
        parser.add_argument('--proxy_host', help="Hostname of proxy to connect to.")
        parser.add_argument('--proxy_port', type=int, default=8080, help="Port of proxy to connect to.")
        parser.add_argument('--verbosity', choices=[x.name for x in io.LogLevel], default=io.LogLevel.NoLogs.name,
                            help='Logging level')

        args = parser.parse_args()

        # Konwersja argumentów na format używany przez aplikację
        result = type('obj', (object,), {
            'input_endpoint': args.endpoint,
            'input_ca': args.ca_file,
            'input_cert': args.cert,
            'input_key': args.key,
            'input_clientId': args.client_id,
            'input_topic': args.topic,
            'input_count': args.count,
            'input_proxy_host': args.proxy_host,
            'input_proxy_port': args.proxy_port,
            'input_port': 8883
        })

        return result
