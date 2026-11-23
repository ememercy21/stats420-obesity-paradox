# Compatibility patch: faircause 0.4.0 with xgboost >= 2.
#
# faircause's internal cv_xgb() reads `cv$best_iteration`, which newer xgboost
# stores under `cv$early_stop$best_iteration`, so xgb.train() fails with
# "argument is of length zero". This replaces it with the fixed version from
# the course repository (course-ci420/R/helpers/one-step-debiased.R), with
# more threads. Source this file after library(faircause).

local({
  cv_xgb_fixed <- function(df, y, weights = NULL, ...) {
    dtrain <- xgboost::xgb.DMatrix(data = as.matrix(df), label = y,
                                   weight = weights)
    binary <- all(y %in% c(0, 1))
    params <- if (binary) {
      list(objective = "binary:logistic", eval_metric = "logloss", nthread = 8)
    } else {
      list(objective = "reg:squarederror", eval_metric = "rmse", nthread = 8)
    }
    cv <- xgboost::xgb.cv(params = params, data = dtrain, nrounds = 1000,
                          nfold = 5, early_stopping_rounds = 10,
                          prediction = TRUE, verbose = FALSE, ...)
    best_iteration <- cv$best_iteration
    if (is.null(best_iteration)) best_iteration <- cv$early_stop$best_iteration
    if (is.null(best_iteration)) best_iteration <- cv$niter
    xgb <- xgboost::xgb.train(params = params, data = dtrain,
                              nrounds = best_iteration, verbose = FALSE, ...)
    attr(xgb, "binary") <- binary
    xgb
  }
  utils::assignInNamespace("cv_xgb", cv_xgb_fixed, ns = "faircause")
})
