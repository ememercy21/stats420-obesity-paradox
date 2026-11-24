# Fix: faircause 0.4.0 does not work with xgboost >= 2.
#
# faircause fits its models with an internal function cv_xgb(). It looks for
# the best number of trees in cv$best_iteration, but newer xgboost stores it
# in cv$early_stop$best_iteration, so the fit fails with "argument is of
# length zero". This is the fixed version from the course repository
# (course-ci420/R/helpers/one-step-debiased.R), using 8 CPU threads.
# Source this file after library(faircause).

cv_xgb_fixed <- function(df, y, weights = NULL, ...) {
  dtrain <- xgboost::xgb.DMatrix(data = as.matrix(df), label = y,
                                 weight = weights)

  # logistic model for a 0/1 outcome, otherwise ordinary regression
  binary <- all(y %in% c(0, 1))
  if (binary) {
    params <- list(objective = "binary:logistic", eval_metric = "logloss",
                   nthread = 8)
  } else {
    params <- list(objective = "reg:squarederror", eval_metric = "rmse",
                   nthread = 8)
  }

  # 5-fold cross-validation picks the number of trees (stops when no
  # improvement for 10 rounds)
  cv <- xgboost::xgb.cv(params = params, data = dtrain, nrounds = 1000,
                        nfold = 5, early_stopping_rounds = 10,
                        prediction = TRUE, verbose = FALSE, ...)
  best <- cv$early_stop$best_iteration    # newer xgboost
  if (is.null(best)) best <- cv$best_iteration  # older xgboost

  # final model on all the training data with that number of trees
  xgb <- xgboost::xgb.train(params = params, data = dtrain, nrounds = best,
                            verbose = FALSE, ...)
  attr(xgb, "binary") <- binary
  xgb
}

# replace faircause's version with the fixed one
assignInNamespace("cv_xgb", cv_xgb_fixed, ns = "faircause")
