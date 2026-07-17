# Huihui DeepSeek V4 Flash Q2 on RunPod Serverless

This repository builds a RunPod Load Balancer Serverless worker for:

- Model cache: `kinson888/Huihui-DeepSeek-V4-Flash-Q2-ds4-GGUF`
- Source model: `huihui-ai/Huihui-DeepSeek-V4-Flash-abliterated-ds4-GGUF`
- File: `Huihui-DeepSeek-V4-Flash-BF16-abliterated-ds4-Q2.gguf`
- Runtime: `antirez/ds4` at commit
  `80ebbc396aee40eedc1d829222f3362d10fa4c6c`
- GPU: one NVIDIA RTX PRO 6000 Blackwell, 96GB
- CUDA: 12.8.1, compiled for `sm_120`
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

The pinned DS4 source is patched to emit `response.created` before a long
Responses prefill. Codex otherwise times out while a full agent prompt is being
loaded on a single GPU, even though SSE comment keepalives are still arriving.

## RunPod configuration

Use a Load Balancer endpoint with these settings:

| Setting | Value |
| --- | --- |
| GPU priority | Server Edition, Workstation Edition, Max-Q Workstation Edition |
| GPU count | 1 |
| Active workers | 0 |
| Max workers | 1 |
| Idle timeout | 1800 seconds |
| Container disk | 32GB or more |
| Container port | 80 |
| Health path | `/ping` |
| Model cache | `kinson888/Huihui-DeepSeek-V4-Flash-Q2-ds4-GGUF` |
| CUDA minimum | 12.8 |
| Max concurrency | 1 |

The model cache repository contains only the selected Q2 file. This avoids
pre-caching the source repository's unrelated Q2_K, Q4_K, and MTP files.

Recommended environment variables:

```text
RUNPOD_INIT_TIMEOUT=1800
CTX_SIZE=131072
KV_DISK_SPACE_MB=8192
WARM_WEIGHTS=0
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

RunPod's Load Balancer does not accept `x-api-key`. Claude Code must therefore
use `ANTHROPIC_AUTH_TOKEN`, not `ANTHROPIC_API_KEY`.

## Codex and Claude Code

Install the isolated launchers:

```bash
./clients/install.sh
```

Then start either client without loading the much larger global plugin and MCP
configuration:

```bash
codex-huihui
claude-huihui
```

Both launchers read the RunPod token from the macOS Keychain service
`runpod-api-key`; the secret is not stored in these files. The Codex catalog
uses a 131,072-token context limit, compacts at 110,000 tokens, disables hidden
reasoning by default, and keeps only the built-in coding tools.
