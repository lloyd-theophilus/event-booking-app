# Use Node.js 18 (or your Jenkins-configured version)
FROM node:18

# Set working directory
WORKDIR /app

# Copy package.json and package-lock.json
COPY package.json package-lock.json ./

# Force install a compatible PostCSS version to fix the issue
RUN npm install postcss@8.4.21 postcss-safe-parser@6.0.0 --legacy-peer-deps

# Install dependencies
RUN npm install

# Copy the entire project
COPY . .

# Expose port 3000
EXPOSE 3000

# Set environment variable to prevent OpenSSL errors
ENV NODE_OPTIONS=--openssl-legacy-provider
ENV PORT=3000

# Start the application
CMD ["npm", "start"]




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