#' @import methods
#' @import DBI
#' @importFrom adbi adbi
#' @importFrom adbcdrivermanager adbc_driver
NULL

# When load_all() sources this package, the namespace isn't initialised yet,
# so DBI generics like dbConnect() aren't in scope for setMethod() calls in
# the driver files.  Attaching DBI here makes the generics available during
# the source pass.
if (identical(environment(), globalenv())) {
  # Running interactively or via source() — do nothing.
} else {
  # Inside load_all(): make DBI generics available in the loading environment.
  requireNamespace("DBI", quietly = FALSE)
  requireNamespace("methods", quietly = FALSE)
  # Import the generic into the current env so setMethod() can find it.
  if (!isGeneric("dbConnect")) {
    importFrom <- methods::getGenerics(where = asNamespace("DBI"))
    for (g in as.character(importFrom)) {
      if (existsMethod(g, where = asNamespace("DBI"))) next
      assign(g, getGeneric(g, where = asNamespace("DBI")),
             envir = parent.env(environment()))
    }
  }
}
