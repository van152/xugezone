"""launch_agent_rpc.py — Official AgentRpc Protocol (app-server stdio JSON-RPC) headless runner.

Uses a locally configured Node app-server entrypoint with explicit `modelSelection`
({providerId, modelId}) so headless runs never depend on TUI/CLI default model state.

Usage:
  py -V:3.12 -B scripts/launch_agent_rpc.py --selftest
  py -V:3.12 -B scripts/launch_agent_rpc.py --task t111 --prompt-file prompts/t111.md --outdir scratch/t111/out
Exit codes: 0 ok, 1 error/timeout, 2 bad usage.
"""
from __future__ import annotations
import sys as _cfg_sys
from pathlib import Path as _cfg_pathlib
_cfg_sys.path.insert(0, str(_cfg_pathlib(__file__).resolve().parent))
import fm24_config as _cfg

import argparse
import json
import os
import subprocess
import sys
import threading
import time
from pathlib import Path

ROOT = Path(str(_cfg.ROOT))


class AgentRpcRpcClient:
    def __init__(self, cwd: Path = ROOT, log_file: Path | None = None):
        env = os.environ.copy()
        entrypoint = env.get("FMDB_RPC_ENTRYPOINT")
        if not entrypoint:
            raise RuntimeError("Set FMDB_RPC_ENTRYPOINT to your local app-server script")
        config_key = env.get("FMDB_RPC_CONFIG_ENV")
        config_path = env.get("FMDB_RPC_CONFIG_PATH")
        if config_key and config_path:
            env[config_key] = config_path
        self.proc = subprocess.Popen(
            ["node", entrypoint, "app-server"],
            cwd=str(cwd),
            env=env,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
            bufsize=1,
        )
        self.log_file = log_file
        self._id = 0
        self._lock = threading.Lock()
        self._pending: dict[int, dict] = {}
        self._events: list[dict] = []
        self._cond = threading.Condition()
        self._closed = False
        self._stderr_lines: list[str] = []

        self._t_out = threading.Thread(target=self._read_stdout, daemon=True)
        self._t_err = threading.Thread(target=self._read_stderr, daemon=True)
        self._t_out.start()
        self._t_err.start()

    def _log(self, msg: str):
        if self.log_file:
            with self.log_file.open("a", encoding="utf-8") as f:
                f.write(msg + "\n")

    def _read_stderr(self):
        assert self.proc.stderr is not None
        for ln in self.proc.stderr:
            ln = ln.rstrip("\r\n")
            self._stderr_lines.append(ln)
            self._log(f"[STDERR] {ln}")

    def _read_stdout(self):
        assert self.proc.stdout is not None
        for ln in self.proc.stdout:
            ln = ln.strip()
            if not ln:
                continue
            try:
                msg = json.loads(ln)
            except json.JSONDecodeError:
                self._log(f"[RAW] {ln[:300]}")
                continue
            with self._cond:
                if "id" in msg and "method" in msg:
                    # Server -> Client RPC request (e.g. session/requestRuntimePreferences, permission requests)
                    req_id = msg["id"]
                    mname = msg["method"]
                    self._log(f"[S2C] id={req_id} method={mname} params={json.dumps(msg.get('params'), ensure_ascii=False)[:250]}")
                    reply = {"id": req_id, "result": {}}
                    if "requestRuntimePreferences" in mname:
                        reply = {"id": req_id, "result": {"nativeSearchEnhancementsEnabled": False}}
                    elif "permission" in mname.lower():
                        reply = {"id": req_id, "result": {"decision": "allow"}}
                    assert self.proc.stdin is not None
                    self.proc.stdin.write(json.dumps(reply) + "\n")
                    self.proc.stdin.flush()
                elif "id" in msg and ("result" in msg or "error" in msg):
                    self._pending[msg["id"]] = msg
                else:
                    self._events.append(msg)
                    ev = msg.get("method") or msg.get("type") or ""
                    if ev:
                        self._log(f"[EVT] {ev}: {json.dumps(msg.get('params', msg), ensure_ascii=False)[:300]}")
                self._cond.notify_all()
        with self._cond:
            self._closed = True
            self._cond.notify_all()

    def call(self, method: str, params: dict, timeout: float = 60.0) -> dict:
        with self._lock:
            self._id += 1
            rid = self._id
        req = {"id": rid, "method": method, "params": params}
        assert self.proc.stdin is not None
        self.proc.stdin.write(json.dumps(req, ensure_ascii=False) + "\n")
        self.proc.stdin.flush()

        deadline = time.time() + timeout
        with self._cond:
            while rid not in self._pending and not self._closed:
                rem = deadline - time.time()
                if rem <= 0:
                    raise TimeoutError(f"RPC timeout waiting for {method}")
                self._cond.wait(timeout=min(rem, 1.0))
            if rid not in self._pending:
                raise RuntimeError(f"app-server closed before replying to {method}; stderr={self._stderr_lines[-5:]}")
            resp = self._pending.pop(rid)
        if "error" in resp:
            raise RuntimeError(f"RPC error in {method}: {resp['error']}")
        return resp["result"]

    def wait_for_idle(self, session_id: str, timeout: float = 1800.0) -> tuple[bool, str]:
        deadline = time.time() + timeout
        last_text = ""
        seen_idx = 0
        while time.time() < deadline:
            with self._cond:
                while seen_idx < len(self._events):
                    ev = self._events[seen_idx]
                    seen_idx += 1
                    p = ev.get("params", {})
                    if isinstance(p, dict):
                        et = p.get("eventType") or p.get("type") or ev.get("method", "")
                        # Capture assistant text / completion signals
                        payload = p.get("event") or p.get("payload") or p
                        if isinstance(payload, dict):
                            pt = payload.get("type") or ""
                            if pt in ("turn_completed", "turn_failed", "turn_aborted", "turn.completed", "turn.failed", "idle"):
                                return (pt not in ("turn_failed", "turn_aborted", "turn.failed")), json.dumps(payload, ensure_ascii=False)[:500]
                            if "text" in payload and isinstance(payload["text"], str):
                                last_text += payload["text"]
                if self._closed:
                    return False, f"app-server exited; stderr={self._stderr_lines[-5:]}"
                self._cond.wait(timeout=2.0)
            # Also poll session/read every few seconds to check busy/status reliably
            try:
                snap = self.call("session/read", {"sessionId": session_id}, timeout=15.0)
                st = snap.get("status") or snap.get("state") or snap.get("lifecycleState")
                is_busy = snap.get("isBusy") or snap.get("busy") or snap.get("running")
                msgs = snap.get("messages") or []
                if msgs:
                    last_m = msgs[-1]
                    if last_m.get("role") == "assistant":
                        content = last_m.get("content") or last_m.get("text") or ""
                        if isinstance(content, list):
                            content = "\n".join(
                                b.get("text", "") for b in content if isinstance(b, dict) and b.get("type") == "text"
                            )
                        if content:
                            last_text = str(content)
                if is_busy is False or st in ("idle", "ready", "completed", "error", "failed"):
                    if msgs and msgs[-1].get("role") == "assistant":
                        return (st not in ("error", "failed")), last_text
            except Exception:
                pass
        return False, f"timeout after {timeout}s; last_text={last_text[:300]}"

    def close(self):
        try:
            self.proc.terminate()
            self.proc.wait(timeout=5)
        except Exception:
            try:
                self.proc.kill()
            except Exception:
                pass


