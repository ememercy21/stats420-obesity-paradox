# Fix: ricu 0.6.1 does not work with data.table >= 1.17.
#
# Newer data.table passes an extra argument (ignore.attr) to rbind() when it
# merges tables. ricu's rbind for its own table types doesn't expect it, and
# the SOFA concept fails with "values must be length 1, but FUN(X[[3]])
# result is length 0". The version below accepts ignore.attr and ignores it.
# Source this file after library(ricu).

rbind_fixed <- function(..., use.names = TRUE, fill = FALSE, idcol = NULL,
                        ignore.attr = FALSE) {
  ricu:::rbind_lst(list(...), use.names = use.names, fill = fill,
                   idcol = idcol)
}

# use it for ricu's two table types
registerS3method("rbind", "id_tbl", rbind_fixed, envir = asNamespace("ricu"))
registerS3method("rbind", "ts_tbl", rbind_fixed, envir = asNamespace("ricu"))
