# Build Stage
FROM rust:1.83-slim-bookworm AS builder

WORKDIR /usr/src/app
COPY . .

# Build for release
RUN cargo build --release

# Run Stage
FROM debian:bookworm-slim

# Install OpenSSL/Ca-certificates if needed (good practice for web servers)
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /usr/src/app/target/release/image_optimizer .

# Cloud Run uses port 8080 by default
ENV PORT 8080
EXPOSE 8080

CMD ["./image_optimizer"]
