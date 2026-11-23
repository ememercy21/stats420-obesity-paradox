# Figures and LaTeX tables for the report. Run from the project root after
# scripts 01-05:
#   Rscript R/06-figures-tables.R
# Output goes to report/ (tables as .tex, figures as .pdf).

library(data.table)
library(ggplot2)
library(knitr)

dir.create("report", showWarnings = FALSE)
dat <- as.data.table(arrow::read_parquet("data/obesity-paradox.parquet"))

pct <- function(x, d = 1) sprintf(paste0("%.", d, "f\\%%"), 100 * x)
mean_sd <- function(x) sprintf("%.1f (%.1f)", mean(x), sd(x))
med_iqr <- function(x, d = 1) {
  x <- x[!is.na(x)]
  q <- formatC(quantile(x, c(0.25, 0.5, 0.75)), format = "f", digits = d)
  paste0(q[2], " [", q[1], ", ", q[3], "]")
}
save_tex <- function(tab, file, caption, label, align = NULL) {
  tex <- kable(tab, format = "latex", booktabs = TRUE, escape = FALSE,
               caption = caption, label = label, align = align,
               row.names = FALSE, linesep = "")
  writeLines(tex, file.path("report", file))
}

# --- Table 1: cohort characteristics by BMI group ---------------------------
describe <- function(d) {
  c(
    "Stays, n"                      = format(nrow(d), big.mark = ","),
    "BMI, median [IQR]"             = med_iqr(d$bmi_cont),
    "Age, mean (SD)"                = mean_sd(d$Z_age),
    "Male"                          = pct(mean(d$Z_sex)),
    "Charlson index, mean (SD)"     = mean_sd(d$Z_charlson),
    "SOFA (first 24h), mean (SD)"   = mean_sd(d$Z_sofa),
    "Lactate, median [IQR]$^a$"     = med_iqr(d$lact_24),
    "PaO$_2$/FiO$_2$, median [IQR]$^a$" = med_iqr(d$pafi_24, 0),
    "AST, median [IQR]$^a$"         = med_iqr(d$ast_24, 0),
    "Lactate measured"              = pct(mean(!is.na(d$lact_24))),
    "PaO$_2$/FiO$_2$ measured"      = pct(mean(!is.na(d$pafi_24))),
    "AST measured"                  = pct(mean(!is.na(d$ast_24))),
    "In-hospital death"             = pct(mean(d$Y_death))
  )
}
t1 <- data.frame(
  Variable = names(describe(dat)),
  `BMI $\\le$ 25` = describe(dat[X_bmi == 0]),
  `BMI $>$ 25` = describe(dat[X_bmi == 1]),
  All = describe(dat),
  check.names = FALSE
)
save_tex(t1, "table1-cohort.tex",
         "Cohort characteristics by BMI group. $^a$Among stays where measured.",
         "cohort", align = "lccc")

# --- Figure 2 and Table 2: decomposition ------------------------------------
dec <- fread("output/decomposition.csv")
labels <- c("Total variation" = "TV",
            "Direct effect" = "x-DE",
            "Indirect effect (reverse)" = "x-IE (rev.)",
            "Spurious effect (reverse)" = "x-SE (rev.)")
dec[, measure := factor(labels[component], levels = labels)]

main <- dec[spec == "main"]
p <- ggplot(main, aes(x = measure, y = 100 * estimate)) +
  geom_hline(yintercept = 0, colour = "grey50") +
  geom_col(fill = "grey70", width = 0.6) +
  geom_errorbar(aes(ymin = 100 * lo, ymax = 100 * hi), width = 0.2) +
  labs(x = NULL, y = "Difference in mortality (percentage points)") +
  theme_bw(base_size = 12)
ggsave("report/fig-decomposition.pdf", p, width = 6, height = 3.5)

spec_names <- c(main = "Main (Charlson in $Z$)",
                charlson_as_mediator = "Charlson in $W$",
                labs_as_mediators = "Labs added to $W$")
dec[, cell := sprintf("%.2f [%.2f, %.2f]", 100 * estimate, 100 * lo, 100 * hi)]
t2 <- dcast(dec, measure ~ spec, value.var = "cell")
t2 <- t2[, c("measure", names(spec_names)), with = FALSE]
setnames(t2, c("Measure", spec_names))
save_tex(t2, "table2-decomposition.tex",
         paste("Decomposition of the total variation (percentage points,",
               "95\\% CI). TV = x-DE $-$ x-IE $-$ x-SE."),
         "decomposition", align = "lccc")

# --- Table 3: interaction tests ---------------------------------------------
int <- fread("output/interactions.csv")
int[, cell := sprintf("%.2f (%.3f)", 100 * estimate, p_value)]
t3 <- dcast(int, interaction ~ spec, value.var = "cell")
t3 <- t3[match(c("DE x IE", "DE x SE", "IE x SE", "TE x SE", "DE x IE x SE"),
               interaction)]
t3[, interaction := gsub(" x ", " $\\times$ ", interaction, fixed = TRUE)]
t3 <- t3[, c("interaction", names(spec_names)), with = FALSE]
setnames(t3, c("Interaction", spec_names))
save_tex(t3, "table3-interactions.tex",
         "Tests of pathway interactions: estimate in percentage points (p-value).",
         "interactions", align = "lccc")

# --- Table 4: sensitivity ---------------------------------------------------
sens <- read.csv("output/sensitivity-summary.csv")
bench <- read.csv("output/sensitivity-benchmarks.csv")
t4 <- data.frame(
  `Hidden confounder as strong as` = c("Male sex", "Age $\\ge$ 65",
                                       "Charlson $\\ge$ 3"),
  `RR$_{XZ}$` = sprintf("%.2f", bench$rr_xz),
  `RR$_{ZY}$` = sprintf("%.2f", bench$rr_zy),
  `Adjusted RR (flipped)` = sprintf("%.2f", bench$adjusted_rr),
  check.names = FALSE
)
cap4 <- sprintf(paste(
  "Sensitivity to unobserved confounding. Adjusted risk ratio of death",
  "(BMI $>$ 25 vs.\\ $\\le$ 25): %.2f [%.2f, %.2f]; E-value %.2f (CI limit: %.2f).",
  "Benchmarks remove the bias a confounder as strong as each observed",
  "covariate could induce, on the flipped scale (values $>$ 1: association remains)."),
  sens$rr, sens$rr_lo, sens$rr_hi, sens$evalue, sens$evalue_ci)
save_tex(t4, "table4-sensitivity.tex", cap4, "sensitivity", align = "lccc")

cat("Saved tables and figures to report/\n")
