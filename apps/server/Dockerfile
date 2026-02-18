# STAGE 1: Build
FROM dart:stable AS build

# This should be the folder where pubspec.yaml lives
WORKDIR /apps/server

# Copy ONLY the dependency files first
COPY pubspec.yaml ./
# If you have a pubspec.lock, uncomment the next line
#COPY pubspec.lock ./

# Try to get packages
RUN dart pub get

# Copy the rest of the source code
COPY . .

# Ensure the path to your server.dart is correct relative to pubspec.yaml
RUN dart compile exe bin/server.dart -o bin/server

# STAGE 2: Runtime
FROM debian:bookworm-slim
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server

EXPOSE 8080
CMD ["/app/bin/server"]
