# Callback used by the custom MIMIC-IV BMI concept in ../config/concept-dict.json.
# Copied from the original course extraction helpers so this project is
# self-contained.
miiv_omr_bmi_cb <- function(x, ...) {
  x[, result_value := as.numeric(result_value)]
  x[, bmi_omr := mean(result_value, na.rm = TRUE), by = c(id_vars(x))]
  x
}

# Oxygen-therapy concepts used by the Lecture 11 extraction. These definitions
# are project-local copies of the original course callbacks.
oxygen_miiv_cb <- function(...) {
  inputs <- list(...)
  res <- merge(inputs[[1]], inputs[[2]], all = TRUE)
  res <- merge(res, inputs[[3]], all = TRUE)
  res[fio2 > 21, oxy_ind := 1]
  res[!is.na(o2flow), oxy_ind := 1]
  res[o2device != "None", oxy_ind := 1]
  res[o2device == "None", oxy_ind := 0]
  res[, c(meta_vars(res), "oxy_ind"), with = FALSE]
}

oxygen_impute_miiv_cb <- function(oxy_ind, ...) {
  res <- fill_gaps(oxy_ind)
  res[, lag_oxy_ind := oxy_ind]
  for (tlag in seq_len(4)) {
    res[, lag_oxy_ind := data.table::shift(lag_oxy_ind), by = c(id_vars(res))]
    res[is.na(oxy_ind) & !is.na(lag_oxy_ind), oxy_ind := lag_oxy_ind]
  }
  res[, oxy_imp := oxy_ind]
  res[is.na(oxy_imp), oxy_imp := 0]
  res[, c(meta_vars(res), "oxy_imp"), with = FALSE]
}
