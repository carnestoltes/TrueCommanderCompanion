# ---------- STAGE 1: Build Flutter Web ----------
FROM ghcr.io/cirruslabs/flutter:3.24.0 AS web-build
WORKDIR /app

# Copiar pubspecs primero para cachear dependencias
COPY pubspec.yaml .
COPY apps/true_command/pubspec.yaml ./apps/true_command/
COPY packages/shared_logic/pubspec.yaml ./packages/shared_logic/

# Obtener dependencias desde la raíz del workspace
RUN dart pub get

# Copiar el resto del código
COPY apps/true_command/ ./apps/true_command/
COPY packages/shared_logic/ ./packages/shared_logic/

# Construir web
WORKDIR /app/apps/true_command
RUN flutter build web --release

# ---------- STAGE 2: Build Dart Server ----------
FROM dart:stable AS server-build
WORKDIR /app

# IMPORTANTE: Copiar el pubspec.yaml raíz primero
COPY pubspec.yaml .
COPY apps/server/pubspec.yaml ./apps/server/
COPY packages/shared_logic/pubspec.yaml ./packages/shared_logic/

# Obtener dependencias desde el contexto correcto
# Primero en la raíz del workspace para resolver las dependencias locales
WORKDIR /app
RUN dart pub get

# Luego en el servidor específicamente
WORKDIR /app/apps/server
RUN dart pub get

# Copiar el código fuente
COPY apps/server/ ./apps/server/
COPY packages/shared_logic/ ./packages/shared_logic/

# Compilar el servidor - NOTA: estamos en /app/apps/server
RUN dart compile exe bin/server.dart -o /app/server_bin

# ---------- STAGE 3: Final Runtime ----------
FROM debian:stable-slim
WORKDIR /app

# Instalar dependencias necesarias para el ejecutable
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=server-build /app/server_bin ./server
COPY --from=web-build /app/apps/true_command/build/web ./web_bundle

# Verificar que el ejecutable existe y tiene permisos
RUN chmod +x ./server

ENV PORT=8080
EXPOSE 8080

# Ejecutar el servidor
CMD ["./server"]
