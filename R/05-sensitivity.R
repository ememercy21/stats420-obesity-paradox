# Sensitivity to unobserved confounding (E-value), following the Lecture 10
# vignette (course-ci420/R/10-sensitivity.qmd), but with logistic regression
# instead of cross-fitted xgboost.
# Run from the project root:
#   Rscript R/05-sensitivity.R

library(data.table)
source("R/specs.R")
set.seed(4209)

evalue <- function(rr) rr + sqrt(rr * (rr - 1))

# --- 1. Total effect of BMI > 25 as a risk ratio ------------------------------
# adjust for the confounders of the main spec (age, sex, Charlson)
risk_ratio <- function(d) {
  fit <- glm(Y_death ~ X_bmi + Z_age + Z_sex + Z_charlson,
             data = d, family = binomial())
  p1 <- predict(fit, newdata = copy(d)[, X_bmi := 1], type = "response")
  p0 <- predict(fit, newdata = copy(d)[, X_bmi := 0], type = "response")
  mean(p1) / mean(p0)
}

rr <- risk_ratio(dat)

rr_boot <- c()
for (b in 1:200) {
  idx <- sample(nrow(dat), replace = TRUE)
  rr_boot <- c(rr_boot, risk_ratio(dat[idx]))
}
ci <- quantile(rr_boot, c(0.025, 0.975))

# RR < 1 (protective), so flip it to use the E-value formula (Lecture 10, Q3)
rr_flip <- 1 / rr
ci_flip <- 1 / ci  # the upper limit of rr is the one closest to 1

cat("Risk ratio (BMI > 25 vs <= 25):", round(rr, 3),
    " 95% CI [", round(ci[1], 3), ",", round(ci[2], 3), "]\n")
cat("E-value (point estimate):", round(evalue(rr_flip), 3), "\n")
cat("E-value (CI limit closest to 1):",
    ifelse(ci[2] >= 1, 1, round(evalue(ci_flip[2]), 3)), "\n\n")

summary_tab <- data.frame(
  rr = rr, rr_lo = ci[1], rr_hi = ci[2],
  evalue = evalue(rr_flip),
  evalue_ci = ifelse(ci[2] >= 1, 1, evalue(ci_flip[2]))
)
write.csv(summary_tab, "output/sensitivity-summary.csv", row.names = FALSE)

# --- 2. Benchmarks: pretend one observed confounder was not measured ----------
# The benchmark formulas need binary confounders, so we use binary versions:
dat[, male := Z_sex]
dat[, old := as.integer(Z_age >= 65)]
dat[, sick := as.integer(Z_charlson >= 3)]
benchmarks <- c("male", "old", "sick")

# outcome model with the binary confounders (used for RR_ZY below)
fit_y <- glm(Y_death ~ X_bmi + male + old + sick,
             data = dat, family = binomial())

bench <- data.frame()
for (zj in benchmarks) {
  others <- setdiff(benchmarks, zj)

  # how strongly is Zj related to BMI?  RR_XZ
  fit_z <- glm(reformulate(c("X_bmi", others), response = zj),
               data = dat, family = binomial())
  q1 <- mean(predict(fit_z, newdata = copy(dat)[, X_bmi := 1], type = "response"))
  q0 <- mean(predict(fit_z, newdata = copy(dat)[, X_bmi := 0], type = "response"))
  rr_xz <- max(q1 / q0, (1 - q1) / (1 - q0))

  # how strongly is Zj related to death?  RR_ZY
  rr_zy <- c()
  for (x in 0:1) {
    d1 <- copy(dat)[, X_bmi := x][, (zj) := 1]
    d0 <- copy(dat)[, X_bmi := x][, (zj) := 0]
    r <- mean(predict(fit_y, d1, type = "response")) /
      mean(predict(fit_y, d0, type = "response"))
    rr_zy <- c(rr_zy, r, 1 / r)
  }
  rr_zy <- max(rr_zy)

  # risk ratio after removing the bias such a confounder could cause
  adjusted <- rr_flip * (rr_xz + rr_zy - 1) / (rr_xz * rr_zy)

  bench <- rbind(bench, data.frame(hidden = zj, rr_xz = round(rr_xz, 3),
                                   rr_zy = round(rr_zy, 3),
                                   adjusted_rr = round(adjusted, 3)))
}

cat("Benchmarks (on the flipped scale; adjusted_rr > 1 means the protective\n")
cat("association would survive a confounder this strong):\n")
print(bench)

write.csv(bench, "output/sensitivity-benchmarks.csv", row.names = FALSE)
