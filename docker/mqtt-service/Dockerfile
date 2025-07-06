FROM node:18-alpine

WORKDIR /app

# Copy package.json and package-lock.json
COPY apps/mqtt-service/package*.json ./

# Install dependencies
RUN npm install --production

# Copy source code
COPY apps/mqtt-service/src ./src

EXPOSE 3001

CMD ["node", "src/index.js"]
