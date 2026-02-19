# ---------- BUILD STAGE ----------
FROM dart:stable AS build

WORKDIR /app

# 1. Copy the Root and all Member Pubspecs first
# This is the "Skeleton" needed for Workspace resolution
COPY pubspec.yaml ./
COPY apps/server/pubspec.yaml ./apps/server/
COPY packages/shared_logic/pubspec.yaml ./packages/shared_logic/

# 2. Resolve dependencies for the WHOLE workspace at once
# This prevents Exit Code 1 by letting Dart see all packages
RUN dart pub get

# 3. Copy the actual source code
COPY apps/server ./apps/server
COPY packages/shared_logic ./packages/shared_logic

# 4. Compile the server
# We run this from the root, pointing to the server entry point
RUN dart compile exe apps/server/bin/server.dart -o /app/server_bin

# ---------- RUNTIME STAGE ----------
FROM debian:stable-slim
WORKDIR /app

# Copy the compiled binary and the runtime from the build stage
COPY --from=build /runtime/ /
COPY --from=build /app/server_bin ./server

# Expose the port Render expects
EXPOSE 8080

# Start the server
CMD ["./server"]