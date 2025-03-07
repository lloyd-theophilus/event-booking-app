# Use Alpine-based Node.js 18 for a smaller and more secure base image
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Install system dependencies (if needed for native modules)
# RUN apk add --no-cache python3 make g++

# Copy package files first to leverage Docker layer caching
COPY package.json package-lock.json* ./

# Force install a compatible PostCSS version to fix the issue
#RUN npm install postcss@8.4.21 postcss-safe-parser@6.0.0 --legacy-peer-deps
RUN npm update postcss postcss-safe-parser 

# Install production dependencies using npm ci for deterministic builds
RUN npm ci --omit=dev

# Copy application files
COPY . .

# ----------------------------
# Production stage
# ----------------------------
FROM node:18-alpine

WORKDIR /app

# Copy installed dependencies from builder
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app ./

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000

# Expose application port
EXPOSE ${PORT}

# Start the application
CMD ["npm", "start"]  
