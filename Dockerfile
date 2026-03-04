# ---------- STAGE 1: Build ----------
FROM ghcr.io/cirruslabs/flutter:3.27.0 AS builder
WORKDIR /app

# 1. STOP THE 403 ERROR: Pre-download the web engine
RUN flutter precache --web

# 2. Copy files
COPY . .

# 3. STOP THE TTY ERROR: Run pub get quietly
RUN flutter pub get --no-example

# 4. Build without interactive prompts
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
