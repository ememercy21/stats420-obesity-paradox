# Exploratory data analysis of the cohort table.
# Run from the project root (or step through it line by line in RStudio):
#   Rscript R/02-eda.R
#
# NOTE: head() and str() print individual patients' rows. That is fine on your
# own computer, but don't paste that output into the report, GitHub, or any
# online/AI tool: the MIMIC data use agreement doesn't allow sharing row-level
# data. Everything after section 1 prints only counts, means and percentages.

library(data.table)
library(ggplot2)

dat <- as.data.table(arrow::read_parquet("data/obesity-paradox.parquet"))
dir.create("output", showWarnings = FALSE)

# --- 1. First look at the table ----------------------------------------------
print(head(dat))
str(dat)
print(summary(dat))

# one row per ICU stay?
cat("\nRows:", nrow(dat), "| unique stay_id:", uniqueN(dat$stay_id), "\n")

# --- 2. Missing values --------------------------------------------------------
# age/sex/Charlson/SOFA/death were already filled in during extraction; the
# labs are still NA when they weren't measured in the first 24h
cat("\nMissing values per column:\n")
print(colSums(is.na(dat)))
cat("\nShare missing (labs):\n")
print(round(colMeans(is.na(dat[, .(lact_24, pafi_24, ast_24)])), 3))

# are labs missing more often in one BMI group?
cat("\nShare of lactate measured, by BMI group:\n")
print(dat[, .(lactate_measured = mean(!is.na(lact_24))), by = X_bmi])

# --- 3. Treatment and outcome -------------------------------------------------
cat("\nBMI > 25 (X = 1) vs BMI <= 25 (X = 0):\n")
print(table(dat$X_bmi))
print(round(prop.table(table(dat$X_bmi)), 3))

cat("\nIn-hospital mortality by BMI group:\n")
mort <- dat[, .(n = .N, deaths = sum(Y_death), mortality = mean(Y_death)),
            by = X_bmi]
print(mort[order(X_bmi)])

# the raw difference we are trying to explain (TV)
tv <- mort[X_bmi == 1, mortality] - mort[X_bmi == 0, mortality]
cat("TV = P(death | BMI > 25) - P(death | BMI <= 25) =", round(100 * tv, 2),
    "percentage points\n")

# --- 4. Are the two groups different in other ways? ---------------------------
# if the groups differ in age, sex or illness, the raw TV mixes those in too
cat("\nMeans by BMI group:\n")
print(dat[, .(age = mean(Z_age), male = mean(Z_sex),
              charlson = mean(Z_charlson), sofa = mean(Z_sofa),
              bmi = median(bmi_cont)), by = X_bmi][order(X_bmi)], digits = 3)

cat("\nAdmission type by BMI group (row %):\n")
print(round(prop.table(table(dat$X_bmi, dat$adm), 1), 3))

# does mortality go up with SOFA, as expected?
cat("\nMortality by SOFA score (first 24h):\n")
dat[, sofa_group := cut(Z_sofa, c(-Inf, 2, 5, 8, 11, Inf),
                        labels = c("0-2", "3-5", "6-8", "9-11", "12+"))]
print(dat[, .(n = .N, mortality = round(mean(Y_death), 3)),
          by = sofa_group][order(sofa_group)])

# --- 5. Plots -----------------------------------------------------------------
# BMI distribution (a few BMI values above 60 are cut off; some are likely
# data-entry errors, but they all count as BMI > 25 either way)
p1 <- ggplot(dat[bmi_cont <= 60], aes(x = bmi_cont)) +
  geom_histogram(binwidth = 1, fill = "grey60", colour = "white") +
  geom_vline(xintercept = 25, linetype = "dashed") +
  labs(x = "BMI", y = "Number of ICU stays",
       title = "BMI distribution (dashed line = cutoff of 25)") +
  theme_bw()
ggsave("output/eda-bmi-histogram.png", p1, width = 6, height = 4)

# mortality across finer BMI categories: is it really a "paradox"?
dat[, bmi_group := cut(bmi_cont, c(18.5, 25, 30, 35, 40, Inf),
                       labels = c("18.5-25", "25-30", "30-35", "35-40", "40+"))]
by_bmi <- dat[, .(n = .N, mortality = mean(Y_death)), by = bmi_group]
print(by_bmi[order(bmi_group)])

p2 <- ggplot(by_bmi, aes(x = bmi_group, y = 100 * mortality)) +
  geom_col(fill = "grey60") +
  geom_text(aes(label = paste0("n=", n)), vjust = -0.5, size = 3) +
  labs(x = "BMI category", y = "In-hospital mortality (%)",
       title = "Mortality by BMI category") +
  theme_bw()
ggsave("output/eda-mortality-by-bmi.png", p2, width = 6, height = 4)

# SOFA (the mediator) by BMI group
sofa_tab <- dat[, .N, by = .(X_bmi, sofa_group)]
sofa_tab[, share := N / sum(N), by = X_bmi]
p3 <- ggplot(sofa_tab, aes(x = sofa_group, y = share,
                           fill = factor(X_bmi, labels = c("BMI <= 25", "BMI > 25")))) +
  geom_col(position = "dodge") +
  labs(x = "SOFA score (first 24h)", y = "Share of stays", fill = NULL,
       title = "Illness severity by BMI group") +
  theme_bw()
ggsave("output/eda-sofa-by-bmi.png", p3, width = 6, height = 4)

cat("\nSaved plots to output/eda-*.png\n")
