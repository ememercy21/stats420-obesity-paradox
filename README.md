# STATS 420 Project (Option B2): Obesity Paradox Mechanisms

Causal decomposition of the effect of elevated BMI on ICU in-hospital mortality
using MIMIC-IV 3.1.

## Data access

MIMIC-IV is credentialed data from PhysioNet
(<https://physionet.org/content/mimiciv/3.1/>). No data is included in this
repository. To reproduce, obtain access and place the `hosp/` and `icu/`
folders in one directory.

## Setup

Requires R (>= 4.3) with `ricu` (0.6.1), `data.table`, `arrow`, `faircause`,
`xgboost`.

```bash
MIMIC_DIR=/path/to/mimiciv-3.1 Rscript R/00-import.R   # one-time, slow
Rscript R/01-extract-cohort.R                          # -> data/obesity-paradox.parquet
Rscript R/02-summary.R                                 # aggregate overview
Rscript R/03-decomposition.R                           # TV = DE - IE - SE (faircause)
Rscript R/04-interactions.R                            # pathway interaction tests (intertest)
Rscript R/05-sensitivity.R                             # E-value + benchmarks
Rscript R/06-figures-tables.R                          # report/ tables (.tex) and figures
```

`report/preview.tex` compiles all figures and tables (`cd report && pdflatex preview.tex`);
`report/dag.tex` is the DAG figure in TikZ.

Variable roles for 03 and 04 are set in `R/specs.R`. `R/ricu-compat.R` and
`R/faircause-compat.R` are small fixes for newer `data.table` / `xgboost`
versions. `intertest` is installed with
`remotes::install_github("dplecko/intertest")`.

`config/data-sources.json` adapts ricu's MIMIC-IV 2.2 table spec to v3.1.
`config/concept-dict.json` and `R/ricu-helpers.R` are from the course
repository (<https://github.com/dplecko/ci420>) and define the `bmi_omr`
concept.
