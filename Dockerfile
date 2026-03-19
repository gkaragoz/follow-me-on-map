FROM dart:stable

WORKDIR /app

# Copy server source and resolve deps
COPY shared/ shared/
COPY server/ server/
WORKDIR /app/server
RUN dart pub get

# Copy pre-built Flutter web client (built by CI or locally)
COPY build/web/ /app/public/

EXPOSE 8080

CMD ["dart", "run", "bin/server.dart", "--static", "/app/public"]
