require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { Pool } = require('pg');
const client = require('prom-client');
const swaggerUi = require('swagger-ui-express');
const swaggerJsdoc = require('swagger-jsdoc');

// Initialize Express app
const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(helmet());
app.use(morgan('combined'));
app.use(express.json());

// Prometheus metrics
const httpRequests = new client.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status']
});

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10]
});

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

// Middleware for metrics
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const route = req.route ? req.route.path : req.path;
    
    httpRequests.inc({ 
      method: req.method, 
      route: route,
      status: res.statusCode 
    });
    
    httpRequestDuration.observe(
      { 
        method: req.method, 
        route: route,
        status: res.statusCode 
      },
      duration
    );
  });
  
  next();
});

// Swagger configuration
const swaggerOptions = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'IoT Data Collector API',
      version: '1.0.0',
      description: 'API for accessing IoT sensor data',
    },
    servers: [
      {
        url: `http://localhost:${port}`,
        description: 'Development server',
      },
    ],
  },
  apis: ['./src/*.js'],
};

const swaggerSpec = swaggerJsdoc(swaggerOptions);
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

/**
 * @swagger
 * /api/devices:
 *   get:
 *     summary: Get all devices
 *     description: Retrieve a list of all devices that have sent data
 *     responses:
 *       200:
 *         description: A list of devices
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *                 properties:
 *                   device_id:
 *                     type: string
 */
app.get('/api/devices', async (req, res) => {
  try {
    const result = await pool.query('SELECT DISTINCT device_id FROM sensor_data');
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching devices:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * @swagger
 * /api/devices/{deviceId}/data:
 *   get:
 *     summary: Get device data
 *     description: Retrieve data for a specific device
 *     parameters:
 *       - in: path
 *         name: deviceId
 *         required: true
 *         description: ID of the device
 *         schema:
 *           type: string
 *       - in: query
 *         name: limit
 *         description: Maximum number of records to return
 *         schema:
 *           type: integer
 *           default: 100
 *       - in: query
 *         name: from
 *         description: Start timestamp (ISO format)
 *         schema:
 *           type: string
 *           format: date-time
 *       - in: query
 *         name: to
 *         description: End timestamp (ISO format)
 *         schema:
 *           type: string
 *           format: date-time
 *     responses:
 *       200:
 *         description: Device data
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 type: object
 *                 properties:
 *                   id:
 *                     type: integer
 *                   device_id:
 *                     type: string
 *                   topic:
 *                     type: string
 *                   data:
 *                     type: object
 *                   timestamp:
 *                     type: string
 *                     format: date-time
 */
app.get('/api/devices/:deviceId/data', async (req, res) => {
  try {
    const { deviceId } = req.params;
    const { limit = 100, from, to } = req.query;
    
    let query = 'SELECT * FROM sensor_data WHERE device_id = $1';
    const queryParams = [deviceId];
    
    if (from) {
      query += ' AND timestamp >= $' + (queryParams.length + 1);
      queryParams.push(from);
    }
    
    if (to) {
      query += ' AND timestamp <= $' + (queryParams.length + 1);
      queryParams.push(to);
    }
    
    query += ' ORDER BY timestamp DESC LIMIT $' + (queryParams.length + 1);
    queryParams.push(limit);
    
    const result = await pool.query(query, queryParams);
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching device data:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * @swagger
 * /api/stats:
 *   get:
 *     summary: Get statistics
 *     description: Retrieve statistics about the collected data
 *     responses:
 *       200:
 *         description: Statistics
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 deviceCount:
 *                   type: integer
 *                 messageCount:
 *                   type: integer
 *                 lastMessageTime:
 *                   type: string
 *                   format: date-time
 */
app.get('/api/stats', async (req, res) => {
  try {
    const deviceCountResult = await pool.query('SELECT COUNT(DISTINCT device_id) as device_count FROM sensor_data');
    const messageCountResult = await pool.query('SELECT COUNT(*) as message_count FROM sensor_data');
    const lastMessageResult = await pool.query('SELECT MAX(timestamp) as last_message_time FROM sensor_data');
    
    res.json({
      deviceCount: parseInt(deviceCountResult.rows[0].device_count),
      messageCount: parseInt(messageCountResult.rows[0].message_count),
      lastMessageTime: lastMessageResult.rows[0].last_message_time
    });
  } catch (error) {
    console.error('Error fetching statistics:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * @swagger
 * /metrics:
 *   get:
 *     summary: Get metrics
 *     description: Retrieve Prometheus metrics
 *     responses:
 *       200:
 *         description: Prometheus metrics
 *         content:
 *           text/plain:
 *             schema:
 *               type: string
 */
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});

/**
 * @swagger
 * /health:
 *   get:
 *     summary: Health check
 *     description: Check if the API is healthy
 *     responses:
 *       200:
 *         description: Health status
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                 timestamp:
 *                   type: string
 *                   format: date-time
 */
app.get('/health', async (req, res) => {
  try {
    // Check database connection
    await pool.query('SELECT 1');
    
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      services: {
        database: 'connected'
      }
    });
  } catch (error) {
    console.error('Health check failed:', error);
    res.status(500).json({
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      services: {
        database: 'disconnected'
      },
      error: error.message
    });
  }
});

// Start the server
app.listen(port, () => {
  console.log(`API Gateway running on port ${port}`);
});
