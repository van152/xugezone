# t139 (AgentRpc GLM-5.3-Flash): FM24 Unified Read-Only Database Explorer & SQLite Exporter CLI

You are working in `D:\tmp2b\fm24-db`. Do NOT modify `reports/`, `scratch/t01/LEDGER.json`, or any existing `scripts/tNN_*.py` files. Write ONLY to `scripts/t139_fm24_db_cli.py` and `scratch/t139/out/`.
Use `sys.path.insert(0, r"D:\tmp2b\fm24\tools\python")` for `zstandard`.

## Context & Verified Pure-Python Building Blocks Already On Disk
We now have 100% pure-Python, verified decoders for the entire FM24 core database:
1. `scripts/t133_fm24_reader_v2.py` — **79 / 79 numbered tables** in `server_db.dat` + `client_db.dat` (2,846,936 rows, 9.08s, 100% `diff=0`!)
2. `scripts/t106_special_members.py` — **13 / 13 special members** (`name_table_0/1/2` + `name_table_extra_0/1/2` 873,709 UTF-8 names, `club_links` 9,261, `common_name_links` 12,056, `simple_vars` 28,552, `summary.dat` 54,087)
3. `scratch/data/basic_people_db.dat` — **658,011 people** (`{1:166064, 2:476158, 3:4757, 4:9839, 5:1193}`, `CA` at `+48`, `PA` at `+50`, `birth_year` at `+52`, `uid` at `+75`, `diff=0`)
4. `scratch/t135/out/star_player_cards.json` (21 world superstars with full 54 `PDxx` attributes) and `scratch/t126/out/player_69b_attributes_l3.json` (54/54 `PDxx` L3 map)

## Goal
Build a clean, fast, practical, zero-dependency (Python stdlib `sqlite3` + vendored `zstandard`) unified FM24 database tool `scripts/t139_fm24_db_cli.py` that:
1. **Exports a normalized, indexed SQLite database** (`scratch/t139/out/fm24_core.sqlite`) containing:
   - Core entity tables decoded via `t133`: `nations` (`server/10`, 251 rows), `clubs` (`server/3`, 84,259 rows), `competitions` (`server/25`, 7,047 rows), `stadiums` (`server/21`, 48,413 rows), `cities` (`server/2`, 56,293 rows), `awards` (`server/0`, 3,545 rows), `languages` (`server/8`, 126 rows), `injuries` (`server/6`, 115 rows), `weather` (`server/27`, 334 rows), `currencies` (`server/41`, 173 rows), `starting_records` (`server/45`, 84,477 rows), `teams` (`server/24`, 84,507 rows)
   - Name pools (`name_first` 245,981, `name_second` 542,060, `name_common` 85,668 from `t106`)
   - `basic_people` (all 658,011 rows with `ordinal`, `person_type`, `uid`, `ca` at `+48`, `pa` at `+50`, `birth_year` at `+52`)
   - `star_player_attributes` (all 21 superstars × 54 `PDxx` attributes from `t135`)
   - `table_inventory` (all 79 numbered tables + 13 special members with exact row counts & closure status)
   - Proper SQLite indexes on `uid`, `ordinal`, `ca`, `name` so queries return in < 5ms!
2. **Provides a clean CLI**:
   - `--build-sqlite` (builds `scratch/t139/out/fm24_core.sqlite` + integrity report)
   - `--stats` (prints row counts across all SQLite tables)
   - `--query-uid <UID>` (looks up a person/club/comp/nation/stadium by UID)
   - `--top-players <N>` (queries Top-N players by CA with PA & birth_year)
   - `--search-name <TEXT>` (searches across clubs, competitions, stadiums, names)
   - `--selftest` (verifies exact row counts in SQLite match source `.dat` counts: 251 nations, 84,259 clubs, 7,047 comps, 48,413 stadiums, 56,293 cities, 658,011 basic_people, 245,981+542,060+85,668 names, plus queries Harry Kane `28049320`, Lionel Messi `7458500`, Cristiano Ronaldo `735216`, England, Premier League!)

## Deliverables
Write `scripts/t139_fm24_db_cli.py` and `scratch/t139/out/`:
1. `fm24_core.sqlite` — verified indexed SQLite database
2. `export_summary.json` — exact table row counts, build time, DB size, integrity checks
3. `REPORT.md` — concise user guide with example CLI commands & sample query outputs
4. `DONE.md` — `DONE type=t139`, total rows exported, DB size, `--selftest` PASS

Run `py -V:3.12 -B scripts/t139_fm24_db_cli.py --build-sqlite` and `--selftest` before finishing!
