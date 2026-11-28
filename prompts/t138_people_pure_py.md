# t138 (AgentRpc GLM-5.3-Flash): Pure-Python Full 400 MB `people_db.dat` Decoder (Aim for All 658,011 Rows!)

You are working in `D:\tmp2b\fm24-db`. Do NOT modify `reports/`, `scratch/t01/LEDGER.json`, or any other task's `scratch/tNN/` folder. Write ONLY to `scripts/t138_people_pure_py.py` and `scratch/t138/out/`.
Use `sys.path.insert(0, r"D:\tmp2b\fm24\tools\python")` for `zstandard`. Keep `scratch/data/people_db.dat` and `D:\tmp2b\fm24\ida\editor_merge_v2.i64` strictly READ-ONLY (never write 400MB decompressed dumps to disk; decompress in memory).

## Context & Verified Ground Truth On Disk
1. `t120` proved via Unicorn that `people_db.dat` (400,443,970 B decompressed) has:
   - Header: `[2B zero][u32 count=658,011]`
   - Per record: `[u32 ordinal][u8 person_type][body]`
   - Only 5 person types appear on disk: `1=NON_PLAYER` (166,064), `2=PLAYER` (476,158), `3=ACTUAL_PLAYER_AND_NON_PLAYER` (4,757), `4=OFFICIAL` (9,839), `5=RETIRED_PERSON` (1,193).
   - `t120` cleanly walked 3,000/3,000 consecutive rows across all 5 types (`scratch/t120/out/people_unicorn_traces.json`).
2. ALL core `slot19` (read) and `slot21` (write) functions are ALREADY decompiled in:
   - `scratch/t120/out/funcs/`: `140e06ec0.c` (`PLAYER` 712L), `14145f800.c` (425L), `140dc1d30.c` (`NON_PLAYER` 870L), `1415d5110.c` (`ACTUAL_PLAYER_AND_NON_PLAYER` 21L), `1415856b0.c` (`OFFICIAL` 253L), `143f891c0.c` (`RETIRED_PERSON` 56L), `143f2b820.c` (`PERSON` base 76L)
   - `scratch/t124/out/funcs/`: `140e089c0.c` (`PLAYER::write`), `140dc40f0.c` (`NON_PLAYER::write`), `141585e80.c` (`OFFICIAL::write`), `143f89580.c` (`RETIRED::write`)
   - `scratch/t126/out/player_69b_attributes_l3.json` (54/54 `PDxx` attribute map, `PHRP/PCRP/PWRP/PCAB/PPAB` at `body[0:10]`, `positions` at `29:44`, `PDxx` at `44:98`, signed `weight/height` at `126:130`).
   - If you need any missing sub-callee `.c` (e.g. `CONTRACT` or `PERSON` helper), you MAY use `idalib` (`sys.path.insert(0, r"C:\Program Files\IDA Professional 9.4\idalib\python")`) ONLY on `scratch/t95/editor_work.i64` (NEVER touch `editor_merge_v2.i64`!) and save decompilations to `scratch/t138/out/ida/`.

## Goal
Build a fast **pure-Python** (stdlib + vendored `zstandard`, NO Unicorn / NO IDA at runtime!) streaming parser `scripts/t138_people_pure_py.py` for ALL 5 person types in `people_db.dat`:
1. Start by matching `t120`'s first **3,000 rows** (`scratch/t126/out/_walk.json`) byte-for-byte (`end_offset == 1,216,813`, 0 byte difference on every single row!).
2. Scale up to walk ALL **658,011 rows** of `people_db.dat` (`400,443,970 B`) to exact EOF/footer closure (`diff == 0`) — never using heuristic identity-skipping! Every branch must match the real C grammar. (If any rare edge case stalls before 658,011, fix it cleanly from the C code or report the exact stopping row/offset honestly.)
3. Extract per-row summary stats (exact 5-type histogram matching `basic_people_db.dat` `{1:166064, 2:476158, 3:4757, 4:9839, 5:1193}`, min/max body len per type, Top-20 players by CA with 54 `PDxx` attributes and real names from `scratch/t106/out/payload_server_name_table_extra_{0,1,2}.bin`).

## Deliverables
Write `scripts/t138_people_pure_py.py` (with `--selftest`, `--limit N`, `--verify-full`) and `scratch/t138/out/`:
1. `people_pure_py_verify.json` — exact closure metrics (`rows_decoded`, `total_bytes`, `diff`, 5-type histogram, elapsed seconds, Top-20 players sample)
2. `REPORT.md` — concise grammar + closure report
3. `DONE.md` — `DONE type=t138`, headline numbers, `--selftest` PASS

Run `py -V:3.12 -B scripts/t138_people_pure_py.py --verify-full` and `--selftest` before finishing!
