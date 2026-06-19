FROM dart:latest as builder

# Sets the working directory to /app
WORKDIR /app

# Copies the current directory contents into the container at /app
COPY . .

RUN dart pub get

# Generate a production build.
RUN dart pub global activate dart_frog_cli
RUN dart pub global run dart_frog_cli:dart_frog build

RUN dart compile exe build/bin/server.dart -o build/bin/server

# Build minimal serving image from AOT-compiled `/server` and required system
# libraries and configuration files stored in `/runtime/` from the build stage.
FROM scratch

# Copy runtime dependencies
COPY --from=builder /runtime /

# Copy executable
COPY --from=builder /app/build/bin/server /app/bin/

# Start the server.
CMD ["/app/bin/server"]
