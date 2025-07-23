
# Use a base image with Java 19
FROM openjdk:19-jdk-slim

# Set the working directory inside the container
WORKDIR /app

# Copy the Gradle build files and source code
COPY ../../backend /app/backend
COPY ../../gradle /app/gradle
COPY ../../build.gradle.kts /app/
COPY ../../settings.gradle.kts /app/

# Build the application
RUN --mount=type=cache,target=/root/.gradle ./gradlew -p backend assemble

# Expose the port the application runs on
EXPOSE 8080

# Run the application
CMD ["java", "-jar", "/app/backend/app/build/libs/app-0.0.1-all.jar"]
