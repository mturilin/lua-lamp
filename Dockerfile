# Multi-stage Dockerfile for building and bundling Lua Lamp on Linux
FROM ubuntu:22.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install build prerequisites
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    git \
    meson \
    ninja-build \
    libsdl2-dev \
    libfreetype6-dev \
    libpcre2-dev \
    pkg-config \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth 1 --branch v2.1.8 https://github.com/lite-xl/lite-xl.git lite-xl-src

WORKDIR /src/lite-xl-src
RUN meson setup --buildtype=release build-dir && \
    ninja -C build-dir

# Package stage
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    libsdl2-2.0-0 \
    libfreetype6 \
    libpcre2-8-0 \
    ca-certificates \
    tar \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /src/lite-xl-src/build-dir/src/lite-xl /app/bin/lualamp-linux-x86_64
COPY . /app/

RUN chmod +x /app/bin/lualamp-linux-x86_64 /app/scripts/*.sh && \
    LUALAMP_LINUX_BIN=/app/bin/lualamp-linux-x86_64 /app/scripts/bundle_linux.sh

CMD ["/bin/bash", "-c", "echo 'Lua Lamp Linux build complete. Outputs in /app/dist'"]
