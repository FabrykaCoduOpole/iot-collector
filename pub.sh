#!/bin/bash

# Konfiguracja
ENDPOINT_URL="https://a2s082f26l8xct-ats.iot.us-east-1.amazonaws.com"
TOPIC="sdk/test/python"
DURATION=45  # czas trwania w sekundach
INTERVAL=1   # odstęp między wysyłkami
DEVICES=("my1" "my2" "my3" "my4")

# Funkcja do losowego generowania temperatury i wilgotności
generate_payload() {
    local device_id=$1
    local temperature=$(awk -v r=$RANDOM 'BEGIN { srand(); printf "%.1f", 18 + (r % 150) / 10 }')
    local humidity=$(awk -v r=$RANDOM 'BEGIN { srand(); printf "%.1f", 30 + (r % 300) / 10 }')
    echo "{\"deviceId\":\"$device_id\",\"temperature\":$temperature,\"humidity\":$humidity}"
}

echo "▶️ Starting simulation for ${#DEVICES[@]} devices for $DURATION seconds..."

# Główna pętla czasowa
for ((i = 0; i < DURATION; i += INTERVAL)); do
  for device in "${DEVICES[@]}"; do
    payload=$(generate_payload "$device")
    echo "Sending from $device: $payload"
    
    aws iot-data publish \
      --endpoint-url "$ENDPOINT_URL" \
      --topic "$TOPIC" \
      --cli-binary-format raw-in-base64-out \
      --payload "$payload" &
  done

  wait  # upewniamy się, że wszystkie wysyłki się zakończą przed kolejną sekundą
  sleep $INTERVAL
done

echo " Simulation finished."