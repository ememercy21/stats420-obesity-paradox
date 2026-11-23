# Shared analysis setup: loads the cohort, imputes lab mediators, and defines
# the variable-role specifications (Standard Fairness Model) used by
# R/03-decomposition.R and R/04-interactions.R. Edit roles here only.

dat <- as.data.table(arrow::read_parquet("data/obesity-paradox.parquet"))

# Lab mediators: unmeasured values are replaced by normal reference values,
# as in the Lecture 9 vignette. Review these choices (and how many values are
# imputed -- see R/01-extract-cohort.R output) before relying on them.
normal_vals <- c(lact_24 = 1, pafi_24 = 400, ast_24 = 20)
for (v in names(normal_vals)) {
  dat[is.na(get(v)), (v) := normal_vals[[v]]]
}

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
