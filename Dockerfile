# ---------- STAGE 1: Build Flutter Web ----------
FROM cirrusci/flutter:stable AS web-build
WORKDIR /app

RUN flutter config --enable-web

# Copy workspace skeleton
COPY pubspec.yaml ./
COPY apps/true_command/pubspec.yaml ./apps/true_command/
COPY apps/server/pubspec.yaml ./apps/server/
COPY packages/shared_logic/pubspec.yaml ./packages/shared_logic/

RUN flutter pub get

# Copy full source
COPY apps/true_command/ ./apps/true_command/
COPY packages/shared_logic/ ./packages/shared_logic/

RUN cd apps/true_command && flutter build web --release

# ---------- STAGE 2: Build Dart Server ----------
FROM cirrusci/flutter:stable AS server-build
WORKDIR /app

COPY pubspec.yaml ./
COPY apps/true_command/pubspec.yaml ./apps/true_command/
COPY apps/server/pubspec.yaml ./apps/server/
COPY packages/shared_logic/pubspec.yaml ./packages/shared_logic/

RUN flutter pub get

COPY apps/server/ ./apps/server/
COPY packages/shared_logic/ ./packages/shared_logic/

RUN cd apps/server && dart compile exe bin/server.dart -o /app/server_bin

# ---------- STAGE 3: Final Runtime ----------
FROM debian:stable-slim
WORKDIR /app

COPY --from=server-build /app/server_bin ./server
COPY --from=web-build /app/apps/true_command/build/web ./web_bundle

ENV PORT=8080
EXPOSE 8080

CMD ["./server"]