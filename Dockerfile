ARG CUDA_VERSION=13.0.1

FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu24.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG DS4_COMMIT=80ebbc396aee40eedc1d829222f3362d10fa4c6c

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN git clone https://github.com/antirez/ds4.git \
    && cd ds4 \
    && git checkout "${DS4_COMMIT}" \
    && make -B ds4-server CUDA_ARCH=sm_120 NATIVE_CPU_FLAG=-march=x86-64-v3 \
    && strip ds4-server

FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu24.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        findutils \
        nginx \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /etc/nginx/sites-enabled/default

WORKDIR /opt/ds4
COPY --from=builder /build/ds4/ds4-server /opt/ds4/ds4-server
COPY --from=builder /build/ds4/LICENSE /opt/ds4/LICENSE
COPY docker/entrypoint.sh /opt/ds4/entrypoint.sh
COPY docker/nginx.conf.template /opt/ds4/nginx.conf.template

RUN chmod 0755 /opt/ds4/ds4-server /opt/ds4/entrypoint.sh \
    && mkdir -p /var/cache/nginx /var/log/nginx /tmp/ds4-kv

ENV MODEL_ID=huihui-ai/Huihui-DeepSeek-V4-Flash-abliterated-ds4-GGUF \
    MODEL_REVISION=f06f59bce3c36b3282b75c9fe2621c83c9399d10 \
    MODEL_FILE=Huihui-DeepSeek-V4-Flash-BF16-abliterated-ds4-Q2.gguf \
    CTX_SIZE=131072 \
    KV_DISK_DIR=/tmp/ds4-kv \
    KV_DISK_SPACE_MB=8192 \
    POWER_PERCENT=100 \
    WARM_WEIGHTS=1 \
    PORT=8000 \
    DS4_PORT=8001 \
    RUNPOD_INIT_TIMEOUT=1800

EXPOSE 8000

HEALTHCHECK --interval=10s --timeout=5s --start-period=30m --retries=3 \
    CMD curl --fail --silent --show-error http://127.0.0.1:${PORT}/ping >/dev/null || exit 1

ENTRYPOINT ["/opt/ds4/entrypoint.sh"]

