#include <stdlib.h>
#include <string.h>
#include <R.h>
#include <Rinternals.h>

/* Forward declarations of Go-exported functions */
extern char *dbc_install(const char *driver_name);
extern char *dbc_search(const char *pattern);
extern char *dbc_uninstall(const char *driver_name);
extern char *dbc_list(void);
extern char *dbc_info(const char *driver_name);

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

/* R-callable entry point: .Call(C_dbc_uninstall, driver_name_sexp) */
SEXP dbc_uninstall_r(SEXP driver_name_sexp) {
    if (!isString(driver_name_sexp) || length(driver_name_sexp) != 1) {
        error("driver must be a single character string");
    }
    const char *driver = CHAR(STRING_ELT(driver_name_sexp, 0));
    char *errmsg = dbc_uninstall(driver);
    if (errmsg != NULL) {
        char buf[4096];
        strncpy(buf, errmsg, sizeof(buf) - 1);
        buf[sizeof(buf) - 1] = '\0';
        free(errmsg);
        error("%s", buf);
    }
    return R_NilValue;
}

/* R-callable entry point: .Call(C_dbc_list) */
/* Returns a data.frame with columns: id, name, version, level, path */
SEXP dbc_list_r(void) {
    char *result = dbc_list();

    /* Count rows */
    int n = 0;
    if (result != NULL && result[0] != '\0') {
        n = 1;
        for (char *p = result; *p; p++) {
            if (*p == '\n') n++;
        }
    }

    SEXP id_col      = PROTECT(allocVector(STRSXP, n));
    SEXP name_col    = PROTECT(allocVector(STRSXP, n));
    SEXP version_col = PROTECT(allocVector(STRSXP, n));
    SEXP level_col   = PROTECT(allocVector(STRSXP, n));
    SEXP path_col    = PROTECT(allocVector(STRSXP, n));

    if (n > 0) {
        char *line = result;
        for (int i = 0; i < n; i++) {
            char *nl = strchr(line, '\n');
            if (nl) *nl = '\0';

            /* Split on tabs: id, name, version, level, path */
            char *fields[5];
            char *p = line;
            for (int f = 0; f < 5; f++) {
                fields[f] = p;
                char *tab = strchr(p, '\t');
                if (tab) { *tab = '\0'; p = tab + 1; }
            }
            SET_STRING_ELT(id_col,      i, mkChar(fields[0]));
            SET_STRING_ELT(name_col,    i, mkChar(fields[1]));
            SET_STRING_ELT(version_col, i, mkChar(fields[2]));
            SET_STRING_ELT(level_col,   i, mkChar(fields[3]));
            SET_STRING_ELT(path_col,    i, mkChar(fields[4]));

            if (nl) line = nl + 1;
        }
    }
    free(result);

    /* Build data.frame */
    SEXP df = PROTECT(allocVector(VECSXP, 5));
    SET_VECTOR_ELT(df, 0, id_col);
    SET_VECTOR_ELT(df, 1, name_col);
    SET_VECTOR_ELT(df, 2, version_col);
    SET_VECTOR_ELT(df, 3, level_col);
    SET_VECTOR_ELT(df, 4, path_col);

    SEXP colnames = PROTECT(allocVector(STRSXP, 5));
    SET_STRING_ELT(colnames, 0, mkChar("id"));
    SET_STRING_ELT(colnames, 1, mkChar("name"));
    SET_STRING_ELT(colnames, 2, mkChar("version"));
    SET_STRING_ELT(colnames, 3, mkChar("level"));
    SET_STRING_ELT(colnames, 4, mkChar("path"));
    setAttrib(df, R_NamesSymbol, colnames);

    SEXP rownames = PROTECT(allocVector(INTSXP, 2));
    INTEGER(rownames)[0] = NA_INTEGER;
    INTEGER(rownames)[1] = -n;
    setAttrib(df, R_RowNamesSymbol, rownames);

    SEXP cls = PROTECT(allocVector(STRSXP, 1));
    SET_STRING_ELT(cls, 0, mkChar("data.frame"));
    setAttrib(df, R_ClassSymbol, cls);

    UNPROTECT(9);
    return df;
}

