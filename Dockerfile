# Use a base image with Java 19
FROM openjdk:19-jdk-slim

# Set the working directory inside the container
WORKDIR /app

# Copy the Gradle wrapper and root build files
COPY gradlew settings.gradle.kts build.gradle.kts ./
COPY gradle ./gradle

# Copy the entire backend source code
# Note: For more optimized layer caching, you could copy each module's build.gradle.kts
# file individually before copying the source. This is a simpler, more robust approach.
COPY backend ./backend

# Grant execute permission to the gradlew script
RUN chmod +x ./gradlew

# Build the application. The build command will also download dependencies.
# Using a cache mount helps speed this up on subsequent builds.
RUN --mount=type=cache,target=/root/.gradle ./gradlew :backend:app:assemble --no-daemon

# Expose the port the application runs on
EXPOSE 8080

# Run the application
CMD ["java", "-jar", "backend/app/build/libs/app-all.jar"]