FROM node:20-alpine

WORKDIR /app

# Copy package files from backend/ and install
COPY backend/package*.json ./
RUN npm ci --omit=dev

# Copy backend source and board data
COPY backend/src/ ./src/
COPY backend/board_data.json ./

# Create data directory for SQLite fallback
RUN mkdir -p /app/data

EXPOSE 3000

ENV NODE_ENV=production
ENV DB_PATH=/app/data/hawler.db

# Run migrations, seed, then start server
CMD ["sh", "-c", "node src/migrate.js; node src/seed.js; node src/index.js"]
