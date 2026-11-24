# Build the obesity-paradox analysis table from MIMIC-IV 3.1 via ricu.
# Run from the project root after R/00-import.R:
#   Rscript R/01-extract-cohort.R
#
# This reproduces the extraction in the Lecture 4 vignette
# (course-ci420/R/04-est.qmd, `load_op()`), unchanged except for paths.
# Output: data/obesity-paradox.parquet (one row per ICU stay).
#
# Variables (vignette naming):
#   X_bmi      1 if BMI > 25 (BMI from the OMR table; stays with BMI <= 18.5
#              or missing BMI are dropped)
#   Z_sex      1 if male
#   Z_age      age at admission (missing -> 65)
#   Z_charlson Charlson comorbidity index (missing -> 0)
#   Z_sofa     SOFA score, first 24h of ICU stay (missing -> 0)
#   Y_death    in-hospital death (missing -> 0)
# Added beyond the vignette (left NA when unmeasured):
#   lact_24 max lactate, pafi_24 min PaO2/FiO2, ast_24 max AST (first 24h)
#   adm     admission type (med / surg / other)

Sys.setenv(RICU_CONFIG_PATH = normalizePath("config"))
source("R/ricu-helpers.R")
suppressPackageStartupMessages({
  library(ricu)
  library(data.table)
})
# ricu tables print themselves after `:=`, which would dump patient rows into
# the console/log. Turning printing off (and wrapping `:=` lines in
# invisible() below) keeps the output to summary counts only.
options(datatable.print.nrows = 0, datatable.print.topn = 0)
source("R/ricu-compat.R")  # ricu 0.6.1 + data.table >= 1.17 fix

src <- "miiv"
# the imported .fst files live next to the raw data, not in ricu's default
# data folder, so attach the source explicitly
attach_src(src, data_dir = normalizePath(Sys.getenv("MIMIC_DIR", "..")))
out_path <- file.path("data", "obesity-paradox.parquet")

# BMI (kept as continuous for now so the cutoff can be revisited later)
dat <- load_concepts("bmi_omr", src)
dat <- dat[bmi_omr > 18.5]

# baseline covariates
dat <- merge(dat, load_concepts(c("sex", "charlson", "age"), src))
invisible(dat[, sex := as.integer(sex == "Male")])

# SOFA over the first 24h (explicit_wins = hours(12L) evaluates the score at
# hour 12 with ricu's default 24h look-back window, as in the vignette)
sf <- load_concepts("sofa", src, explicit_wins = hours(12L))
invisible(sf[, c(index_var(sf)) := NULL])
dat <- merge(dat, sf, all.x = TRUE)

# outcome
dod <- load_concepts("death", src)
dod <- dod[, c(id_vars(dod), "death"), with = FALSE]
invisible(dod[, death := as.integer(death)])
dat <- merge(dat, dod, all.x = TRUE)

# --- Additional candidate variables (not in the Lecture 4 vignette) --------
# Worst value in the first 24h of the ICU stay, following the variable set of
# the Lecture 9 vignette: max lactate, min PaO2/FiO2, max AST. These are left
# as NA when unmeasured; how to treat them is an analysis decision.
# (charttime is measured in hours since ICU admission)
lact <- as.data.table(load_concepts("lact", src, verbose = FALSE))
lact <- lact[charttime >= 0 & charttime <= 24, .(lact_24 = max(lact)), by = stay_id]

pafi <- as.data.table(load_concepts("pafi", src, verbose = FALSE))
pafi <- pafi[charttime >= 0 & charttime <= 24, .(pafi_24 = min(pafi)), by = stay_id]

ast <- as.data.table(load_concepts("ast", src, verbose = FALSE))
ast <- ast[charttime >= 0 & charttime <= 24, .(ast_24 = max(ast)), by = stay_id]

dat <- merge(dat, as_id_tbl(lact, id_vars = "stay_id"), all.x = TRUE)
dat <- merge(dat, as_id_tbl(pafi, id_vars = "stay_id"), all.x = TRUE)
dat <- merge(dat, as_id_tbl(ast, id_vars = "stay_id"), all.x = TRUE)

# admission type (med / surg / other)
adm <- load_concepts("adm", src, verbose = FALSE)
dat <- merge(dat, adm, all.x = TRUE)

# record missingness before the vignette's simple imputation
miss <- dat[, lapply(.SD, function(v) sum(is.na(v))),
            .SDcols = c("sofa", "charlson", "age", "death",
                        "lact_24", "pafi_24", "ast_24", "adm")]

invisible(dat[is.na(sofa), sofa := 0])
invisible(dat[is.na(charlson), charlson := 0])
invisible(dat[is.na(age), age := 65])
invisible(dat[is.na(death), death := 0])

invisible(dat[, bmi_cont := bmi_omr])
invisible(dat[, X_bmi := as.integer(bmi_omr > 25)])
invisible(dat[, bmi_omr := NULL])
setnames(dat,
  c("death", "sofa", "age", "sex", "charlson"),
  c("Y_death", "Z_sofa", "Z_age", "Z_sex", "Z_charlson")
)

ids <- id_vars(dat)
dat <- as.data.frame(dat)
dir.create("data", showWarnings = FALSE)
arrow::write_parquet(dat, out_path)

cat("ID column:", ids, "\n")
cat("Rows written:", nrow(dat), "->", out_path, "\n")
cat("Missing values imputed (count per variable):\n")
print(miss)
