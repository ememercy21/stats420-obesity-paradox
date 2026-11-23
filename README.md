# The ICU Obesity Paradox: Direct, Indirect and Spurious Effects

Course project for STATS 420 (Causal Inference, Fall 2026), Option B2.

In intensive care, patients with a higher body mass index (BMI) tend to die
slightly *less* often than normal-weight patients, even though obesity is a
known risk factor in the general population. This project asks where that
difference comes from: how much of it is a direct effect of BMI, how much runs
through illness severity on ICU admission, and how much is due to differences
in who the patients are.

## Question and approach

- **Treatment** $X$: BMI > 25 (vs. 18.5 < BMI ≤ 25)
- **Outcome** $Y$: in-hospital death
- **Confounders** $Z$: age, sex, Charlson comorbidity index
- **Mediators** $W$: SOFA score in the first 24 hours of the ICU stay
  (extended specification: also worst lactate, PaO₂/FiO₂ and AST)

The observed mortality difference (total variation, TV) is decomposed into
counterfactual direct, indirect and spurious components under the Standard
Fairness Model:

$$\text{TV}_{x_0,x_1}(y) = \text{x-DE}_{x_0,x_1}(y \mid x_0) - \text{x-IE}_{x_1,x_0}(y \mid x_0) - \text{x-SE}_{x_1,x_0}(y)$$

The analysis consists of:

1. **Decomposition** of TV with `faircause` for three variable-role
   specifications: main (Charlson as confounder), Charlson as mediator, and
   lab values added as mediators.
2. **Pathway interaction tests** with `intertest`, to check whether the
   direct and indirect pathways interact.
3. **Sensitivity analysis** for unobserved confounding: E-value for the total
   effect, benchmarked against observed confounders.

## Data

[MIMIC-IV v3.1](https://physionet.org/content/mimiciv/3.1/): de-identified
records of ICU patients at Beth Israel Deaconess Medical Center, Boston.
Access requires PhysioNet credentialing. **No data is included in this
repository.** The analysis cohort contains 53,050 ICU stays with a recorded
BMI (from the `omr` table).

## Repository structure

```
R/
  00-import.R            convert raw MIMIC-IV csv.gz files to ricu format (one-time)
  01-extract-cohort.R    build the analysis table -> data/obesity-paradox.parquet
  02-summary.R           aggregate descriptive overview
  specs.R                variable roles (X, Z, W, Y) for each specification
  03-decomposition.R     TV decomposition (faircause)
  04-interactions.R      pathway interaction tests (intertest)
  05-sensitivity.R       E-value and benchmark confounders
  06-figures-tables.R    LaTeX tables and figures for the report
  ricu-helpers.R         BMI concept callback (from the course repository)
  ricu-compat.R          fix for ricu 0.6.1 with data.table >= 1.17
  faircause-compat.R     fix for faircause 0.4.0 with xgboost >= 2
config/
  data-sources.json      ricu table spec adapted from MIMIC-IV 2.2 to 3.1
  concept-dict.json      BMI concept definition (from the course repository)
report/                  tables (.tex), figures, TikZ DAG, preview.pdf
output/                  decomposition plots
data/                    (not tracked) analysis table
```

## Reproducing the analysis

Requires R (>= 4.3) with `ricu` (0.6.1), `data.table`, `arrow`, `faircause`,
`xgboost`, `ggplot2`, `knitr`, and `intertest`
(`remotes::install_github("dplecko/intertest")`).

Place the MIMIC-IV `hosp/` and `icu/` folders in one directory, then run from
the repository root:

```bash
MIMIC_DIR=/path/to/mimiciv-3.1 Rscript R/00-import.R
MIMIC_DIR=/path/to/mimiciv-3.1 Rscript R/01-extract-cohort.R
Rscript R/02-summary.R
Rscript R/03-decomposition.R
Rscript R/04-interactions.R
Rscript R/05-sensitivity.R
Rscript R/06-figures-tables.R
```

`00-import.R` is slow (about an hour; `chartevents` has ~430M rows) and only
needs to run once. `MIMIC_DIR` defaults to the parent folder of this
repository. To preview all tables and figures: `cd report && pdflatex preview.tex`.

## Acknowledgements

Cohort extraction and analysis follow the STATS 420 course vignettes
(<https://github.com/dplecko/ci420>), in particular Lecture 4 (obesity
paradox), Lecture 9 (variation analysis) and Lecture 10 (sensitivity
analysis). Data loading uses [`ricu`](https://github.com/eth-mds/ricu).