def run_prompt(
    prompt: str,
    cwd: Path,
    provider_id: str,
    model_id: str,
    mode: str,
    thought_level: str,
    timeout: float,
    log_file: Path | None = None,
) -> tuple[bool, str, str]:
    cli = AgentRpcRpcClient(cwd=cwd, log_file=log_file)
    try:
        model_sel = {"providerId": provider_id, "modelId": model_id}
        res = cli.call(
            "session/create",
            {
                "workspace": {"workspacePath": str(cwd), "workspaceKey": str(cwd)},
                "mode": mode,
                "model": model_sel,
                "thoughtLevel": thought_level,
            },
            timeout=30.0,
        )
        sid = res.get("sessionId") or (res.get("value") or {}).get("sessionId")
        if not sid:
            raise RuntimeError(f"No sessionId in session/create result: {json.dumps(res)[:300]}")
        cli._log(f"[INFO] session created: {sid}")

        try:
            cli.call("session/subscribe", {"sessionId": sid}, timeout=10.0)
        except Exception:
            pass

        send_res = cli.call(
            "session/send",
            {
                "sessionId": sid,
                "content": prompt,
                "modelSelection": model_sel,
            },
            timeout=60.0,
        )
        cli._log(f"[INFO] session/send ack: {json.dumps(send_res, ensure_ascii=False)[:300]}")
        ok, text = cli.wait_for_idle(sid, timeout=timeout)
        try:
            cli.call("session/close", {"sessionId": sid}, timeout=10.0)
        except Exception:
            pass
        return ok, sid, text
    finally:
        cli.close()


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    ap = argparse.ArgumentParser(description="Run AgentRpc headless agent via official app-server JSON-RPC.")
    ap.add_argument("--task", default="agent_rpc_task")
    ap.add_argument("--prompt", default="")
    ap.add_argument("--prompt-file", type=Path, default=None)
    ap.add_argument("--outdir", type=Path, default=None)
    ap.add_argument("--cwd", type=Path, default=ROOT)
    ap.add_argument("--provider", default=os.environ.get("FMDB_RPC_PROVIDER"),
                    required=not bool(os.environ.get("FMDB_RPC_PROVIDER")))
    ap.add_argument("--model", default="GLM-5.3-Flash")
    ap.add_argument("--mode", default="yolo", choices=["plan", "edit", "build", "yolo", "guarded"])
    ap.add_argument("--thought", default="max")
    ap.add_argument("--timeout", type=float, default=1800.0)
    ap.add_argument("--selftest", action="store_true")
    args = ap.parse_args()

    if args.selftest:
        log = ROOT / "scratch/t02/pi-logs/agent_rpc_selftest.log"
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text("", encoding="utf-8")
        ok, sid, text = run_prompt(
            "Reply with ONLY the two letters OK.",
            args.cwd,
            args.provider,
            args.model,
            "plan",
            "low",
            60.0,
            log,
        )
        print(f"SELFTEST ok={ok} sid={sid} reply={text[:200]!r}")
        return 0 if ok and "OK" in text.upper() else 1

    if args.prompt_file:
        prompt = args.prompt_file.read_text(encoding="utf-8")
    elif args.prompt:
        prompt = args.prompt
    else:
        print("Need --prompt or --prompt-file", file=sys.stderr)
        return 2

    if args.outdir:
        args.outdir.mkdir(parents=True, exist_ok=True)
        prompt += f"\n\n---\n## 本次任务参数\n- OUTDIR = {args.outdir}\n- 若目录已有中间进度则续作。完成后写 DONE.md（含 DONE type={args.task}）并打印交付清单与核心统计。\n"

    log = ROOT / f"scratch/t02/pi-logs/{args.task}_agent_rpc.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text("", encoding="utf-8")

    ok, sid, text = run_prompt(
        prompt,
        args.cwd,
        args.provider,
        args.model,
        args.mode,
        args.thought,
        args.timeout,
        log,
    )
    print(f"=== AGENT_RPC {args.task} ok={ok} sid={sid} ===")
    print(text[-2000:])
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
