FROM node:18-alpine

WORKDIR /app

# Copy package.json and package-lock.json
COPY apps/api-gateway/package*.json ./

# Install dependencies
RUN npm install --production

# Copy source code
COPY apps/api-gateway/src ./src

EXPOSE 3000

CMD ["node", "src/index.js"]
