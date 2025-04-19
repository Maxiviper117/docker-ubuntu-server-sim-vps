# Build stage
FROM node:22-alpine AS builder

WORKDIR /usr/src/app

# Copy package files
COPY package*.json ./

# Install all dependencies (including devDependencies)
RUN npm ci

# Copy source
COPY . .

# If you have a build step, add it here
# RUN npm run build

# Production stage
FROM node:22-alpine

WORKDIR /usr/src/app

# Copy package files
COPY package*.json ./

# Install only production dependencies
RUN npm ci --only=production && \
    npm cache clean --force

# Copy built app from builder stage
COPY --from=builder /usr/src/app/index.js ./

# Add non-root user
RUN addgroup -g 1001 nodeapp && \
    adduser -S -u 1001 -G nodeapp nodeapp

# Set ownership
RUN chown -R nodeapp:nodeapp .

# Switch to non-root user
USER nodeapp

EXPOSE 3000

CMD ["node", "index.js"]

# build image:
# docker build -t express-app-test .

# Tag the image for Docker Hub:
# docker tag express-app-test maxiviper117/express-app-test:latest

# Push the image to Docker Hub:
# docker push maxiviper117/express-app-test:latest

# single powershell command to build, tag, and push the image:
# docker build -t express-app-test . ; docker tag express-app-test maxiviper117/express-app-test:latest ; docker push maxiviper117/express-app-test:latest

# Login to Docker Hub:
# docker login