# ---------- BUILD FLUTTER WEB ----------
FROM cirrusci/flutter:stable AS flutter_build

WORKDIR /app

# 1. Copy the WORKSPACE ROOT (Essential!)
COPY pubspec.yaml ./

# 2. Copy the PUBSPECS for the members
COPY apps/true_command/pubspec.* ./apps/true_command/
COPY packages/shared_logic/pubspec.* ./packages/shared_logic/

# 3. Resolve for the whole workspace
RUN flutter pub get

# 4. Copy source and build
COPY apps/true_command ./apps/true_command
COPY packages/shared_logic ./packages/shared_logic
RUN cd apps/true_command && flutter build web

# ---------- BUILD DART SERVER ----------
FROM dart:stable AS server_build

WORKDIR /app

# 1. Copy the WORKSPACE ROOT again for this stage
COPY pubspec.yaml ./

# 2. Copy the PUBSPECS for server and logic
COPY apps/server/pubspec.* ./apps/server/
COPY packages/shared_logic/pubspec.* ./packages/shared_logic/

# 3. Resolve (This will now pass Code 66)
RUN dart pub get

# 4. Copy source and compile
COPY apps/server ./apps/server
COPY packages/shared_logic ./packages/shared_logic
RUN cd apps/server && dart compile exe bin/server.dart -o server

# ---------- FINAL IMAGE ----------
FROM debian:stable-slim
WORKDIR /app
COPY --from=server_build /app/apps/server/server ./server
COPY --from=flutter_build /app/apps/true_command/build/web ./web
EXPOSE 8080
CMD ["./server"]