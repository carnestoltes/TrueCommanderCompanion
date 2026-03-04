# ---------- STAGE 1: Build Flutter Web ----------
FROM ghcr.io/cirruslabs/flutter:3.24.0 AS web-build
WORKDIR /app

# Configurar Flutter para web
RUN flutter config --enable-web

# Copiar archivos de dependencias
COPY pubspec.yaml .
COPY apps/true_command/pubspec.yaml ./apps/true_command/
COPY apps/server/pubspec.yaml ./apps/server/
COPY packages/shared_logic/pubspec.yaml ./packages/shared_logic/

# Crear estructura necesaria para el workspace
RUN mkdir -p apps/server/bin

# Obtener dependencias para la app Flutter (usa Flutter SDK)
WORKDIR /app/apps/true_command
RUN flutter pub get

# Copiar el código fuente
WORKDIR /app
COPY apps/true_command/ ./apps/true_command/
COPY packages/shared_logic/ ./packages/shared_logic/

# Construir la web
WORKDIR /app/apps/true_command
RUN flutter build web --release

# ---------- STAGE 2: Build Dart Server ----------
FROM dart:stable AS server-build
WORKDIR /app

# Copiar todos los pubspec.yaml
COPY pubspec.yaml .
COPY apps/true_command/pubspec.yaml ./apps/true_command/
COPY apps/server/pubspec.yaml ./apps/server/
COPY packages/shared_logic/pubspec.yaml ./packages/shared_logic/

# Crear directorio dummy para true_command (para satisfacer el workspace)
RUN mkdir -p apps/true_command && \
    echo "name: true_command_dummy" > apps/true_command/pubspec.yaml && \
    echo "environment:" >> apps/true_command/pubspec.yaml && \
    echo "  sdk: ^3.11.1" >> apps/true_command/pubspec.yaml

# SOLO UNA VEZ: Resolver dependencias desde la raíz del workspace
# Esto resuelve las dependencias de server y shared_logic
WORKDIR /app
RUN dart pub get

# Copiar el código real del servidor y shared_logic
COPY apps/server/ ./apps/server/
COPY packages/shared_logic/ ./packages/shared_logic/

# Compilar el servidor (ahora con todas las dependencias resueltas)
WORKDIR /app/apps/server
RUN ls -la bin/ # Debug: verificar que server.dart existe
RUN dart compile exe bin/server.dart -o /app/server_bin

# ---------- STAGE 3: Final Runtime ----------
FROM debian:stable-slim
WORKDIR /app

# Instalar dependencias necesarias
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copiar los artefactos construidos
COPY --from=server-build /app/server_bin ./server
COPY --from=web-build /app/apps/true_command/build/web ./web_bundle

# Dar permisos de ejecución
RUN chmod +x ./server

# Configurar puerto
ENV PORT=8080
EXPOSE 8080

# Ejecutar el servidor
CMD ["./server"]
