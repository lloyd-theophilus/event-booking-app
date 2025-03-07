# Builder stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files first for caching
COPY package.json package-lock.json* ./

# Install production dependencies only, with offline caching
RUN npm ci --omit=dev --prefer-offline

# Copy only necessary application files
COPY src ./src
COPY public ./public
# Add other required directories/files if needed (e.g., config/, lib/)

# ----------------------------
# Production stage
# ----------------------------
FROM node:18-alpine

WORKDIR /app

# Copy installed dependencies and app files from builder
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app ./

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000

# Expose application port
EXPOSE ${PORT}

# Start the application
CMD ["npm", "start"]
