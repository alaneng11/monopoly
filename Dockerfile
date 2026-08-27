FROM node:20-alpine

WORKDIR /app

# Copy package files from backend/ and install
COPY backend/package*.json ./
RUN npm ci --omit=dev

# Copy backend source
COPY backend/src/ ./src/

# Create data directory for SQLite
RUN mkdir -p /app/data

EXPOSE 3000

ENV NODE_ENV=production
ENV DB_PATH=/app/data/hawler.db

CMD ["node", "src/index.js"]
