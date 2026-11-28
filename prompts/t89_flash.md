# t89-flash-lane — [NATION+0x108] 静态读链追源 + table_9(NATION_T9)文法定型(重脚手架;前作探针资产在盘)

你是受指挥官委派的子代理,**全新会话**。E127 已把 t85 遗留升级:table_9(NATION_T9,251 行,13B 头+变长体+12B identity 尾+9B 脚,严格闭包 31,956B)成立,但**条目文法 held_no_item_grammar**,且 [NATION+0x108] 集合是否就是 table_9 的 wire 家**未证**。t83(E126)已证 DATABASE 构造器把 t9 注册在 `db+0x60`(紧邻 nation `db+0x28`)。本任务用静态链一锤定音。

## 已冻结地基(直接用,不重做)

- **前作探针资产(只读,13 件共 1.3MB,全部 >20KB 禁止整读——用 grep 程序化抽取,print ≤30 行/次)**:
  `scratch/t89/probe_t9_read.txt`(164K)、`probe_t9_get_impl.txt`(226K)、`probe_t9_set_impl.txt`(175K)、`probe_t9_write.txt`(102K)、`probe_nation_get_impl.txt`(146K)、`probe_nation_set_impl.txt`(158K)、`probe_helpers.txt`(259K)、`probe_t9_ctor.txt`(25K)、`probe_t9_base_ctor.txt`、`probe_fixup_get_set.txt`、`probe_helper_*.txt`×3——前作(neon)车道被杀前落盘的 NATION+0x108 与 T9 ctor/get/set/write 静态探针段
- `scratch/t85/out2/profile_nation.json`(table_9 结构+行 0 body_head_hex 首反例+逐偏移 lane 域)、`wire_candidates.json`(双档闭包+t51 冻结游标对拍)、`collection_fields.json`(getter_proven_but_no_main_row_sink 清单;nhrl 实例:gate 17048862 "compares bounds at [this+0x108]+0x4a0/0x4a8")
- `scratch/t83/out/xref_*.json`:五表工厂/vtable/RTTI/`DATABASE` 构造器 0xf026c0 的 16 个 db+offset 绑定(含 **+0x60: t9 (NATION_T9, 251)**、+0x28: t10);getter+setter 双链范式
- `scratch/t75/out/xref_reverse.json`(1.3MB,程序化):nation_escalations 与 slots
- 静态:只读 `D:/tmp2b/fm24/input/editor.exe`(SHA-256 `b82ebe8e032f20171e813c02f53084dc0ac2c43bc8346beb742418efaadadab4`);schema `evidence/fm24/reports/editor_schema/master.json`(程序化查,不整读)
- 载荷加载:`scripts/t71_club100_cnst.py` 的 archives() 可 importlib 复用(不得修改),`raw[side,'table_9']`

## 任务(分相,每相落盘)

- **Phase 0(10 分钟内)**:先写 `scratch/t89/out/xref_nation108.json` 与 `table9_grammar.json` **骨架**(meta+status)
- **Phase 1 [NATION+0x108] 读链追源**:grep probe_nation_get_impl/probe_helpers 定位 gate 17048862 与全部 `[this+0x108]` 引用,向上回溯——类型、reader/write 路径、读的是哪个 DATABASE 表(假设 table_9@db+0x60):给 VA/fo/指令字节三件套;证实即"集合字段 wire 家=table_9"**L3 裁决**,否则 held+首反例
- **Phase 2 table_9 条目文法定型**:从 NATION_T9 类 vtable slot 19/20/21 读 handler(probe_t9_read/get_impl 已有原料)逐字节给条目网格,解释 body 46..449B 变长与 92 种长度;与行 0 反例对账:`00 ff ff ff ff 01 01 01 00 00 00 0a 00 00 00 00 00 01 5c 05 00 00 00 00`
- **Phase 3 held 集合字段回填**:nhrl 等逐个对到 table_9 条目内偏移(或证伪);过闸 L2/L3,不过闸 held+首反例
- **Phase 4 双档对拍**:table_9 client 31,956B / server 307,555B 差额(server body0=1086 vs client 46)的静态解释
- **Phase 5**:独立 `out/verify.py`(不 import builder/fm24_dump)+ builder `scripts/t89_*.py`(新文件);`--help`/`--selftest`;退出码 0/1/2;`REPORT.md` + `DONE.md`(首行 `DONE type=t89 status=complete`);跑 `scripts/t01_anchors.py`(7/7)

## 边界与纪律

1. 只做 [NATION+0x108]/table_9 及直接关联字段;不碰 club/comp 主行、t45(t88-fix2 车道在做)、五表(t83 已收)
2. 只写 `scratch/t89/out/` 和 `scripts/t89_*.py`(**不修改 scratch/t89/ 探针文件**);不碰 reports/、LEDGER
3. 不启动游戏本体/FM 编辑器(IDA 静态分析允许),不联网,不读写 Z:(editor.exe 只读);数据侧验证向量化
4. **铁律**:`>20KB` 不进会话(13 件探针全是大文件,只能 grep);print ≤30 行/次;单次写 ≤120 行;负结果原样保留;候选不写成结论
5. 自检:发现整读大文件/上下文暴涨→立即停,换程序化;两轮定不出→`escalate` 并写 `DONE status=partial`,不静默放弃
6. `py -V:3.12 -I -B`;`FM24_DB_DIR=D:/tmp2b/fm24-db/scratch/data`;zstd vendored `D:/tmp2b/fm24/tools/python`

## 交付 scratch/t89/out/

`xref_nation108.json`(读链)、`table9_grammar.json`(条目文法+行 0 对账)、`field_map.json`(held 回填增量)、`domain_stats.json`、`verify.py`、`REPORT.md`、`DONE.md`。
