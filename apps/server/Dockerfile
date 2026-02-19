# ---------- BUILD FLUTTER WEB ----------
FROM ghcr.io/cirruslabs/flutter:stable AS flutter_build

WORKDIR /app
COPY ../../ ./
WORKDIR /app/apps/true_command

RUN flutter pub get
RUN flutter build web

# ---------- BUILD DART SERVER ----------
FROM dart:stable AS server_build

WORKDIR /app
COPY ../../ ./
WORKDIR /app/apps/server

RUN dart pub get
RUN dart compile exe bin/server.dart -o server

# ---------- FINAL IMAGE ----------
FROM debian:stable-slim

WORKDIR /app

COPY --from=server_build /app/apps/server/server .
COPY --from=flutter_build /app/apps/true_command/build/web ./web

EXPOSE 8080

CMD ["./server"]
