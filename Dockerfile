# Stage 1: Build the frontend
FROM node:20-slim as frontend-builder

WORKDIR /app/frontend

# Copy frontend project files
COPY frontend/package.json frontend/package-lock.json ./
COPY frontend/vite.config.ts ./
COPY frontend/tsconfig.json ./
COPY frontend/tsconfig.app.json ./
COPY frontend/tsconfig.node.json ./
COPY frontend/index.html ./
COPY frontend/eslint.config.js ./
COPY frontend/src ./src
COPY frontend/public ./public

# Install dependencies and build the frontend
RUN npm install
RUN npm run build

# Stage 2: Build the backend and create the final image
FROM cimg/openjdk:19.0-node

WORKDIR /app

# Copy the Gradle wrapper and root build files
COPY gradlew settings.gradle.kts build.gradle.kts ./
COPY gradle ./gradle

# Copy the entire backend source code
COPY backend ./backend

# Copy the built frontend assets from the frontend-builder stage
COPY --from=frontend-builder /app/frontend/dist /app/backend/app/src/main/resources/static

# Grant execute permission to the gradlew script
RUN chmod +x ./gradlew

# Build the application
RUN --mount=type=cache,target=/root/.gradle ./gradlew :backend:app:assemble --no-daemon

# Expose the port the application runs on
EXPOSE 8080

# Run the application
CMD ["java", "-jar", "backend/app/build/libs/app-all.jar"]