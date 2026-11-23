# One-time conversion of the raw MIMIC-IV 3.1 csv.gz files into ricu's fst
# format. Run from the project root:
#   Rscript R/00-import.R
#
# MIMIC_DIR must point to the folder that contains hosp/ and icu/
# (default: the parent of this project folder).
#
# config/data-sources.json patches ricu 0.6.1's MIMIC-IV 2.2 table spec for
# v3.1 (admissions.ethnicity -> race; a few dropped columns in d_labitems,
# inputevents, procedureevents; two new columns in prescriptions).
# "expected N rows but got M rows" warnings are expected: 3.1 is larger.
# Tables not imported below are also removed from that config, because ricu
# only attaches a source when every configured table is present.

Sys.setenv(RICU_CONFIG_PATH = normalizePath("config"))
library(ricu)

mimic_dir <- normalizePath(Sys.getenv("MIMIC_DIR", ".."))

# Only the tables needed for the concepts used in this project (BMI, age,
# sex, Charlson, SOFA, death, lactate, PaO2/FiO2, AST, admission type).
# Importing everything (incl. emar, poe, pharmacy) is slow and memory-hungry.
tables <- c(
  "patients", "admissions", "icustays", "omr", "diagnoses_icd",
  "d_items", "d_labitems", "services", "transfers",
  "inputevents", "outputevents", "procedureevents", "datetimeevents",
  "labevents", "chartevents"
)
import_src("miiv", data_dir = mimic_dir, tables = tables)
