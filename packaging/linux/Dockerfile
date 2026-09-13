FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PATH="/opt/flutter/bin:/usr/local/bin:/root/.local/bin:${PATH}" \
    PUB_CACHE=/root/.pub-cache \
    UV_PYTHON_INSTALL_DIR=/root/.local/share/uv/python

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        clang \
        cmake \
        git \
        libgtk-3-dev \
        liblzma-dev \
        ninja-build \
        pkg-config \
        python3 \
        rsync \
        unzip \
        xz-utils \
        zip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
ENTRYPOINT ["bash", "/src/packaging/linux/build_inside_docker.sh"]
