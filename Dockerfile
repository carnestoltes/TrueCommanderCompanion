# ---------- STAGE 1: Build Everything ----------
FROM ghcr.io/cirruslabs/flutter:stable AS builder
WORKDIR /app

# 1. Copy pubspecs to cache dependencies
COPY pubspec.yaml ./
COPY apps/true_command/pubspec.yaml ./apps/true_command/
COPY apps/server/pubspec.yaml ./apps/server/
COPY packages/shared_logic/pubspec.yaml ./packages/shared_logic/

# 2. Get dependencies for all packages
RUN flutter pub get

# 3. Copy source code (Respects .dockerignore)
COPY . .

# 4. Build Flutter Web
RUN cd apps/true_command && \
    flutter clean && \
    flutter build web --release --base-href "/"

# 5. Build Dart Server Binary
RUN cd apps/server && \
    dart compile exe bin/server.dart -o /app/server_bin

# ---------- STAGE 2: Final Runtime ----------
FROM debian:stable-slim
WORKDIR /app

# Install necessary libraries for Dart binary to run
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

# Copy the compiled binary and the web files
COPY --from=builder /app/server_bin ./server
COPY --from=builder /app/apps/true_command/build/web ./web_bundle

# Set runtime environment
ENV PORT=8080
EXPOSE 8080

CMD ["./server"]