/* R-callable entry point: .Call(C_dbc_info, driver_name_sexp) */
/* Returns a named list: path, title, version, license, description, platforms */
SEXP dbc_info_r(SEXP driver_name_sexp) {
    if (!isString(driver_name_sexp) || length(driver_name_sexp) != 1) {
        error("driver must be a single character string");
    }
    const char *driver = CHAR(STRING_ELT(driver_name_sexp, 0));
    char *result = dbc_info(driver);

    if (result != NULL && strncmp(result, "ERROR:", 6) == 0) {
        char buf[4096];
        strncpy(buf, result + 6, sizeof(buf) - 1);
        buf[sizeof(buf) - 1] = '\0';
        free(result);
        error("%s", buf);
    }

    /* Split tab-delimited: path, title, version, license, description, platforms */
    char *fields[6] = {"", "", "", "", "", ""};
    if (result != NULL) {
        char *p = result;
        for (int f = 0; f < 6; f++) {
            fields[f] = p;
            char *tab = strchr(p, '\t');
            if (tab) { *tab = '\0'; p = tab + 1; } else break;
        }
    }

    /* platforms: split comma-separated into character vector */
    int np = 0;
    char platforms_copy[4096];
    strncpy(platforms_copy, fields[5], sizeof(platforms_copy) - 1);
    platforms_copy[sizeof(platforms_copy) - 1] = '\0';
    if (platforms_copy[0] != '\0') {
        np = 1;
        for (char *q = platforms_copy; *q; q++) if (*q == ',') np++;
    }
    SEXP plat_vec = PROTECT(allocVector(STRSXP, np));
    if (np > 0) {
        char *tok = strtok(platforms_copy, ",");
        for (int i = 0; tok != NULL && i < np; i++, tok = strtok(NULL, ",")) {
            SET_STRING_ELT(plat_vec, i, mkChar(tok));
        }
    }

    SEXP out = PROTECT(allocVector(VECSXP, 6));
    SET_VECTOR_ELT(out, 0, mkString(fields[0]));
    SET_VECTOR_ELT(out, 1, mkString(fields[1]));
    SET_VECTOR_ELT(out, 2, mkString(fields[2]));
    SET_VECTOR_ELT(out, 3, mkString(fields[3]));
    SET_VECTOR_ELT(out, 4, mkString(fields[4]));
    SET_VECTOR_ELT(out, 5, plat_vec);
    free(result);

    SEXP nms = PROTECT(allocVector(STRSXP, 6));
    SET_STRING_ELT(nms, 0, mkChar("path"));
    SET_STRING_ELT(nms, 1, mkChar("title"));
    SET_STRING_ELT(nms, 2, mkChar("version"));
    SET_STRING_ELT(nms, 3, mkChar("license"));
    SET_STRING_ELT(nms, 4, mkChar("description"));
    SET_STRING_ELT(nms, 5, mkChar("platforms"));
    setAttrib(out, R_NamesSymbol, nms);

    UNPROTECT(3);
    return out;
}

/* R registration table */
#include <R_ext/Rdynload.h>

static const R_CallMethodDef call_methods[] = {
    {"dbc_install_c",      (DL_FUNC) &dbc_install_r,      1},
    {"dbc_search_c",       (DL_FUNC) &dbc_search_r,       1},
    {"dbc_uninstall_c",    (DL_FUNC) &dbc_uninstall_r,    1},
    {"dbc_list_c", (DL_FUNC) &dbc_list_r, 0},
    {"dbc_info_c",         (DL_FUNC) &dbc_info_r,         1},
    {NULL, NULL, 0}
};

void R_init_dbc(DllInfo *dll) {
    R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
    R_forceSymbols(dll, TRUE);
}
