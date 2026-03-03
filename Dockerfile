# ---------- STAGE 1: Build Flutter Web ----------
FROM ghcr.io/cirruslabs/flutter:3.24.0 AS web-build
WORKDIR /app

RUN flutter config --enable-web

COPY apps/true_command/pubspec.yaml ./apps/true_command/
COPY packages/shared_logic/pubspec.yaml ./packages/shared_logic/

WORKDIR /app/apps/true_command
RUN flutter pub get

WORKDIR /app
COPY apps/true_command/ ./apps/true_command/
COPY packages/shared_logic/ ./packages/shared_logic/

WORKDIR /app/apps/true_command
RUN flutter build web --release

# ---------- STAGE 2: Build Dart Server ----------
FROM dart:stable AS server-build
WORKDIR /app

COPY apps/server/pubspec.yaml ./apps/server/
COPY packages/shared_logic/pubspec.yaml ./packages/shared_logic/

WORKDIR /app/apps/server
RUN flutter pub get

WORKDIR /app
COPY apps/server/ ./apps/server/
COPY packages/shared_logic/ ./packages/shared_logic/

WORKDIR /app/apps/server
RUN dart compile exe bin/server.dart -o /app/server_bin

# ---------- STAGE 3: Final Runtime ----------
FROM debian:stable-slim
WORKDIR /app

COPY --from=server-build /app/server_bin ./server
COPY --from=web-build /app/apps/true_command/build/web ./web_bundle

ENV PORT=8080
EXPOSE 8080

CMD ["./server"]