ARG CUDA_VERSION=12.8.1

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
COPY patches/ds4-responses-early-created.patch /tmp/ds4-responses-early-created.patch
RUN git clone https://github.com/antirez/ds4.git \
    && cd ds4 \
    && git checkout "${DS4_COMMIT}" \
    && git apply /tmp/ds4-responses-early-created.patch \
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

ENV MODEL_ID=kinson888/Huihui-DeepSeek-V4-Flash-Q2-ds4-GGUF \
    MODEL_REVISION=e97533b21a4e168c415c658c25b63a89d859e593 \
    MODEL_FILE=Huihui-DeepSeek-V4-Flash-BF16-abliterated-ds4-Q2.gguf \
    CTX_SIZE=131072 \
    KV_DISK_DIR=/tmp/ds4-kv \
    KV_DISK_SPACE_MB=8192 \
    POWER_PERCENT=100 \
    WARM_WEIGHTS=0 \
    PORT=80 \
    DS4_PORT=8001 \
    RUNPOD_INIT_TIMEOUT=1800

EXPOSE 80

HEALTHCHECK --interval=10s --timeout=5s --start-period=30m --retries=3 \
    CMD curl --fail --silent --show-error http://127.0.0.1:${PORT}/ping >/dev/null || exit 1

ENTRYPOINT ["/opt/ds4/entrypoint.sh"]
