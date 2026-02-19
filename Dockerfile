# ---------- BUILD FLUTTER WEB ----------
FROM ghcr.io/cirruslabs/flutter:stable AS flutter_build

WORKDIR /app
COPY apps/true_command/pubspec.* ./apps/true_command/
RUN cd apps/true_command && flutter pub get

COPY apps/true_command ./apps/true_command
RUN cd apps/true_command && flutter build web

# ---------- BUILD DART SERVER ----------
FROM dart:stable AS server_build

WORKDIR /app
COPY apps/server/pubspec.* ./apps/server/
RUN cd apps/server && dart pub get

COPY apps/server ./apps/server
RUN cd apps/server && dart compile exe bin/server.dart -o server

# ---------- FINAL IMAGE ----------
FROM debian:stable-slim

WORKDIR /app

COPY --from=server_build /app/apps/server/server ./server
COPY --from=flutter_build /app/apps/true_command/build/web ./web

EXPOSE 8080

CMD ["./server"]
