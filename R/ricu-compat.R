# Compatibility patch: ricu 0.6.1 with data.table >= 1.17.
#
# data.table 1.17's merge() calls rbind(..., ignore.attr = TRUE). ricu's
# rbind method for id_tbl/ts_tbl/win_tbl forwards `...` into rbind_lst(), so
# the logical `ignore.attr` is treated as a table to bind and fails with
# "values must be length 1, but FUN(X[[3]]) result is length 0".
# This re-registers the method so that the argument is accepted and ignored.
# Source this file after library(ricu).

local({
  ns <- asNamespace("ricu")
  patched <- function(..., use.names = TRUE, fill = FALSE, idcol = NULL,
                      ignore.attr = FALSE) {
    ricu:::rbind_lst(list(...), use.names = use.names, fill = fill,
                     idcol = idcol)
  }
  for (cls in c("id_tbl", "ts_tbl", "win_tbl")) {
    if (exists(paste0("rbind.", cls), envir = ns, inherits = FALSE)) {
      registerS3method("rbind", cls, patched, envir = ns)
    }
  }
})
