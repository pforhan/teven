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

# Switch to the 'circleci' user
USER circleci

# Copy the Gradle wrapper and root build files with correct ownership
COPY --chown=circleci:circleci gradlew ./
COPY --chown=circleci:circleci settings.gradle.kts build.gradle.kts ./
COPY --chown=circleci:circleci gradle ./gradle

# trigger a download of the gradle wrapper
RUN ./gradlew --status --no-daemon

# Create backend directory and copy build.gradle.kts files for caching
RUN mkdir -p backend && find backend -name "build.gradle.kts" -exec cp --parents {} . \;

# Download dependencies for caching
RUN ./gradlew dependencies --no-daemon

# Copy the entire backend source code with correct ownership
COPY --chown=circleci:circleci backend ./backend

# Copy the built frontend assets from the frontend-builder stage with correct ownership
COPY --chown=circleci:circleci --from=frontend-builder /app/frontend/dist /app/backend/app/src/main/resources/static

# Build the application
RUN ./gradlew :backend:app:assemble --no-daemon

# Expose the port the application runs on
EXPOSE 8080

# Run the application
CMD ["java", "-jar", "backend/app/build/libs/app-all.jar"]
