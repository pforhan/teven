# Which web bundle to compile into the backend jar: `react` (the live app until
# Phase 10) or `flutter`. Both pipelines stay buildable during the migration.
#
# Must be declared before the first FROM: Docker only substitutes build args into
# FROM instructions when they are in the global scope, and the stage selector
# below relies on that.
ARG WEB_SOURCE=react

# Stage 1: Gradle setup
FROM cimg/openjdk:19.0-node AS gradle-setup

WORKDIR /app

# Switch to the 'circleci' user
USER circleci

# Copy the Gradle wrapper and root build files with correct ownership
COPY --chown=circleci:circleci gradlew ./
COPY --chown=circleci:circleci settings.gradle.kts build.gradle.kts ./
COPY --chown=circleci:circleci gradle ./gradle

# trigger a download of the gradle wrapper
RUN ./gradlew --status --no-daemon

CMD ["/bin/bash", "-c", "ls -la /app"]

# Stage 2a: Build the React frontend (legacy; live app until Phase 10)
FROM node:20-slim AS frontend-react

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

# Normalize the output location so the selector stage can copy either pipeline
# from a single, predictable path.
RUN cp -a /app/frontend/dist /web-dist

# Stage 2b: Stage the Flutter frontend, built OUTSIDE Docker.
#
# Deliberately does not run the Flutter SDK. Two reasons, both verified:
#
# 1. No usable SDK image exists. The newest ghcr.io/cirruslabs/flutter tag is
#    3.44.0 (Dart 3.12.0), but flutter_app requires Dart ^3.13.2 and freezed 4.x
#    requires >=3.13.0 -- `flutter pub get` inside that image fails outright.
# 2. No native arm64 SDK exists at all. Flutter publishes linux SDKs for x86_64
#    only (the arm64 tarball URL 404s for 3.47.2, 3.44.0, 3.38.0 and 3.27.0).
#    So an in-container build on Apple Silicon means emulating amd64 via QEMU:
#    a ~1.5 GB SDK download plus a slow emulated dart2js, on every cold build.
#
# The trade-off is that the bundle is no longer built by this Dockerfile. It must
# be built on the host first -- see the note in FLUTTER-CONVERT.md task 0.12 and
# `flutter_app/README.md`. `WEB_SOURCE=flutter` will FAIL LOUDLY rather than
# silently ship a stale bundle if the prebuilt output is missing.
#
# The bundle is plain JS/WASM/CSS/PNG, so it is architecture-independent and
# copies into a native image unchanged.
FROM debian:bookworm-slim AS frontend-flutter

# Normalize to the same path the React stage uses.
COPY flutter_app/build/web /web-dist

# Fail loudly on a missing or empty prebuilt bundle. Docker would happily copy a
# nonexistent source directory as an empty dir, producing an image whose backend
# serves a bare directory listing instead of the app -- an easy trap to debug.
RUN set -eux; \
    test -f /web-dist/index.html; \
    test -f /web-dist/main.dart.js; \
    test -f /web-dist/flutter_bootstrap.js

# Stage 2c: select the web bundle to bundle into the backend jar.
#
# Docker skips stages nothing references, so only the selected variant is built:
# the other pipeline's stage is never pulled in.
FROM frontend-${WEB_SOURCE} AS web-assets

# Stage 3: Build the backend and create the final image
FROM cimg/openjdk:19.0-node AS final

WORKDIR /app

# Switch to the 'circleci' user
USER circleci

# Copy the Gradle files from the gradle-setup stage
COPY --chown=circleci:circleci --from=gradle-setup /app/ /app/
COPY --chown=circleci:circleci --from=gradle-setup /home/circleci/.gradle/ /home/circleci/.gradle/

# Create backend directory and copy build.gradle.kts files for caching
RUN mkdir -p backend && find backend -name "build.gradle.kts" -exec cp --parents {} . \;

# Download dependencies for caching
RUN ./gradlew dependencies --no-daemon

# Copy the entire backend source code with correct ownership
COPY --chown=circleci:circleci backend ./backend

# Copy the selected web bundle into the backend's static resources, where Ktor
# serves it from "/" (backend/.../app/Routing.kt, staticResources).
#
# `web-assets` resolves to frontend-react or frontend-flutter per WEB_SOURCE, and
# both normalize their output to /web-dist. Referencing only `web-assets` is
# what keeps the unselected pipeline from being built: a COPY --from on a stage
# nothing references would drag that stage in.
COPY --chown=circleci:circleci --from=web-assets /web-dist /app/backend/app/src/main/resources/static

# Build the application
RUN ./gradlew :backend:app:assemble --no-daemon

# Expose the port the application runs on
EXPOSE 8080

# Run the application
CMD ["java", "-jar", "backend/app/build/libs/app-all.jar"]