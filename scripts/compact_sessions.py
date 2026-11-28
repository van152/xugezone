"""Compact every pi session via RPC mode (--mode rpc), 3 per minute.

Compact requires an LLM call, so provider must be live. Retries throttled providers.
Usage: py -V:3.12 -I scripts/compact_sessions.py [--limit N] [--dry]
"""
from __future__ import annotations
import json
import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PI = shutil.which("pi") or "pi"
# On Windows `pi` resolves to a .cmd shim, which needs a shell to exec.
USE_SHELL = PI.lower().endswith((".cmd", ".bat"))

# (session_dir, session_id, provider, model)
def load_sessions():
    manifest = Path(os.environ.get("FMDB_SESSION_MANIFEST", str(ROOT / "scratch/session_manifest.json")))
    if not manifest.is_file():
        raise SystemExit("Set FMDB_SESSION_MANIFEST to a private JSON array of [session_dir, session_id, provider, model] records.")
    return json.loads(manifest.read_text(encoding="utf-8"))


def session_file(sdir: str, sid: str) -> Path | None:
    d = ROOT / sdir
    hits = sorted(d.glob(f"*_{sid}.jsonl"))
    return hits[-1] if hits else None


def compact_one(sdir: str, sid: str, provider: str | None, model: str | None, timeout=300):
    f = session_file(sdir, sid)
    if not f:
        return False, "no session file", 0
    size_before = f.stat().st_size

    cmd = [PI, "--mode", "rpc", "--session-dir", sdir, "--session-id", sid]
    if provider: cmd += ["--provider", provider]
    if model: cmd += ["--model", model]

    try:
        p = subprocess.Popen(cmd, cwd=str(ROOT), stdin=subprocess.PIPE,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             text=True, encoding="utf-8", errors="replace", bufsize=1,
                             shell=USE_SHELL)
    except Exception as e:
        return False, f"spawn failed: {e}", 0

    try:
        # send compact command
        p.stdin.write(json.dumps({"id": "c1", "type": "compact"}) + "\n")
        p.stdin.flush()

        deadline = time.time() + timeout
        while time.time() < deadline:
            line = p.stdout.readline()
            if not line:
                if p.poll() is not None:
                    break
                continue
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except json.JSONDecodeError:
                continue
            if rec.get("type") == "response" and rec.get("command") == "compact":
                ok = bool(rec.get("success"))
                data = rec.get("data") or {}
                det = f"{data.get('tokensBefore')}->{data.get('estimatedTokensAfter')}" if ok else str(rec.get("error"))
                return ok, det, size_before
    except Exception as e:
        return False, f"io: {e}", size_before
    finally:
        try: p.stdin.close()
        except Exception: pass
        try: p.terminate()
        except Exception: pass
        try: p.wait(timeout=10)
        except Exception: p.kill()
    return False, "timeout/no response", size_before


def main():
    limit = None
    dry = "--dry" in sys.argv
    if "--limit" in sys.argv:
        limit = int(sys.argv[sys.argv.index("--limit") + 1])
    only = None
    if "--only" in sys.argv:
        only = set(sys.argv[sys.argv.index("--only") + 1].split(","))

    items = load_sessions()
    if only:
        items = [s for s in items if s[1] in only]
    if limit:
        items = items[:limit]
    print(f"targets: {len(items)} sessions; 3 per minute (20s apart)\n")
    if dry:
        for sdir, sid, prov, model in items:
            f = session_file(sdir, sid)
            print(f"  {sid:16} {f.name if f else 'MISSING':50} {f.stat().st_size if f else 0:,} B")
        return

    ok_n = 0
    for i, (sdir, sid, prov, model) in enumerate(items):
        f = session_file(sdir, sid)
        before = f.stat().st_size if f else 0
        print(f"[{i+1}/{len(items)}] {sid} ({before:,} B) ... ", end="", flush=True)
        ok, detail, _ = compact_one(sdir, sid, prov, model)
        after = f.stat().st_size if f else 0
        print(f"{'OK' if ok else 'FAIL'} {detail}  ({before:,} -> {after:,} B)")
        ok_n += ok
        if i < len(items) - 1:
            time.sleep(20)   # 3 per minute
    print(f"\ndone: {ok_n}/{len(items)} compacted")


if __name__ == "__main__":
    main()
