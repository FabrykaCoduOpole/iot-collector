FROM node:18-alpine

WORKDIR /app

COPY apps/api-gateway/package*.json ./
RUN npm install --production

COPY apps/api-gateway/src ./src

EXPOSE 3000

CMD ["node", "src/index.js"]
