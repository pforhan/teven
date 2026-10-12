# Which web bundle to compile into the backend jar: `react` (the live app until
# Phase 10) or `flutter`. Both pipelines stay buildable during the migration.
#
# Must be declared before the first FROM: Docker only substitutes build args into
# FROM instructions when they are in the global scope, and the stage selector
# below relies on that.
ARG WEB_SOURCE=react

# Stage 1: Gradle setup
#
# JDK 21 (LTS), on Eclipse Temurin rather than cimg/openjdk for two reasons:
#
# 1. ARCHITECTURE. cimg/openjdk is published amd64-only, so on Apple Silicon
#    every Gradle invocation ran under QEMU emulation. Measured on this repo,
#    the emulated `:backend:app:assemble` took 384.9s where the identical
#    assembly against the same dependency cache took 20s natively -- roughly
#    19x, far more than a CPU microbenchmark suggests, because kotlinc is a
#    JIT-compiling workload and emulation compounds it. Temurin publishes a
#    real arm64 variant, so Docker selects it with no arch pin needed.
# 2. The `final` stage only runs the jar. Node was never needed outside the
#    separate `frontend-react` stage; dropping it shrinks the runtime image.
#
# Changing the base image invalidates every cached layer below, so the first
# build re-downloads Gradle and all dependencies. Subsequent builds are cached.
FROM eclipse-temurin:21-jdk-jammy AS gradle-setup

# Temurin ships no `circleci` user -- cimg/openjdk did. Recreate it with the
# same uid and gid so the existing `--chown=circleci:circleci` COPY flags and
# the `/home/circleci/.gradle` cache path below keep working unchanged.
RUN groupadd --gid 1000 circleci \
  && useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash circleci

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

# Stage 3: Compile the backend.
#
# Split out from `final` so the expensive Kotlin compile (measured at ~265s
# cold on a native arm64 JDK) is cached independently of the web bundle. It
# depends only on backend sources, so a Flutter-only change -- the common case
# for the rest of this port -- reuses this layer untouched and skips the
# compile entirely. Previously the web bundle was copied *before* the assemble,
# so every frontend edit invalidated and repeated the whole Kotlin build.
#
# Only `classes` is compiled here. Packaging into the fat jar happens in
# `final`, after the web bundle lands in the jar's static resources.
FROM eclipse-temurin:21-jdk-jammy AS backend-compile

RUN groupadd --gid 1000 circleci \
  && useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash circleci

WORKDIR /app

# See the note in the `final` stage on why this is explicit rather than
# inherited from the base image.
RUN chown circleci:circleci /app

USER circleci

COPY --chown=circleci:circleci --from=gradle-setup /app/ /app/
COPY --chown=circleci:circleci --from=gradle-setup /home/circleci/.gradle/ /home/circleci/.gradle/

COPY --chown=circleci:circleci backend ./backend

# Compile only -- do not assemble. Produces the class files and, importantly,
# the Gradle task history under /app/.gradle that lets the `final` stage see
# these tasks as UP-TO-DATE and skip straight to packaging.
#
# The Gradle user home is mounted from a BuildKit cache rather than baked into
# a layer, because it has to survive a layer it cannot be allowed to invalidate.
# The distribution and the resolved dependencies cost minutes to fetch and
# depend on nothing but the build scripts, but as a layer that cache would sit
# behind the COPY above, whose cache key spans all backend source -- so any .kt
# edit would re-download everything. Working round that meant copying only the
# build scripts, which Docker cannot do: a recursive copy does not preserve
# directory structure (`COPY backend/*/build.gradle.kts backend/` flattens every
# module's script into one path, where they collide), so each module had to be
# named individually. Copy-then-delete fails the same way by a different route,
# since its COPY still covers all the source.
#
# A cache mount persists across builds independently of any layer, so no source
# has to be held out of the tree to protect it and the module list disappears.
# `id=teven-gradle` is what makes it shared: `final` mounts the same one and
# reuses the distribution and the dependencies resolved here.
#
# This replaces a "copy the build scripts, then resolve dependencies" step that
# never worked. It ran `mkdir -p backend && find backend -name
# "build.gradle.kts" ...`, but `backend/` did not exist yet at that point in the
# stage, so find matched nothing, `dependencies` resolved nothing, and every
# build re-downloaded. Gradle 8 tolerated the project directories that were then
# missing; Gradle 9 rejects them, which is how it surfaced.
RUN --mount=type=cache,id=teven-gradle,target=/home/circleci/.gradle,uid=1000,gid=1000 \
    ./gradlew :backend:app:classes --no-daemon

# Stage 4: Build the backend and create the final image
#
# JDK 21 to match the build stages. This is also the image's *runtime* JDK, so
# it is not only a build-tool choice -- 21 is an LTS release, which is why it
# was preferred over the 25/26 that Gradle would also accept.
FROM eclipse-temurin:21-jdk-jammy AS final

RUN groupadd --gid 1000 circleci \
  && useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash circleci

WORKDIR /app

# Give the build user ownership of its own working directory.
#
# This was previously true by accident, and swapping the base image broke it:
# cimg/openjdk defaults to `USER circleci`, so `WORKDIR /app` created the
# directory circleci-owned. Temurin defaults to root, so it created it
# root-owned, and the dependency-caching step failed with
# "mkdir: cannot create directory 'backend': Permission denied".
#
# Set explicitly rather than inherited, so the next base-image swap does not
# silently take this with it.
RUN chown circleci:circleci /app

USER circleci

# Take the whole compiled tree, including /app/.gradle. The task history is
# what makes the compile below a no-op: without it Gradle has no record that
# compileKotlin already ran and would redo the full build.
COPY --chown=circleci:circleci --from=backend-compile /app /app

# Copy the selected web bundle into the backend's static resources, where Ktor
# serves it from "/" (backend/.../app/Routing.kt, staticResources).
#
# This is the only input that changes on a frontend-only edit, so it is placed
# after the compile deliberately.
#
# `web-assets` resolves to frontend-react or frontend-flutter per WEB_SOURCE, and
# both normalize their output to /web-dist. Referencing only `web-assets` is
# what keeps the unselected pipeline from being built: a COPY --from on a stage
# nothing references would drag that stage in.
COPY --chown=circleci:circleci --from=web-assets /web-dist /app/backend/app/src/main/resources/static

# Package. compileKotlin and friends are UP-TO-DATE here, so this re-runs only
# resource processing and jar assembly -- seconds, not minutes.
#
# Mounts the same cache as the compile stage; see the note there.
RUN --mount=type=cache,id=teven-gradle,target=/home/circleci/.gradle,uid=1000,gid=1000 \
    ./gradlew :backend:app:assemble --no-daemon

# Expose the port the application runs on
EXPOSE 8080

# Run the application
CMD ["java", "-jar", "backend/app/build/libs/app-all.jar"]