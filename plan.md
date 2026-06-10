# DESI 光谱流水线简易工作流计划

以 **shell 命令 + txt 文件** 模拟 [DESI 光谱处理流水线](https://desidatamodel.readthedocs.io/en/latest/)（原始数据 → `cframe`），作为 Snakemake 教程的前置原型。

---

## 1. 设计原则

| 原则 | 说明 |
|------|------|
| txt 代替 FITS | 每个 DESI 产物用同名 `.txt` 占位，内容记录元数据与上游依赖 |
| shell 循环即 rule | 每个处理步骤对应 `workflow.sh` 中的一段 `for` 循环 |
| 按 exptype 分支 | `arc` / `flat` / `science` 走不同子流程，与正式流水线一致 |
| 粒度对齐 DESI | `NIGHT` → `EXPID` → `CAMERA`（如 `b0`、`r2`）三级目录 |
| 每晚汇总 | `psfnight`、`fiberflatnight` 放在 `calibnight/NIGHT/`，依赖当晚多个曝光 |

不做真实 CCD 处理；txt 文件通过 `grep` / 重定向表达「输入 → 输出」的数据流。

---

## 2. 目录结构

```
snakemake_tutorial/
├── data/                              # 原始「观测」数据（输入）
│   └── {night}/{expid}/
│       └── just_{expid}.txt           # 曝光描述文件
│
└── redux/                             # 处理产物（输出，类比 SPECPROD）
    ├── preproc/{night}/{expid}/       # ① preproc
    ├── calibnight/{night}/            # ③ psfnight, ⑦ fiberflatnight
    └── exposures/{night}/{expid}/     # 其余 per-exposure 产物
```

### 2.1 输入文件格式 `just_{expid}.txt`

```text
night=20261128
expid=31415928
exptype=science          # arc | flat | science
b0    1                  # camera → 光谱仪编号（示意）
r0    2
z0    3
b2    4
r2    5
z2    6
```

- 每行 `camera specid` 表示该曝光包含哪些相机
- `exptype` 决定后续走哪条分支

### 2.2 输出 txt 命名约定

| DESI 产物 | 简易 txt 文件名 | 路径 |
|-----------|----------------|------|
| preproc | `preproc_{camera}_{expid}.txt` | `redux/preproc/{night}/{expid}/` |
| fit-psf | `fit-psf-{camera}-{expid}.txt` | `redux/exposures/{night}/{expid}/` |
| psf | `psf-{camera}-{expid}.txt` | `redux/exposures/{night}/{expid}/` |
| psfnight | `psfnight-{camera}-{night}.txt` | `redux/calibnight/{night}/` |
| traceshift | `traceshift-{camera}-{expid}.txt` | `redux/exposures/{night}/{expid}/` |
| frame | `frame-{camera}-{expid}.txt` | `redux/exposures/{night}/{expid}/` |
| fiberflat | `fiberflat-{camera}-{expid}.txt` | `redux/exposures/{night}/{expid}/` |
| fiberflatnight | `fiberflatnight-{camera}-{night}.txt` | `redux/calibnight/{night}/` |
| fiberflatexp | `fiberflatexp-{camera}-{expid}.txt` | `redux/exposures/{night}/{expid}/` |
| sky | `sky-{camera}-{expid}.txt` | `redux/exposures/{night}/{expid}/` |
| sframe | `sframe-{camera}-{expid}.txt` | `redux/exposures/{night}/{expid}/` |
| stdstars | `stdstars-{specid}-{expid}.txt` | `redux/exposures/{night}/{expid}/` |
| fluxcalib | `fluxcalib-{camera}-{expid}.txt` | `redux/exposures/{night}/{expid}/` |
| cframe | `cframe-{camera}-{expid}.txt` | `redux/exposures/{night}/{expid}/` |

### 2.3 产物 txt 内容模板

每个产物 txt 至少包含：

```text
step=frame
night=20261128
expid=31415928
camera=b0
exptype=science
in_preproc=redux/preproc/20261128/31415928/preproc_b0_31415928.txt
in_psfnight=redux/calibnight/20261128/psfnight-b0-20261128.txt
```

便于 `grep` 追溯依赖链。

---

## 3. 流水线总览

```
原始 just_{expid}.txt
        │
        ▼
   ① preproc ───────────────────────────── 所有 exptype
        │
        ├─[arc]──► ② psf ──► ③ psfnight (每晚每 camera)
        │
        ├─[flat]─► ④ traceshift ──► ⑤ extract(frame)
        │              │                    │
        │              │                    ▼
        │              │              ⑥ fiberflat
        │              │                    │
        │              │                    ▼
        │              │              ⑦ fiberflatnight (每晚每 camera)
        │
        └─[science]► ④ traceshift ──► ⑤ extract(frame)
                              │
                              ▼
                         ⑧ sky (+ sframe)
                              │
                              ▼
                         ⑨ starfit
                              │
                              ▼
                        ⑩ fluxcalib
                              │
                              ▼
                        ⑪ cframe  ◄── 终点
```

---

## 4. 各 Rule 详细计划

### ① rule preproc（所有曝光）

| 项 | 内容 |
|----|------|
| 触发 | `data/{night}/{expid}/just_{expid}.txt` 存在 |
| 条件 | 无 |
| 输出 | `redux/preproc/{night}/{expid}/preproc_{camera}_{expid}.txt` |
| 逻辑 | 遍历 `just_*.txt`，对每个出现的 camera 写 preproc txt |
| 状态 | **已实现**（`workflow.sh` L7–21） |

```bash
# 伪代码
for file in $(find data -name "just_*.txt"); do
    parse night, expid
    for camera in cameras_in_file; do
        mkdir -p redux/preproc/${night}/${expid}
        { echo "step=preproc"; grep exptype; grep $camera; } \
            > redux/preproc/${night}/${expid}/preproc_${camera}_${expid}.txt
    done
done
```

---

### ② rule psf（仅 arc）

| 项 | 内容 |
|----|------|
| 触发 | `preproc_*.txt` 且 `exptype=arc` |
| 输入 | `redux/preproc/{night}/{expid}/preproc_{camera}_{expid}.txt` |
| 输出 | `redux/exposures/{night}/{expid}/fit-psf-{camera}-{expid}.txt` |
| 逻辑 | 从 preproc 复制元数据，标注 `step=psf` |
| 状态 | **部分实现**（仅写 fit-psf，缺 psf-*.txt） |

```bash
for file in $(find redux/preproc -name "preproc_*.txt"); do
    parse night, expid, camera
    if grep -q "exptype=arc" "$file"; then
        mkdir -p redux/exposures/${night}/${expid}
        { echo "step=fit-psf"; cat "$file"; } \
            > redux/exposures/${night}/${expid}/fit-psf-${camera}-${expid}.txt
        { echo "step=psf"; echo "in_fit_psf=..."; cat "$file"; } \
            > redux/exposures/${night}/${expid}/psf-${camera}-${expid}.txt
    fi
done
```

---

### ③ rule psfnight（每晚，仅 arc）

| 项 | 内容 |
|----|------|
| 触发 | 当晚所有 arc 的 `psf-{camera}-{expid}.txt` 就绪 |
| 输入 | `redux/exposures/{night}/*/psf-{camera}-*.txt`（同 camera 聚合） |
| 输出 | `redux/calibnight/{night}/psfnight-{camera}-{night}.txt` |
| 逻辑 | 按 `(night, camera)` 分组，列出所依赖的 arc expid |
| 状态 | **未实现**（`workflow.sh` 中 nightpdf 仅 echo，未写文件） |

```bash
# 按 night+camera 聚合
for night_dir in redux/exposures/*/; do
    night=$(basename "$night_dir")
    for camera in b0 r0 z0 b2 r2 z2; do
        psf_files=$(find "$night_dir" -name "psf-${camera}-*.txt" | sort)
        [[ -z "$psf_files" ]] && continue
        mkdir -p redux/calibnight/${night}
        { echo "step=psfnight"; echo "night=$night"; echo "camera=$camera"
          echo "inputs:"; echo "$psf_files"; } \
            > redux/calibnight/${night}/psfnight-${camera}-${night}.txt
    done
done
```

---

### ④ rule traceshift（flat + science）

| 项 | 内容 |
|----|------|
| 触发 | `preproc` 完成 + `psfnight` 存在 |
| 输入 | preproc txt + `psfnight-{camera}-{night}.txt` |
| 输出 | `redux/exposures/{night}/{expid}/traceshift-{camera}-{expid}.txt` |
| 条件 | `exptype=flat` 或 `exptype=science` |
| 状态 | **未实现** |

---

### ⑤ rule extract → frame（flat + science）

| 项 | 内容 |
|----|------|
| 触发 | traceshift 完成 |
| 输入 | preproc + psfnight + traceshift |
| 输出 | `redux/exposures/{night}/{expid}/frame-{camera}-{expid}.txt` |
| 条件 | `exptype=flat` 或 `exptype=science` |
| 状态 | **未实现** |

```bash
# frame 内容示意
step=frame
night=20261128
expid=31415928
camera=b0
exptype=science
unit=electron/Angstrom
in_preproc=...
in_psfnight=...
in_traceshift=...
```

---

### ⑥ rule fiberflat（仅 flat）

| 项 | 内容 |
|----|------|
| 触发 | flat 曝光的 `frame` 就绪 |
| 输入 | `frame-{camera}-{expid}.txt`（flat） |
| 输出 | `redux/exposures/{night}/{expid}/fiberflat-{camera}-{expid}.txt` |
| 状态 | **未实现** |

---

### ⑦ rule fiberflatnight（每晚，仅 flat）

| 项 | 内容 |
|----|------|
| 触发 | 当晚所有 flat 的 fiberflat 就绪 |
| 输入 | `redux/exposures/{night}/*/fiberflat-{camera}-*.txt` |
| 输出 | `redux/calibnight/{night}/fiberflatnight-{camera}-{night}.txt` |
| 状态 | **未实现** |

---

### ⑧ rule sky + sframe（仅 science）

| 项 | 内容 |
|----|------|
| 触发 | science 的 `frame` + `fiberflatexp` 就绪 |
| 输入 | frame + fiberflatexp（由 fiberflatnight 派生） |
| 输出 | `sky-{camera}-{expid}.txt`、`sframe-{camera}-{expid}.txt` |
| 公式 | `sframe = frame / flatfield - sky`（仅在 txt 中记录关系） |
| 状态 | **未实现** |

```bash
# fiberflatexp：science 曝光引用当晚 fiberflatnight
{ echo "step=fiberflatexp"
  echo "in_fiberflatnight=redux/calibnight/${night}/fiberflatnight-${camera}-${night}.txt"
  ...
} > redux/exposures/${night}/${expid}/fiberflatexp-${camera}-${expid}.txt
```

---

### ⑨ rule starfit（仅 science）

| 项 | 内容 |
|----|------|
| 触发 | `sframe` 就绪 |
| 输入 | sframe（标准星光纤） |
| 输出 | `redux/exposures/{night}/{expid}/stdstars-{specid}-{expid}.txt` |
| 粒度 | 按光谱仪 `specid`（从 camera 末位数字提取，如 b**2** → specid=2） |
| 状态 | **未实现** |

---

### ⑩ rule fluxcalib（仅 science）

| 项 | 内容 |
|----|------|
| 触发 | sframe + stdstars 就绪 |
| 输入 | sframe + stdstars |
| 输出 | `redux/exposures/{night}/{expid}/fluxcalib-{camera}-{expid}.txt` |
| 状态 | **未实现** |

---

### ⑪ rule cframe（仅 science，终点）

| 项 | 内容 |
|----|------|
| 触发 | frame + fiberflatexp + sky + fluxcalib 就绪 |
| 输入 | 上述四个产物 |
| 输出 | `redux/exposures/{night}/{expid}/cframe-{camera}-{expid}.txt` |
| 公式 | `cframe.flux = (frame / flatfield - sky) / fluxcalib` |
| 单位 | `10^-17 erg/s/cm2/Angstrom`（写在 txt 元数据中） |
| 状态 | **未实现** |

```bash
{ echo "step=cframe"
  echo "unit=1e-17_erg/s/cm2/Angstrom"
  echo "in_frame=..."
  echo "in_fiberflatexp=..."
  echo "in_sky=..."
  echo "in_fluxcalib=..."
} > redux/exposures/${night}/${expid}/cframe-${camera}-${expid}.txt
```

---

## 5. exptype 与步骤对照表

| 步骤 | arc | flat | science |
|------|:---:|:----:|:-------:|
| ① preproc | ✓ | ✓ | ✓ |
| ② psf | ✓ | — | — |
| ③ psfnight | ✓（每晚） | — | — |
| ④ traceshift | — | ✓ | ✓ |
| ⑤ frame | — | ✓ | ✓ |
| ⑥ fiberflat | — | ✓ | — |
| ⑦ fiberflatnight | — | ✓（每晚） | — |
| ⑧ sky / sframe | — | — | ✓ |
| ⑨ starfit | — | — | ✓ |
| ⑩ fluxcalib | — | — | ✓ |
| ⑪ cframe | — | — | ✓ |

---

## 6. 示例数据与预期产物

当前 `data/20261128/` 下有 4 个曝光：

| expid | exptype | 用途 |
|-------|---------|------|
| 31415926 | arc | 产生 psf → psfnight |
| 31415927 | flat | 产生 fiberflat → fiberflatnight |
| 31415928 | science | 最终应产出 cframe |
| 31415929 | arc | 同上，并入 psfnight |

### science 曝光 31415928 的依赖链（单 camera 以 b0 为例）

```
data/20261128/31415928/just_31415928.txt
  → preproc_b0_31415928.txt
  → psfnight-b0-20261128.txt        (来自 31415926, 31415929 的 arc)
  → traceshift-b0-31415928.txt
  → frame-b0-31415928.txt
  → fiberflatexp-b0-31415928.txt    (来自 31415927 的 flat)
  → sky-b0-31415928.txt
  → sframe-b0-31415928.txt
  → stdstars-1-31415928.txt         (specid 来自 b0 的末位 0→ 需约定映射)
  → fluxcalib-b0-31415928.txt
  → cframe-b0-31415928.txt          ★ 终点
```

6 个 camera × 1 个 science 曝光 = **6 个 cframe txt**。

---

## 7. 执行顺序与脚本组织

建议 `scripts/workflow.sh` 按依赖顺序分段，每段可独立运行（后续由 Snakemake 接管）：

```bash
#!/usr/bin/env bash
set -euo pipefail

CAMERAS=(b0 r0 z0 b2 r2 z2)

rule_preproc()      { ... }   # ① 已实现
rule_psf()          { ... }   # ② 部分实现
rule_psfnight()     { ... }   # ③ 待实现
rule_traceshift()   { ... }   # ④ 待实现
rule_extract()      { ... }   # ⑤ 待实现
rule_fiberflat()    { ... }   # ⑥ 待实现
rule_fiberflatnight(){ ... }  # ⑦ 待实现
rule_sky()          { ... }   # ⑧ 待实现
rule_starfit()      { ... }   # ⑨ 待实现
rule_fluxcalib()    { ... }   # ⑩ 待实现
rule_cframe()       { ... }   # ⑪ 待实现

rule_preproc
rule_psf
rule_psfnight
rule_traceshift
rule_extract
rule_fiberflat
rule_fiberflatnight
rule_sky
rule_starfit
rule_fluxcalib
rule_cframe
```

运行方式：

```bash
bash scripts/workflow.sh
```

---

## 8. 实施阶段

| 阶段 | 内容 | 状态 |
|------|------|------|
| P0 | 确定目录、命名、输入格式 | 完成 |
| P1 | ① preproc + ② psf（arc 分支） | 部分完成 |
| P2 | ③ psfnight（每晚汇总） | 待做 |
| P3 | ④⑤ flat/science 公共步骤（traceshift, frame） | 待做 |
| P4 | ⑥⑦ flat 分支（fiberflat, fiberflatnight） | 待做 |
| P5 | ⑧⑨⑩⑪ science 分支（sky → cframe） | 待做 |
| P6 | 迁移至 Snakefile，用 DAG 管理依赖 | 后续 |

---

## 9. 迁移到 Snakemake 的映射

| shell rule | Snakefile rule 名 | 关键 wildcards |
|------------|-------------------|----------------|
| preproc | `preproc` | `{night}`, `{expid}`, `{camera}` |
| psf | `psf` | `{night}`, `{expid}`, `{camera}` |
| psfnight | `psfnight` | `{night}`, `{camera}` |
| traceshift | `traceshift` | `{night}`, `{expid}`, `{camera}` |
| extract | `frame` | `{night}`, `{expid}`, `{camera}` |
| fiberflat | `fiberflat` | `{night}`, `{expid}`, `{camera}` |
| fiberflatnight | `fiberflatnight` | `{night}`, `{camera}` |
| sky | `sky` / `sframe` | `{night}`, `{expid}`, `{camera}` |
| starfit | `starfit` | `{night}`, `{expid}`, `{specid}` |
| fluxcalib | `fluxcalib` | `{night}`, `{expid}`, `{camera}` |
| cframe | `cframe` | `{night}`, `{expid}`, `{camera}` |

`rule all` 目标可设为所有 science 曝光的 `cframe-{camera}-{expid}.txt`。

---

## 10. 参考

- [DESI Data Model](https://desidatamodel.readthedocs.io/en/latest/)
- [desispec Pipeline Use](https://desispec.readthedocs.io/en/0.51.13/pipeline.html)
- [sframe 数据模型](https://desidatamodel.readthedocs.io/en/latest/DESI_SPECTRO_REDUX/SPECPROD/exposures/NIGHT/EXPID/sframe-CAMERA-EXPID.html)
- [cframe 数据模型](https://desidatamodel.readthedocs.io/en/latest/DESI_SPECTRO_REDUX/SPECPROD/exposures/NIGHT/EXPID/cframe-CAMERA-EXPID.html)
- 本地原型：`scripts/workflow.sh`
