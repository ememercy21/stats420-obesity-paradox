# Causal decomposition of the BMI -> mortality association (TV = DE - IE - SE)
# using faircause::fairness_cookbook, following the Lecture 9 vignette
# (course-ci420/R/09-variations.qmd). Run from the project root:
#   Rscript R/03-decomposition.R
#
# Variable roles (specs) are defined in R/specs.R.

suppressPackageStartupMessages({
  library(data.table)
  library(faircause)
  library(ggplot2)
})
source("R/faircause-compat.R")  # faircause 0.4.0 + xgboost >= 2 fix
set.seed(4209)

source("R/specs.R")  # data, X, Y, specs

component_names <- c(
  tv = "Total variation",
  ctfde = "Direct effect",
  ctfie = "Indirect effect (reverse)",
  ctfse = "Spurious effect (reverse)"
)

dir.create("output", showWarnings = FALSE)
results <- list()
for (nm in names(specs)) {
  s <- specs[[nm]]
  cat("\n== Spec:", nm, "| Z =", paste(s$Z, collapse = ", "),
      "| W =", paste(s$W, collapse = ", "), "\n")
  fcb <- fairness_cookbook(
    data = as.data.frame(dat[, c(X, s$Z, s$W, Y), with = FALSE]),
    X = X, Z = s$Z, W = s$W, Y = Y, x0 = 0, x1 = 1
  )
  m <- as.data.table(fcb$measures)[measure %in% names(component_names)]
  m[, `:=`(spec = nm, component = component_names[measure],
           lo = value - 1.96 * sd, hi = value + 1.96 * sd)]
  results[[nm]] <- m[, .(spec, component, estimate = value, sd, lo, hi)]
  print(results[[nm]], digits = 3)

  ggsave(file.path("output", paste0("decomposition-", nm, ".png")),
         autoplot(fcb) + theme_minimal(base_size = 13) +
           labs(title = paste("Decomposition:", nm), x = NULL,
                y = "Mortality difference"),
         width = 8, height = 5)
}

res <- rbindlist(results)
fwrite(res, "output/decomposition.csv")
cat("\nSaved output/decomposition.csv and output/decomposition-*.png\n")
