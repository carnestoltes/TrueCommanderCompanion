# ---------- STAGE 1: Build Flutter Web ----------
FROM ghcr.io/cirruslabs/flutter:stable AS web-build
WORKDIR /app

# Copy the "Skeleton"
COPY pubspec.yaml ./
COPY apps/true_command/pubspec.yaml ./apps/true_command/
COPY apps/server/pubspec.yaml ./apps/server/
COPY packages/shared_logic/pubspec.yaml ./packages/shared_logic/

# Resolve dependencies for the WHOLE workspace (using flutter pub)
RUN flutter pub get

# Copy source code and build the web app
COPY apps/true_command/ ./apps/true_command/
COPY packages/shared_logic/ ./packages/shared_logic/
RUN cd apps/true_command && flutter build web --release

# ---------- STAGE 2: Build Dart Server ----------
# WE USE FLUTTER HERE TOO so the solver can find the Flutter SDK
FROM ghcr.io/cirruslabs/flutter:stable AS server-build
WORKDIR /app

# Copy the "Skeleton" again
COPY pubspec.yaml ./
COPY apps/true_command/pubspec.yaml ./apps/true_command/
COPY apps/server/pubspec.yaml ./apps/server/
COPY packages/shared_logic/pubspec.yaml ./packages/shared_logic/

# Now this will pass because it can see the Flutter SDK for true_command
RUN flutter pub get

# Copy server source and shared logic
COPY apps/server/ ./apps/server/
COPY packages/shared_logic/ ./packages/shared_logic/

# We still compile using 'dart' because it's a backend app
RUN cd apps/server && dart compile exe bin/server.dart -o /app/server_bin

# ---------- STAGE 3: Final Runtime ----------
# This stays the same (small and clean)
FROM debian:stable-slim
WORKDIR /app

# Copy the compiled binary and the web files
COPY --from=server-build /app/server_bin ./server
COPY --from=web-build /app/apps/true_command/build/web ./web_bundle

ENV PORT=8080
EXPOSE 8080

CMD ["./server"]