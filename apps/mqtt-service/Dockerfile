# docker/mqtt-service/Dockerfile
FROM node:18-alpine

WORKDIR /app

COPY apps/mqtt-service/package*.json ./
RUN npm ci --only=production

COPY apps/mqtt-service/src ./src

EXPOSE 3001

CMD ["node", "src/index.js"]