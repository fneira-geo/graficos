# Project Name: GRAFICOS

## Overview
Process meteorological data from weather stations in Los Ríos Region (Chile). 
Performs EDA, outlier/anomaly detection, and gap filling per WMO standards.

## Architecture & File Structure

R project for analysis and visualization of climatological data from meteorological stations.
ETL flow: Excel read → processing → results write.

```
graficos/
├── data
│   └── BBDD_2026_LOS_RIOS.xlsx      # DB: daily observations + station metadata
│   └── BBDD_ERA5_2026_LOS_RIOS.xlsx # DB: daily observations + station metadata
├── output
├── src
│   ├── plt_heatmap.R  # —
│   ├── plt_ts_anomaly.R  # —
│   ├── utils_carga_BaseMaps.R  # —
│   ├── utils_color.R  # —
│   ├── utils_escribe_climatol.R  # —
│   ├── utils_extrae_CR2Met.R  # —
│   ├── utils_getCR2Met.R  # —
│   └── utils_pivotdata.R  # —
├── .env
├── config.R  # —
├── LICENSE
├── main.py  # —
├── main.R  # —
├── metadata.yaml
├── pyproject.toml
└── README.md
```

**Meteorological variables:** tn (T min), tx (T max), pp (precipitation), rd (radiation), 
hr (humidity), vv (wind), ps (pressure)

**External data (outside repo):**
- CR2MET: daily gridded climate NetCDF 1990-2022 (paths in .env)
- DPA: political-administrative boundary shapefiles (path in .env)

## Development Setup

### R
- RStudio project: `open graficos.Rproj`
- Run pipeline: `Rscript main.R`
- Version: 4.4.3+ (no additional setup required)

### Python (uv - Local Virtual Environment)
```bash
uv venv              # Create local .venv/
uv sync              # Install from requirements.txt
uv add <package>     # Add new dependency
uv run python script.py
```
**Python version:** 3.12 LTS (support until Oct 2028)

**Rules:**
- Install packages ONLY in local environment: `uv add <package>`
- All new/modified libraries must go in requirements.txt
- Never system-wide install without 3+ explicit user confirmations
- Claude Code agents use this environment; do NOT create alternatives

### File I/O Rules
- Read external files: ✅ Allowed
- Write outside project folder: ❌ PROHIBITED (unless explicit user instruction)
- Data in data/: Read-only (inputs)
- Results: output/ (defined in .env)

## Code Conventions & R Script Structure

### Variable Naming & Paths
- Script prefixes: `plt_` = plotting functions | `utils_` = utility helpers | `funcs_` = function libraries
- Meteorological variables: Short codes (tn, tx, pp, rd, hr, vv, ps)
- Paths: NEVER hardcoded → always via .env
- Input: data/ | Output: output/ (defined in .env)
- Encoding: UTF-8 | Indentation: 2 spaces (per graficos.Rproj)

### R Script Sections (Mandatory Structure)

**All R scripts must follow this section order for uniformity and traceability:**

| Order | Section | Description | main.R | utils_*.R | funcs_*.R | plt_*.R |
|---|---|---|---|---|---|
| 1 | `## METADATA` | Header: script name, author (Fernando Neira-Roman), R version, brief description | ✅ | ✅ | ✅ | ✅ |
| 2 | `## SETUP` | Environment cleanup (cat, dev.off, rm, gc) | ✅ | ❌ | ❌ | ❌ |
| 3 | `## ENTORNO` | Load .env, paths (DATA_ENT, DATA_OUT, CUT_REG) | ✅ | ❌ | ❌ | ❌ |
| 4 | `## DEPENDENCIAS` | Library loading (require/library) & source() of other scripts | ✅ | ❌ | ❌ | ❌ |
| 5 | `## FUNCIONES` | Function definitions (auxiliaries or core logic) | ✅ | ✅ | ✅ | ✅ |
| 6 | `## PIPELINE` | Main logic, execution flow (optional if not applicable) | ✅ | ✅ | ✅ | ✅ |
| 7 | `## SALIDA` | Results output: write_xlsx, exports, saved graphics (optional if not applicable) | ✅ | ✅ | ✅ | ✅ |

**Library Management (CRITICAL):**
- ❌ PROHIBITED: Load libraries in utils_*.R, funcs_*.R, or plt_*.R
- ✅ MANDATORY: All libraries loaded in main.R (DEPENDENCIAS section)
- ✅ REQUIRED: Use `package::function()` notation in secondary scripts for traceability

Examples:
```r
# In utils_*.R, funcs_*.R, or plt_*.R
resultado <- dplyr::select(data, col1, col2)
grafico <- ggplot2::ggplot(data, ggplot2::aes(x, y))
climatol::norm.std(data)
```

## Key Commands

| Language | Command | Purpose |
|---|---|---|
| R | `Rscript main.R` | Execute complete ETL pipeline |
| R | `open graficos.Rproj` | Open RStudio project |
| Python | `uv sync` | Install dependencies |
| Python | `uv add <pkg>` | Add package to requirements.txt |
| Python | `uv run python script.py` | Run Python script |

## Author & Attribution
- **Original code & architecture:** Fernando Neira-Roman
- **Refactoring & code organization:** Claude (AI assistant)
- All scripts maintain original logic; formatting/structure follows project standards

## Important Notes
- Regional project: Los Ríos Region, Chile (CUT_REG=10)
- utils_pivotdata.R: pending implementation (stub)
- ASDF.xlsx output: provisional naming
- src/ folder: utility & plotting scripts now in root (folder may be deprecated)

## Out of Scope
- No system package installation without explicit user confirmation
- No writes outside project folder (unless explicit instruction)
- data/ is read-only — treat as inputs
- No remote pushes without direct user instruction
