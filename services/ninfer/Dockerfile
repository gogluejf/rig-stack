# syntax=docker/dockerfile:1

FROM nvidia/cuda:13.1.2-devel-ubuntu24.04 AS build

ARG DEBIAN_FRONTEND=noninteractive
ARG NINFER_REPOSITORY=https://github.com/Neroued/ninfer.git
ARG NINFER_UPSTREAM_COMMIT=412b11f3e58cda66748b5da4d684ae76f2ccab64

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        cmake \
        g++ \
        git \
        libavcodec-dev \
        libavformat-dev \
        libavutil-dev \
        libcurl4-openssl-dev \
        libswscale-dev \
        ninja-build \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git init \
    && git remote add origin "${NINFER_REPOSITORY}" \
    && git fetch --depth 1 origin "${NINFER_UPSTREAM_COMMIT}" \
    && git checkout --detach FETCH_HEAD \
    && test "$(git rev-parse HEAD)" = "${NINFER_UPSTREAM_COMMIT}" \
    && rm -rf .git

RUN cmake -S . -B /build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DNINFER_BUILD_APPS=ON \
        -DBUILD_TESTING=OFF \
        -DNINFER_BUILD_BENCHMARKS=OFF \
    && cmake --build /build --parallel --target ninfer ninfer-serve

FROM nvidia/cuda:13.1.2-runtime-ubuntu24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG NINFER_UPSTREAM_COMMIT=412b11f3e58cda66748b5da4d684ae76f2ccab64
LABEL org.rig-stack.ninfer.upstream="${NINFER_UPSTREAM_COMMIT}" \
      org.rig-stack.ninfer.cuda="13.1.2"

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        curl \
        libavcodec60 \
        libavformat60 \
        libavutil58 \
        libcurl4t64 \
        libswscale7 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /build/apps/ninfer /usr/local/bin/ninfer
COPY --from=build /build/apps/ninfer-serve /usr/local/bin/ninfer-serve
COPY entrypoint.sh /usr/local/bin/rig-ninfer-entrypoint

RUN chmod 0755 /usr/local/bin/rig-ninfer-entrypoint

WORKDIR /workspace
EXPOSE 8080
STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/local/bin/rig-ninfer-entrypoint"]
