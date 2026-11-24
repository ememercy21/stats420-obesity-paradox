# Tests of interaction among the direct, indirect and spurious pathways
# (intertest::inter_test), following the Lecture 9 vignette, section 3.3.
# Run from the project root:
#   Rscript R/04-interactions.R
#
# Why: the decomposition TV = DE - IE - SE uses "reverse" transitions. If the
# outcome mechanism has no term depending jointly on X and W, then
# x-DE_{x0,x1} = -x-DE_{x1,x0} and the reversal does not matter. A non-zero
# DE x IE interaction indicates that it does (Lecture 9, slides 21-22).
#
# Requires: remotes::install_github("dplecko/intertest")
# Variable roles (specs) are defined in R/specs.R.

suppressPackageStartupMessages(library(data.table))
source("R/specs.R")  # data, X, Y, specs
set.seed(4209)

results <- list()
for (nm in names(specs)) {
  s <- specs[[nm]]
  cat("\n== Spec:", nm, "| Z =", paste(s$Z, collapse = ", "),
      "| W =", paste(s$W, collapse = ", "), "\n")
  fit <- intertest::inter_test(
    data = dat[, c(X, s$Z, s$W, Y), with = FALSE],
    X = X, Z = s$Z, W = s$W, Y = Y,
    scale = "difference", nthread = 8
  )
  # keep only the interaction terms (their names contain " x ")
  r <- fit$results
  r <- r[grepl(" x ", r$measure), ]
  results[[nm]] <- data.frame(
    spec = nm,
    interaction = r$measure,
    estimate = r$value,
    sd = r$sd,
    p_value = r$p_value
  )
  print(results[[nm]], digits = 3)
}

res <- do.call(rbind, results)  # stack the three specs into one table
fwrite(res, "output/interactions.csv")
cat("\nSaved output/interactions.csv\n")
