# STAGE 1: Build
FROM dart:stable AS build

WORKDIR /app

# 1. Copy the WHOLE workspace structure so 'resolution: workspace' works
COPY pubspec.yaml ./ 
COPY apps/server/pubspec.yaml ./apps/server/
COPY packages/shared_logic/ ./packages/shared_logic/

# 2. Get dependencies for the whole workspace
RUN dart pub get

# 3. Copy the rest of the server source
COPY apps/server/ ./apps/server/

# 4. Compile (Notice we point to the specific subfolder)
RUN dart compile exe apps/server/bin/server.dart -o bin/server

# STAGE 2: Runtime
FROM debian:bookworm-slim
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server

EXPOSE 8080
CMD ["/app/bin/server"]