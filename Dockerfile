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

# Stage 2: Server with bundled sqlite3 (no system lib needed)
FROM dart:stable

WORKDIR /app

# Copy server source and resolve deps (sqlite3 v3 bundles its own native lib)
COPY shared/ shared/
COPY server/ server/
WORKDIR /app/server
RUN dart pub get

# Pre-run build hooks so they don't run on first startup
RUN dart run --no-serve-devtools bin/server.dart --help 2>/dev/null; exit 0

# Copy Flutter web build
COPY --from=flutter-build /app/build/web /app/public

RUN mkdir -p /app/data

WORKDIR /app/server

EXPOSE 8080

CMD ["dart", "run", "bin/server.dart", "--static", "/app/public", "--db", "/app/data/tracking.db"]
