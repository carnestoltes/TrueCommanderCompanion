# STAGE 1: Build
FROM dart:stable AS build

WORKDIR /app

# 1. Copy the WORKSPACE ROOT files (Essential for resolution: workspace)
COPY pubspec.yaml ./

# 2. Copy all workspace members' pubspecs first to resolve dependencies
# This allows 'dart pub get' to see the shared_logic link
COPY apps/server/pubspec.yaml ./apps/server/
COPY packages/shared_logic/pubspec.yaml ./packages/shared_logic/

# 3. Resolve dependencies for the entire workspace
RUN dart pub get

# 4. Copy the actual source code
COPY apps/server/ ./apps/server/
COPY packages/shared_logic/ ./packages/shared_logic/

# 5. Compile the server (Path is relative to the root /app)
RUN dart compile exe apps/server/bin/server.dart -o bin/server

# STAGE 2: Runtime
FROM debian:bookworm-slim
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server

# Render uses $PORT, but we'll expose the standard 8080 for internal Docker routing
EXPOSE 8080

CMD ["/app/bin/server"]