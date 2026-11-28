# t128c: `non_pl_hist_{dt,id,index}.dat` (Non-Playing / Manager & Staff History 3-File System) Exact Closure

You are working in `D:\tmp2b\fm24-db`. Do NOT modify `reports/` or `scratch/t01/LEDGER.json`. Write ONLY to `scripts/t128_non_pl_hist.py` and `scratch/t128/out/`.
Keep stdout compact (< 50 lines per command).
Use `sys.path.insert(0, r"D:\tmp2b\fm24\tools\python")` to import `zstandard` (do NOT use `ctypes.util.find_library`).

## Reference Blueprint (ALREADY SOLVED FOR `pl_hist`!)
Read `scripts/t127_pl_hist.py` and `scratch/t127/out/REPORT.md` first!
`pl_hist_{index,id,dt}.dat` was already 100% solved (`diff=0`, 37/37 `--selftest` PASS):
- Shared 5-byte magic `03 01 'tad'` + tags (`index=0x0df1`, `id=0x0001`, `dt=0x0003`)
- `dt` is chunked into uniform 4,096 B zstd frames + a trailing `0x184D2A5E` skippable frame carrying the chunk table
- `id` pairs are `[first, last]` inclusive row indices (NOT half-open!)
- `index` maps `person_uid -> ordinal`
Check whether `non_pl_hist_{index,id,dt}.dat` follows the exact same container architecture (and measure its exact row stride, field layout, and chain structure — never assume stride=44 without proving it!).

## Inputs (READ-ONLY)
- `scratch/data/non_pl_hist_dt.dat` (27.6 MB)
- `scratch/data/non_pl_hist_id.dat` (6.0 MB)
- `scratch/data/non_pl_hist_index.dat` (4.2 MB)
- `scratch/t123/out/basic_people_l3_schema.json` / `scripts/t123_basic_people_l3.py` (or `scratch/t139/out/fm24_core.sqlite`) to resolve manager/staff names and club names for real-world anchor verification!

## Mission
1. Decompress in-memory (do NOT dump giant raw blobs to disk) all 3 files: `non_pl_hist_index.dat`, `non_pl_hist_id.dat`, `non_pl_hist_dt.dat`.
2. Prove exact container framing, chunk table match (`chunk_table == scanned frames`), record counts, exact row stride, and **zero-byte closure (`closure_diff == 0`)** across ALL indexed non-playing staff records!
3. Verify full index → id → dt linkage:
   - `offsets_in_bounds == True`, `misaligned == 0`, `contiguity_violations == 0`, `rows_accounted == dt_rows`
   - Verify chain pointer / terminator invariants if present.
4. Decode the exact byte-by-byte layout of a non-playing career history row (dates, club_id, nation_id / job role enum, etc. — clearly separating verified fields from any remaining unknown bytes!).
5. Decode and cross-verify real career timelines for **at least 5 famous managers** (e.g., Pep Guardiola, Jürgen Klopp, Carlo Ancelotti, José Mourinho, Mikel Arteta / Diego Simeone — look up their real UIDs in `scratch/t139/out/fm24_core.sqlite` or `basic_people_db.dat` + `name_table_extra_*`!) plus 10 general sample records.

## Deliverables
1. `scripts/t128_non_pl_hist.py` (supporting default run, `--uid <UID>`, and `--selftest` with >= 25 assertions including real manager career anchors!)
2. `scratch/t128/out/non_pl_hist_schema.json`
3. `scratch/t128/out/REPORT.md` (with famous manager career tables + byte layout + honest unknown-byte list)
4. `scratch/t128/out/DONE.md` (first line `DONE type=t128c`, key counts, `closure_diff=0`, `--selftest PASS`)

Run `py -V:3.12 -B scripts/t128_non_pl_hist.py` and `py -V:3.12 -B scripts/t128_non_pl_hist.py --selftest` and verify 0 failures before finishing!
