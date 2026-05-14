#include <stdlib.h>
#include <string.h>
#include <R.h>
#include <Rinternals.h>

/* Forward declarations of Go-exported functions */
extern char *dbc_install(const char *driver_name);
extern char *dbc_search(const char *pattern);

/* R-callable entry point: .Call(C_dbc_install, driver_name_sexp) */
SEXP dbc_install_r(SEXP driver_name_sexp) {
    if (!isString(driver_name_sexp) || length(driver_name_sexp) != 1) {
        error("driver must be a single character string");
    }

    const char *driver = CHAR(STRING_ELT(driver_name_sexp, 0));
    char *errmsg = dbc_install(driver);

    if (errmsg != NULL) {
        char buf[4096];
        strncpy(buf, errmsg, sizeof(buf) - 1);
        buf[sizeof(buf) - 1] = '\0';
        free(errmsg);
        error("%s", buf);
    }

    return R_NilValue;
}

/* R-callable entry point: .Call(C_dbc_search, pattern_sexp) */
SEXP dbc_search_r(SEXP pattern_sexp) {
    if (!isString(pattern_sexp) || length(pattern_sexp) != 1) {
        error("pattern must be a single character string");
    }

    const char *pattern = CHAR(STRING_ELT(pattern_sexp, 0));
    char *result = dbc_search(pattern);

    if (result != NULL && strncmp(result, "ERROR:", 6) == 0) {
        char buf[4096];
        strncpy(buf, result + 6, sizeof(buf) - 1);
        buf[sizeof(buf) - 1] = '\0';
        free(result);
        error("%s", buf);
    }

    SEXP out;
    if (result == NULL || result[0] == '\0') {
        free(result);
        return allocVector(STRSXP, 0);
    }

    /* Split newline-delimited result into a character vector */
    int n = 0;
    for (char *p = result; *p; p++) {
        if (*p == '\n') n++;
    }
    n++; /* last element has no trailing newline */

    PROTECT(out = allocVector(STRSXP, n));
    char *start = result;
    int i = 0;
    for (char *p = result; ; p++) {
        if (*p == '\n' || *p == '\0') {
            int len = (int)(p - start);
            char tmp[4096];
            if (len >= (int)sizeof(tmp)) len = (int)sizeof(tmp) - 1;
            memcpy(tmp, start, len);
            tmp[len] = '\0';
            SET_STRING_ELT(out, i++, mkChar(tmp));
            if (*p == '\0') break;
            start = p + 1;
        }
    }
    UNPROTECT(1);
    free(result);
    return out;
}

/* R registration table */
#include <R_ext/Rdynload.h>

static const R_CallMethodDef call_methods[] = {
    {"dbc_install", (DL_FUNC) &dbc_install_r, 1},
    {"dbc_search",  (DL_FUNC) &dbc_search_r,  1},
    {NULL, NULL, 0}
};

void R_init_dbc(DllInfo *dll) {
    R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
    R_forceSymbols(dll, TRUE);
}
