# Stage 1: Build Flutter web client
FROM ghcr.io/cirruslabs/flutter:stable AS flutter-build
WORKDIR /app
COPY pubspec.yaml pubspec.lock* ./
COPY shared/ shared/
RUN flutter pub get
COPY lib/ lib/
COPY web/ web/
COPY analysis_options.yaml ./
RUN flutter build web --release

# Stage 2: Production — Dart runtime with sqlite3
FROM dart:stable
RUN apt-get update && apt-get install -y --no-install-recommends \
    libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy server source and resolve deps
COPY shared/ shared/
COPY server/ server/
WORKDIR /app/server
RUN dart pub get

# Copy Flutter web build
COPY --from=flutter-build /app/build/web /app/public

# Create data directory for SQLite
RUN mkdir -p /app/data

WORKDIR /app/server

EXPOSE 8080

CMD ["dart", "run", "bin/server.dart", "--static", "/app/public", "--db", "/app/data/tracking.db"]
