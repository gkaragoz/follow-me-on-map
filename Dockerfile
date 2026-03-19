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

# Stage 2: Build and run Dart server
FROM dart:stable AS server-build
RUN apt-get update && apt-get install -y --no-install-recommends \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY shared/ shared/
COPY server/ server/
WORKDIR /app/server
RUN dart pub get
RUN dart compile exe bin/server.dart -o bin/server

# Stage 3: Production image
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy compiled server binary
COPY --from=server-build /app/server/bin/server /app/server

# Copy Flutter web build
COPY --from=flutter-build /app/build/web /app/public

# Create data directory for SQLite
RUN mkdir -p /app/data

# Verify sqlite3 is findable
RUN ldconfig && ldconfig -p | grep sqlite3

EXPOSE 8080

CMD ["/app/server", "--static", "/app/public", "--db", "/app/data/tracking.db"]
