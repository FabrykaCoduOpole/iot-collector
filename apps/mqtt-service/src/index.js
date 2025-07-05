require('dotenv').config();
const mqtt = require('mqtt');
const express = require('express');
const { Pool } = require('pg');
const client = require('prom-client');
const fs = require('fs');

// Prometheus metrics
const messageCounter = new client.Counter({
  name: 'mqtt_messages_total',
  help: 'Total MQTT messages received',
  labelNames: ['topic', 'device_id']
});

const app = express();
const port = process.env.PORT || 3001;

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

// MQTT Client setup
console.log('Connecting to MQTT broker:', process.env.MQTT_BROKER_URL);

// For AWS IoT Core, we need to use WebSocket
const mqttOptions = {
  clientId: process.env.MQTT_CLIENT_ID || `mqtt-service-${Math.random().toString(16).slice(2, 8)}`,
  clean: true,
  connectTimeout: 4000,
  reconnectPeriod: 1000,
  protocol: 'wss', // Use WebSocket Secure
};

// Connect to AWS IoT Core using WebSocket
const mqttClient = mqtt.connect(`wss://${process.env.MQTT_BROKER_URL.replace('mqtts://', '').replace(':8883', '/mqtt')}`, mqttOptions);

mqttClient.on('connect', () => {
  console.log('Connected to MQTT broker');
  const topic = process.env.MQTT_TOPIC || 'sensors/+/data';
  console.log(`Subscribing to topic: ${topic}`);
  mqttClient.subscribe(topic);
});

mqttClient.on('error', (error) => {
  console.error('MQTT connection error:', error);
});

mqttClient.on('message', async (topic, message) => {
  try {
    console.log(`Received message on topic ${topic}: ${message.toString()}`);
    const data = JSON.parse(message.toString());
    
    // Update metrics
    messageCounter.inc({ topic, device_id: data.deviceId });
    
    // Store in database
    await pool.query(
      'INSERT INTO sensor_data (device_id, topic, data, timestamp) VALUES ($1, $2, $3, $4)',
      [data.deviceId, topic, data, new Date()]
    );
    
    console.log(`Stored data from ${data.deviceId}`);
  } catch (error) {
    console.error('Error processing message:', error);
  }
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    mqtt: mqttClient.connected ? 'connected' : 'disconnected'
  });
});

app.listen(port, () => {
  console.log(`MQTT service running on port ${port}`);
});
