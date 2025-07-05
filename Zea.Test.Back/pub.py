#!/usr/bin/env python3

import os
import subprocess
import sys
import shutil
import urllib.request

def check_python():
    if not shutil.which("python3"):
        print("\nERROR: python3 must be installed.\n")
        sys.exit(1)

def download_root_ca():
    if not os.path.exists("root-CA.crt"):
        print("\nDownloading AWS IoT Root CA certificate from AWS...\n")
        url = "https://www.amazontrust.com/repository/AmazonRootCA1.pem"
        urllib.request.urlretrieve(url, "root-CA.crt")

def clone_sdk():
    if not os.path.exists("aws-iot-device-sdk-python-v2"):
        print("\nCloning the AWS SDK...\n")
        subprocess.run([
            "git", "clone", "https://github.com/aws/aws-iot-device-sdk-python-v2.git", "--recursive"
        ], check=True)

def install_sdk():
    try:
        import awsiot  # noqa: F401
    except ImportError:
        print("\nInstalling AWS SDK...\n")
        result = subprocess.run([
            sys.executable, "-m", "pip", "install", "./aws-iot-device-sdk-python-v2"
        ])
        if result.returncode != 0:
            print("\nERROR: Failed to install SDK.\n")
            sys.exit(result.returncode)

def run_sample_app():
    print("\nRunning pub/sub sample application...\n")
    subprocess.run([
        sys.executable,
        "aws-iot-device-sdk-python-v2/samples/pubsub.py",
        "--endpoint", "a2s082f26l8xct-ats.iot.us-east-1.amazonaws.com",
        "--ca_file", "root-CA.crt",
        "--cert", "iot-collector-dev-sample-sensor.cert.pem",
        "--key", "iot-collector-dev-sample-sensor.private.key",
        "--client_id", "basicPubSub",
        "--topic", "device/device/data",
        "--count", "0"
    ], check=True)

if __name__ == "__main__":
    check_python()
    download_root_ca()
    clone_sdk()
    install_sdk()
    run_sample_app()