FROM node:20-alpine

WORKDIR /app

# Copy package files and install
COPY package*.json ./
RUN npm ci --omit=dev

# Copy source
COPY src/ ./src/

# Create data directory for SQLite
RUN mkdir -p /app/data

EXPOSE 3000

# Use WAL mode for better concurrency
ENV NODE_ENV=production
ENV DB_PATH=/app/data/hawler.db

CMD ["node", "src/index.js"]
