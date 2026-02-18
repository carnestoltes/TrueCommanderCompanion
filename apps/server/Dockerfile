# STAGE 1: Build
FROM dart:stable AS build

# We use /app as the working directory inside the container
WORKDIR /app

# 1. Copy only the pubspec to install dependencies first (Cache-friendly)
COPY pubspec.yaml ./
RUN dart pub get

# 2. Copy the rest of the server folder (bin, test, etc.)
COPY . .

# 3. Compile the production binary
# This looks for apps/server/bin/server.dart because of the Root Directory setting
RUN dart compile exe bin/server.dart -o bin/server

# STAGE 2: Runtime (Minimalist image)
FROM debian:bookworm-slim

# Copy runtime dependencies from Google's Dart image
COPY --from=build /runtime/ /
# Copy only the compiled server binary
COPY --from=build /app/bin/server /app/bin/server

# Standard port for Render
EXPOSE 8080

# Start the server
CMD ["/app/bin/server"]