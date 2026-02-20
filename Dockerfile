# ---------- STAGE 1: Build Flutter Web ----------
FROM ghcr.io/cirruslabs/flutter:stable AS web-build
WORKDIR /app

# Copy the "Skeleton" (All pubspecs) to resolve workspace
COPY pubspec.yaml ./
COPY apps/true_command/pubspec.yaml ./apps/true_command/
COPY apps/server/pubspec.yaml ./apps/server/
COPY packages/shared_logic/pubspec.yaml ./packages/shared_logic/

# Resolve dependencies for the WHOLE workspace
RUN flutter pub get

# Copy source code and build the web app
COPY apps/true_command/ ./apps/true_command/
COPY packages/shared_logic/ ./packages/shared_logic/
RUN cd apps/true_command && flutter build web --release

# ---------- STAGE 2: Build Dart Server ----------
FROM dart:stable AS server-build
WORKDIR /app

# IMPORTANT: You must copy the workspace skeleton here too!
COPY pubspec.yaml ./
COPY apps/true_command/pubspec.yaml ./apps/true_command/
COPY apps/server/pubspec.yaml ./apps/server/
COPY packages/shared_logic/pubspec.yaml ./packages/shared_logic/

# Resolve dependencies (This will now pass because true_command exists)
RUN dart pub get

# Copy server source and shared logic
COPY apps/server/ ./apps/server/
COPY packages/shared_logic/ ./packages/shared_logic/

# Compile the server from the root context
RUN dart compile exe apps/server/bin/server.dart -o /app/server_bin

# ---------- STAGE 3: Final Runtime ----------
FROM debian:stable-slim
WORKDIR /app

# Copy the compiled server and the web files
COPY --from=server-build /runtime/ /
COPY --from=server-build /app/server_bin ./server
COPY --from=web-build /app/apps/true_command/build/web ./web_bundle

ENV PORT=8080
EXPOSE 8080

CMD ["./server"]