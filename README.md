# Huihui DeepSeek V4 Flash Q2 on RunPod Serverless

This repository builds a RunPod Load Balancer Serverless worker for:

- Model: `huihui-ai/Huihui-DeepSeek-V4-Flash-abliterated-ds4-GGUF`
- File: `Huihui-DeepSeek-V4-Flash-BF16-abliterated-ds4-Q2.gguf`
- Runtime: `antirez/ds4` at commit
  `80ebbc396aee40eedc1d829222f3362d10fa4c6c`
- GPU: one NVIDIA RTX PRO 6000 Blackwell Server Edition, 96GB
- CUDA: 13.0.1, compiled for `sm_120`
- Context: 131,072 tokens

The published worker image is:

```text
ghcr.io/nordinian/runpod-huihui-ds4-serverless:latest
```

The worker exposes:

- `GET /v1/models`
- `POST /v1/chat/completions`
- `POST /v1/responses`
- `POST /v1/completions`
- `POST /v1/messages`

`/v1/responses` is intended for Codex-compatible clients. `/v1/messages` is
intended for Claude Code-compatible clients.

## RunPod configuration

Use a Load Balancer endpoint with these settings:

| Setting | Value |
| --- | --- |
| GPU | NVIDIA RTX PRO 6000 Blackwell Server Edition |
| GPU count | 1 |
| Active workers | 0 |
| Max workers | 1 |
| Idle timeout | 1800 seconds |
| Container disk | 32GB or more |
| Container port | 8000 |
| Health path | `/ping` |
| Model cache | `huihui-ai/Huihui-DeepSeek-V4-Flash-abliterated-ds4-GGUF` |
| CUDA minimum | 13.0 |
| Max concurrency | 1 |

RunPod currently caches every file in a Hugging Face repository, so this model
cache is larger than the selected Q2 file. The cache download is performed
before worker billing begins. The worker only opens the exact Q2 file.

Recommended environment variables:

```text
RUNPOD_INIT_TIMEOUT=1800
CTX_SIZE=131072
KV_DISK_SPACE_MB=8192
WARM_WEIGHTS=1
POWER_PERCENT=100
```

## Verify

The Load Balancer base URL has this form:

```text
https://ENDPOINT_ID.api.runpod.ai
```

Run all compatibility checks:

```bash
RUNPOD_API_KEY=... python3 scripts/verify.py \
  --base-url https://ENDPOINT_ID.api.runpod.ai
```

RunPod authenticates requests at the Load Balancer with:

```text
Authorization: Bearer RUNPOD_API_KEY
```
