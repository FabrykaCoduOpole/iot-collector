CREATE TABLE IF NOT EXISTS sensor_data (
  id SERIAL PRIMARY KEY,
  device_id VARCHAR(50) NOT NULL,
  topic VARCHAR(100) NOT NULL,
  data JSONB NOT NULL,
  timestamp TIMESTAMP NOT NULL
);

CREATE INDEX idx_sensor_data_device_id ON sensor_data(device_id);
CREATE INDEX idx_sensor_data_timestamp ON sensor_data(timestamp);
