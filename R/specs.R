# Shared analysis setup: loads the cohort, imputes lab mediators, and defines
# the variable-role specifications (Standard Fairness Model) used by
# R/03-decomposition.R and R/04-interactions.R. Edit roles here only.

dat <- as.data.table(arrow::read_parquet("data/obesity-paradox.parquet"))

# Lab mediators: if a lab was not measured in the first 24h, assume it was
# normal (same idea as the Lecture 9 vignette). About half of each lab is
# missing, so this matters -- see the missingness counts in R/02-eda.R.
dat[is.na(lact_24), lact_24 := 1]     # lactate, mmol/L
dat[is.na(pafi_24), pafi_24 := 400]   # PaO2/FiO2, mmHg
dat[is.na(ast_24), ast_24 := 20]      # AST, U/L

X <- "X_bmi"
Y <- "Y_death"
specs <- list(
  # class DAG: Charlson is a confounder (X <-> Charlson), SOFA a mediator
  main = list(
    Z = c("Z_age", "Z_sex", "Z_charlson"),
    W = c("Z_sofa")
  ),
  # robustness: Charlson treated as (partly) downstream of BMI
  charlson_as_mediator = list(
    Z = c("Z_age", "Z_sex"),
    W = c("Z_charlson", "Z_sofa")
  ),
  # extended mediator set (Lecture 9 variables)
  labs_as_mediators = list(
    Z = c("Z_age", "Z_sex", "Z_charlson"),
    W = c("Z_sofa", "lact_24", "pafi_24", "ast_24")
  )
)
