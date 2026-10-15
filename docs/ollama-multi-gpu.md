# Ollama on Multi-GPU Hosts

By default the stack runs a single Ollama container. On a machine with several GPUs you can run more, so a large model can stay resident on its own GPU instead of being swapped out whenever another model is used.

Set `OLLAMA_INSTANCE_COUNT` in `.env` (1-8) and run `make update` (or `bash scripts/generate_ollama_instances.sh` followed by `make restart`). Instance 1 stays the familiar `ollama` container; extras are `ollama2`, `ollama3`, and so on.

```env
OLLAMA_INSTANCE_COUNT=3
OLLAMA_GPU_DEVICES=0,1     # instance 1 -> GPUs 0 and 1
OLLAMA2_GPU_DEVICES=2      # instance 2 -> GPU 2
OLLAMA3_GPU_DEVICES=3      # instance 3 -> GPU 3

OLLAMA2_KEEP_ALIVE=-1      # keep this instance's model resident forever
OLLAMA3_MAX_LOADED_MODELS=1
```

The runtime tuning variables — `KEEP_ALIVE`, `NUM_PARALLEL`, `MAX_LOADED_MODELS`, `CONTEXT_LENGTH`, `KV_CACHE_TYPE`, `GPU_OVERHEAD`, `SCHED_SPREAD` — can be set per instance with an `OLLAMA<N>_` prefix, and an unset one falls back to the global value. These take effect on the next `make restart`, with no regeneration needed. (`OLLAMA_GPU_COUNT` has no per-instance form, and `OLLAMA<N>_GPU_DEVICES` does not fall back to the global `OLLAMA_GPU_DEVICES` — it defaults to GPU N-1.)

Anything beyond those knobs — llama.cpp `LLAMA_ARG_*` variables, ROCm `HSA_OVERRIDE_GFX_VERSION`, and so on — goes into optional env files next to `.env`: `ollama.env` applies to every instance, `ollama<N>.env` to one instance and overrides `ollama.env`. A typical use is a smaller free-VRAM margin on a GPU that serves nothing but one Ollama instance:

```env
# ollama2.env - this GPU serves only ollama2, so leave less VRAM unused
LLAMA_ARG_FIT_TARGET=128
```

The files are gitignored and applied on the next `make restart`. Only llama-server-backed models read `LLAMA_ARG_*`; models running on Ollama's own engine ignore them. Keep the `OLLAMA_*` knobs listed above in `.env` — those values win over the files; any other `OLLAMA_*` variable belongs in the files.

## Notes

- **On NVIDIA, set `OLLAMA_GPU_DEVICES` too.** Extra instances are pinned to explicit GPU IDs, but instance 1 falls back to a count-based reservation and may otherwise land on a GPU already assigned to `ollama2`. `make doctor` warns about this. On AMD, `OLLAMA_GPU_DEVICES` is ignored: extra instances are pinned with `HIP_VISIBLE_DEVICES`, while instance 1 still sees every GPU — pin it yourself in `docker-compose.override.yml` if that matters.
- **All instances share one model store**, so each model is downloaded only once.
- **Extra instances are internal only**, reachable at `http://ollama2:11434` from other containers — for example, add it as a second connection in Open WebUI. There are no published ports; if you need external access to a specific instance, add a `caddy-addon/site-*.conf` file.
- Lowering the count stops and removes the surplus containers on the next `make update`.
- **External API**: instance 1 is served by Caddy at `ollama.yourdomain.com` (the wildcard DNS record exposes it automatically); every request must send `Authorization: Bearer <OLLAMA_CADDY_API_TOKEN>`. A leaked token grants full control — including pulling/deleting models — not just inference.
