# ---------- STAGE 1: Build Flutter Web (Frontend) ----------
FROM ghcr.io/cirruslabs/flutter:3.24.0 AS frontend-builder
WORKDIR /app

# Configurar Flutter
RUN flutter config --enable-web

# Copiar archivos de dependencias
COPY pubspec.yaml .
COPY apps/true_command/pubspec.yaml ./apps/true_command/
COPY apps/server/pubspec.yaml ./apps/server/
COPY packages/shared_logic/pubspec.yaml ./packages/shared_logic/

# Crear estructura completa del workspace
RUN mkdir -p apps/server/bin && \
    mkdir -p packages/shared_logic/lib

# Obtener dependencias para la app Flutter
WORKDIR /app/apps/true_command
RUN flutter pub get

# Copiar código fuente completo
WORKDIR /app
COPY apps/true_command/ ./apps/true_command/
COPY packages/shared_logic/ ./packages/shared_logic/

# Construir frontend
WORKDIR /app/apps/true_command
RUN flutter build web --release

# ---------- STAGE 2: Build Dart Server (Backend) ----------
FROM dart:stable AS backend-builder
WORKDIR /app

# Copiar archivos de dependencias
COPY pubspec.yaml .
COPY apps/server/pubspec.yaml ./apps/server/
COPY packages/shared_logic/pubspec.yaml ./packages/shared_logic/

# Crear directorio dummy para true_command (solo para satisfacer workspace)
RUN mkdir -p apps/true_command && \
    echo "name: true_command_dummy" > apps/true_command/pubspec.yaml && \
    echo "environment:" >> apps/true_command/pubspec.yaml && \
    echo "  sdk: ^3.11.1" >> apps/true_command/pubspec.yaml && \
    mkdir -p apps/true_command/lib

# Resolver dependencias desde la raíz
WORKDIR /app
RUN dart pub get

# Copiar código fuente
COPY apps/server/ ./apps/server/
COPY packages/shared_logic/ ./packages/shared_logic/

# Compilar servidor
WORKDIR /app/apps/server
RUN dart compile exe bin/server.dart -o /app/server_bin

# ---------- STAGE 3: Frontend Runtime (Static Site) ----------
FROM nginx:alpine AS frontend
COPY --from=frontend-builder /app/apps/true_command/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

# ---------- STAGE 4: Backend Runtime ----------
FROM debian:stable-slim AS backend
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=backend-builder /app/server_bin ./server
COPY --from=frontend-builder /app/apps/true_command/build/web ./web_bundle

RUN chmod +x ./server

ENV PORT=8080
EXPOSE 8080

CMD ["./server"]
