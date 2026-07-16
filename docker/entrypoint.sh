#!/usr/bin/env bash
set -Eeuo pipefail

log() {
    printf '[ds4-entrypoint] %s\n' "$*" >&2
}

resolve_model_path() {
    if [[ -n "${MODEL_PATH:-}" ]]; then
        if [[ -f "${MODEL_PATH}" ]]; then
            printf '%s\n' "${MODEL_PATH}"
            return 0
        fi
        log "MODEL_PATH does not exist: ${MODEL_PATH}"
        return 1
    fi

    local org="${MODEL_ID%%/*}"
    local name="${MODEL_ID#*/}"
    local model_root="/runpod-volume/huggingface-cache/hub/models--${org}--${name}"
    local snapshot=""

    if [[ -f "${model_root}/refs/${MODEL_REVISION}" ]]; then
        snapshot="$(<"${model_root}/refs/${MODEL_REVISION}")"
    elif [[ -f "${model_root}/refs/main" ]]; then
        snapshot="$(<"${model_root}/refs/main")"
    elif [[ -d "${model_root}/snapshots/${MODEL_REVISION}" ]]; then
        snapshot="${MODEL_REVISION}"
    fi

    if [[ -n "${snapshot}" && -f "${model_root}/snapshots/${snapshot}/${MODEL_FILE}" ]]; then
        printf '%s\n' "${model_root}/snapshots/${snapshot}/${MODEL_FILE}"
        return 0
    fi

    local search_root
    local candidate
    for search_root in \
        "${model_root}/snapshots" \
        /runpod-volume \
        /models \
        /workspace \
        /root/.cache/huggingface; do
        [[ -d "${search_root}" ]] || continue
        candidate="$(find "${search_root}" -type f -name "${MODEL_FILE}" -print -quit 2>/dev/null || true)"
        if [[ -n "${candidate}" ]]; then
            printf '%s\n' "${candidate}"
            return 0
        fi
    done

    return 1
}

MODEL_PATH="$(resolve_model_path || true)"
if [[ -z "${MODEL_PATH}" ]]; then
    log "Q2 model file was not found."
    log "Expected RunPod cached model: ${MODEL_ID}@${MODEL_REVISION}"
    log "Expected file: ${MODEL_FILE}"
    log "Attach the Hugging Face model cache to this endpoint before starting a worker."
    exit 1
fi

if ! [[ "${PORT}" =~ ^[0-9]+$ && "${DS4_PORT}" =~ ^[0-9]+$ ]]; then
    log "PORT and DS4_PORT must be numeric."
    exit 2
fi

mkdir -p "${KV_DISK_DIR}"
sed \
    -e "s/__PORT__/${PORT}/g" \
    -e "s/__DS4_PORT__/${DS4_PORT}/g" \
    /opt/ds4/nginx.conf.template > /tmp/nginx.conf

args=(
    /opt/ds4/ds4-server
    --cuda
    --model "${MODEL_PATH}"
    --ctx "${CTX_SIZE}"
    --kv-disk-dir "${KV_DISK_DIR}"
    --kv-disk-space-mb "${KV_DISK_SPACE_MB}"
    --power "${POWER_PERCENT}"
    --host 127.0.0.1
    --port "${DS4_PORT}"
)

if [[ "${WARM_WEIGHTS}" == "1" ]]; then
    args+=(--warm-weights)
fi

log "Starting DS4 commit 80ebbc396aee40eedc1d829222f3362d10fa4c6c"
log "Model: ${MODEL_PATH}"
log "Context: ${CTX_SIZE}; public port: ${PORT}; DS4 port: ${DS4_PORT}"

"${args[@]}" &
ds4_pid=$!
nginx -c /tmp/nginx.conf -g 'daemon off;' &
nginx_pid=$!

shutdown() {
    trap - INT TERM
    kill -TERM "${nginx_pid}" "${ds4_pid}" 2>/dev/null || true
    wait "${nginx_pid}" "${ds4_pid}" 2>/dev/null || true
}

trap shutdown INT TERM

set +e
wait -n "${ds4_pid}" "${nginx_pid}"
status=$?
set -e

log "A serving process exited with status ${status}; stopping the worker."
shutdown
exit "${status}"

