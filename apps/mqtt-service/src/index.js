require('dotenv').config();
const mqtt = require('mqtt');
const express = require('express');
const { Pool } = require('pg');
const client = require('prom-client');

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
const mqttClient = mqtt.connect(process.env.MQTT_BROKER_URL || 'mqtt://localhost:1883');

mqttClient.on('connect', () => {
  console.log('Connected to MQTT broker');
  mqttClient.subscribe('sensors/+/data'); // Subscribe to sensor data
});

mqttClient.on('message', async (topic, message) => {
  try {
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
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.listen(port, () => {
  console.log(`MQTT service running on port ${port}`);
});