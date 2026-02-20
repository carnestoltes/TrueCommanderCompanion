# Stage 1: Build Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS web-build
WORKDIR /app

# Copy the "Skeleton" (All pubspecs)
COPY pubspec.yaml ./
COPY apps/true_command/pubspec.yaml ./apps/true_command/
COPY apps/server/pubspec.yaml ./apps/server/
COPY packages/shared_logic/pubspec.yaml ./packages/shared_logic/

# Resolve dependencies for the whole workspace
RUN flutter pub get

# Copy source code and build the web app
COPY apps/true_command/ ./apps/true_command/
COPY packages/shared_logic/ ./packages/shared_logic/
RUN cd apps/true_command && flutter build web --release

# Stage 2: Build Dart Server
FROM dart:stable AS server-build
WORKDIR /app

# Copy the "Skeleton" again (or reuse from previous stage if using same base)
COPY pubspec.yaml ./
COPY apps/server/pubspec.yaml ./apps/server/
COPY packages/shared_logic/pubspec.yaml ./packages/shared_logic/

RUN dart pub get

# Copy server source and compile
COPY apps/server/ ./apps/server/
COPY packages/shared_logic/ ./packages/shared_logic/
RUN dart compile exe apps/server/bin/server.dart -o /app/server_bin

# Stage 3: Final Runtime
FROM debian:stable-slim
WORKDIR /app

# Copy the compiled server and the web files
COPY --from=server-build /runtime/ /
COPY --from=server-build /app/server_bin ./server
COPY --from=web-build /app/apps/true_command/build/web ./web_bundle

# Set the environment variable for Render's port
ENV PORT=8080
EXPOSE 8080

CMD ["./server"]