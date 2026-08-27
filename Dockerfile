FROM node:20-alpine

WORKDIR /app

# Copy package files from backend/ and install
COPY backend/package*.json ./
RUN npm install --omit=dev

# Copy backend source and board data
COPY backend/src/ ./src/
COPY backend/board_data.json ./

# Create data directory for SQLite fallback
RUN mkdir -p /app/data

EXPOSE 3000

ENV NODE_ENV=production
ENV DB_PATH=/app/data/hawler.db

# Just start the server — it handles migration + seed on startup
CMD ["node", "src/index.js"]
