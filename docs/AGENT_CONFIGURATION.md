# Local agent configuration

Public research records retain model names and technical findings. Provider/account identifiers and local service configuration belong in private environment variables or ignored local files.

- `FMDB_FLASH_PROVIDER`: local provider identifier for Flash tasks.
- `FMDB_FLASH_MODEL`: model ID accepted by that provider (default `deepseek-v4.1-flash`).
- `FMDB_GPT_PROVIDER`: local provider used in the PowerShell launcher example.
- `FMDB_NEON_COMMAND`: local executable for Neon tasks; `FMDB_NEON_MODEL` overrides the model name.
- `FMDB_RPC_ENTRYPOINT`: local Node app-server script; `FMDB_RPC_PROVIDER`: local provider ID. Optional `FMDB_RPC_CONFIG_ENV` and `FMDB_RPC_CONFIG_PATH` configure the local app-server.
- `FMDB_SESSION_MANIFEST`: private JSON array of `[session_dir, session_id, provider, model]` records; defaults to ignored `scratch/session_manifest.json`. Existing session IDs can be preserved in this local manifest.

Historical notes may use neutral lane labels. These labels describe orchestration, not different model architectures. Do not commit private configuration or raw session logs.
