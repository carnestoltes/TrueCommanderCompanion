# ---------- STAGE 1: Unified Builder ----------
# We use Flutter 3.24+ to ensure Dart 3.5+ workspace support
FROM ghcr.io/cirruslabs/flutter:3.24.0 AS builder
WORKDIR /app

# 1. Copy the entire workspace (Root + apps + packages)
# This is required for 'resolution: workspace' to function 
COPY . .

# 2. Resolve all dependencies at the root
# This maps 'shared_logic' to both 'server' and 'true_command' 
RUN flutter pub get

# 3. Build Flutter Web
# Using the HTML renderer avoids CanvasKit/Skia download issues (403 errors)
RUN cd apps/true_command && \
    flutter build web --release --web-renderer html --no-tree-shake-icons

# 4. Build Dart Server
# We run from the server folder to ensure it finds the local 'bin'
RUN cd apps/server && \
    dart compile exe bin/server.dart -o /app/server_bin

# ---------- STAGE 2: Final Runtime ----------
FROM debian:stable-slim
WORKDIR /app

# Install CA certificates so the server can talk to HTTPS APIs
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

# Copy the server binary and the web bundle from the builder stage
COPY --from=builder /app/server_bin ./server
COPY --from=builder /app/apps/true_command/build/web ./web_bundle

# Render uses port 8080 by default
ENV PORT=8080
EXPOSE 8080

CMD ["./server"]
