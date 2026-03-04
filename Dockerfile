# ---------- STAGE 1: Unified Builder ----------
FROM ghcr.io/cirruslabs/flutter:3.24.0 AS builder
WORKDIR /app

# 1. Copy the ENTIRE workspace (Root + all apps + all packages)
# This ensures the 'workspace' resolution can see the root pubspec.yaml
COPY . .

# 2. Get dependencies for the whole workspace at once
RUN flutter pub get

# 3. Build Flutter Web
# Using --web-renderer html to avoid the TTY/CanvasKit 403 errors
RUN cd apps/true_command && \
    flutter build web --release --web-renderer html --no-tree-shake-icons

# 4. Build Dart Server
# We run from the server folder so it finds the local pubspec.yaml
RUN cd apps/server && \
    dart compile exe bin/server.dart -o /app/server_bin

# ---------- STAGE 2: Lightweight Runtime ----------
FROM debian:stable-slim
WORKDIR /app

# Required for the server to communicate with external APIs (like Scryfall)
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

# Copy the compiled binary and the web bundle from the builder stage
COPY --from=builder /app/server_bin ./server
COPY --from=builder /app/apps/true_command/build/web ./web_bundle

ENV PORT=8080
EXPOSE 8080

# Run the server
CMD ["./server"]
