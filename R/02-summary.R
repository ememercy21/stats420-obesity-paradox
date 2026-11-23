# Aggregate-only overview of the analysis table (safe to share: no row-level
# data is printed). Run from the project root:
#   Rscript R/02-summary.R

suppressPackageStartupMessages(library(data.table))
dat <- as.data.table(arrow::read_parquet("data/obesity-paradox.parquet"))

pct <- function(x) sprintf("%.1f%%", 100 * x)

cat("Rows:", nrow(dat), " (unique", names(dat)[1], ":", uniqueN(dat[[1]]), ")\n\n")

cat("Treatment X_bmi (BMI > 25):", pct(mean(dat$X_bmi)), "\n")
cat("Outcome Y_death:", pct(mean(dat$Y_death)), "\n")
cat("TV = P(Y|X=1) - P(Y|X=0):",
    pct(dat[X_bmi == 1, mean(Y_death)] - dat[X_bmi == 0, mean(Y_death)]), "\n\n")

cat("By treatment group (means):\n")
print(dat[, .(n = .N, death = mean(Y_death), age = mean(Z_age),
              male = mean(Z_sex), charlson = mean(Z_charlson),
              sofa = mean(Z_sofa), bmi = mean(bmi_cont)), by = X_bmi][order(X_bmi)],
      digits = 3)
