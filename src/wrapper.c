#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <R.h>
#include <Rinternals.h>
#include <cli/progress.h>

/* Forward declarations of Go-exported functions (updated signatures) */
extern char *dbc_install(char *driver_name, char *level, int no_verify, int pre);
extern char *dbc_install_progress(char *driver_name, char *level, int no_verify, int pre, void (*cb)(int64_t, int64_t));
extern char *dbc_search(char *pattern, int pre);
extern char *dbc_uninstall(char *driver_name, char *level);
extern char *dbc_list(void);
extern char *dbc_info(char *driver_name);
extern char *dbc_init(char *path);
extern char *dbc_add(char *drivers, char *path, int pre);
extern char *dbc_remove(char *driver_name, char *path);
extern char *dbc_sync(char *path, char *level, int no_verify);
extern char *dbc_docs(char *driver_name);
extern char *dbc_auth_login(char *registry_url, char *api_key, char *client_id);
extern char *dbc_auth_logout(char *registry_url, int purge);

/* ---------------------------------------------------------------------------
 * Progress bar support using cli C API
 * --------------------------------------------------------------------------- */

/* Global progress bar state used during install. */
static SEXP g_progress_bar = NULL;
static int g_progress_bar_created = 0;
static const char *g_progress_driver_name = NULL;

/* Callback invoked by Go during download. Called on the R main thread. */
static void install_progress_callback(int64_t written, int64_t total) {
    /* Lazily create the progress bar on first callback so we know the total */
    if (!g_progress_bar_created) {
        double bar_total = (total > 0) ? (double)total : NA_REAL;

        /* Build config: name, type, show_after=0 so bar appears immediately */
        SEXP cfg = PROTECT(allocVector(VECSXP, 3));
        SEXP cfg_nms = PROTECT(allocVector(STRSXP, 3));
        SET_STRING_ELT(cfg_nms, 0, mkChar("name"));
        SET_STRING_ELT(cfg_nms, 1, mkChar("type"));
        SET_STRING_ELT(cfg_nms, 2, mkChar("show_after"));
        setAttrib(cfg, R_NamesSymbol, cfg_nms);
        SET_VECTOR_ELT(cfg, 0, mkString(g_progress_driver_name));
        SET_VECTOR_ELT(cfg, 1, mkString("download"));
        SET_VECTOR_ELT(cfg, 2, ScalarReal(0));

        g_progress_bar = cli_progress_bar(bar_total, cfg);
        R_PreserveObject(g_progress_bar);
        UNPROTECT(2);
        g_progress_bar_created = 1;
    }

    if (g_progress_bar == NULL) return;

    if (CLI_SHOULD_TICK) {
        cli_progress_set(g_progress_bar, (double)written);
    }
}

/* ---------------------------------------------------------------------------
 * R-callable: .Call(C_dbc_install, driver, level, no_verify, pre)
 * Now with progress bar!
 * --------------------------------------------------------------------------- */
SEXP dbc_install_r(SEXP driver_sexp, SEXP level_sexp, SEXP no_verify_sexp, SEXP pre_sexp) {
    if (!isString(driver_sexp) || length(driver_sexp) != 1)
        error("driver must be a single character string");

    const char *driver = CHAR(STRING_ELT(driver_sexp, 0));
    const char *level = "";
    int no_verify = 0;
    int pre = 0;

    if (!isNull(level_sexp) && isString(level_sexp) && length(level_sexp) == 1)
        level = CHAR(STRING_ELT(level_sexp, 0));
    if (!isNull(no_verify_sexp) && isLogical(no_verify_sexp) && length(no_verify_sexp) == 1)
        no_verify = LOGICAL(no_verify_sexp)[0];
    if (!isNull(pre_sexp) && isLogical(pre_sexp) && length(pre_sexp) == 1)
        pre = LOGICAL(pre_sexp)[0];

    /* Initialize progress bar state (lazily created in callback) */
    g_progress_bar = NULL;
    g_progress_bar_created = 0;
    g_progress_driver_name = driver;
    cli_progress_init_timer();

    char *errmsg = dbc_install_progress((char *)driver, (char *)level, no_verify, pre,
                                         install_progress_callback);

    /* Done with progress bar */
    if (g_progress_bar_created && g_progress_bar != NULL) {
        cli_progress_done(g_progress_bar);
        R_ReleaseObject(g_progress_bar);
    }
    g_progress_bar = NULL;
    g_progress_bar_created = 0;
    g_progress_driver_name = NULL;

    if (errmsg != NULL) {
        char buf[4096];
        strncpy(buf, errmsg, sizeof(buf) - 1);
        buf[sizeof(buf) - 1] = '\0';
        free(errmsg);
        error("%s", buf);
    }

    return R_NilValue;
}

/* ---------------------------------------------------------------------------
 * R-callable: .Call(C_dbc_search, pattern, pre)
 * --------------------------------------------------------------------------- */
SEXP dbc_search_r(SEXP pattern_sexp, SEXP pre_sexp) {
    if (!isString(pattern_sexp) || length(pattern_sexp) != 1)
        error("pattern must be a single character string");

    const char *pattern = CHAR(STRING_ELT(pattern_sexp, 0));
    int pre = 0;
    if (!isNull(pre_sexp) && isLogical(pre_sexp) && length(pre_sexp) == 1)
        pre = LOGICAL(pre_sexp)[0];

    char *result = dbc_search((char *)pattern, pre);

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
    n++;

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

/* ---------------------------------------------------------------------------
 * R-callable: .Call(C_dbc_uninstall, driver, level)
 * --------------------------------------------------------------------------- */
SEXP dbc_uninstall_r(SEXP driver_sexp, SEXP level_sexp) {
    if (!isString(driver_sexp) || length(driver_sexp) != 1)
        error("driver must be a single character string");

    const char *driver = CHAR(STRING_ELT(driver_sexp, 0));
    const char *level = "";
    if (!isNull(level_sexp) && isString(level_sexp) && length(level_sexp) == 1)
        level = CHAR(STRING_ELT(level_sexp, 0));

    char *errmsg = dbc_uninstall((char *)driver, (char *)level);
    if (errmsg != NULL) {
        char buf[4096];
        strncpy(buf, errmsg, sizeof(buf) - 1);
        buf[sizeof(buf) - 1] = '\0';
        free(errmsg);
        error("%s", buf);
    }
    return R_NilValue;
}

/* ---------------------------------------------------------------------------
 * R-callable: .Call(C_dbc_list)
 * --------------------------------------------------------------------------- */
SEXP dbc_list_r(void) {
    char *result = dbc_list();

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

/* ---------------------------------------------------------------------------
 * R-callable: .Call(C_dbc_info, driver)
 * --------------------------------------------------------------------------- */
SEXP dbc_info_r(SEXP driver_sexp) {
    if (!isString(driver_sexp) || length(driver_sexp) != 1)
        error("driver must be a single character string");

    const char *driver = CHAR(STRING_ELT(driver_sexp, 0));
    char *result = dbc_info((char *)driver);

    if (result != NULL && strncmp(result, "ERROR:", 6) == 0) {
        char buf[4096];
        strncpy(buf, result + 6, sizeof(buf) - 1);
        buf[sizeof(buf) - 1] = '\0';
        free(result);
        error("%s", buf);
    }

    char *fields[6] = {"", "", "", "", "", ""};
    if (result != NULL) {
        char *p = result;
        for (int f = 0; f < 6; f++) {
            fields[f] = p;
            char *tab = strchr(p, '\t');
            if (tab) { *tab = '\0'; p = tab + 1; } else break;
        }
    }

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

/* ---------------------------------------------------------------------------
 * R-callable: .Call(C_dbc_init, path)
 * --------------------------------------------------------------------------- */
SEXP dbc_init_r(SEXP path_sexp) {
    const char *path = "./dbc.toml";
    if (!isNull(path_sexp) && isString(path_sexp) && length(path_sexp) == 1)
        path = CHAR(STRING_ELT(path_sexp, 0));

    char *errmsg = dbc_init((char *)path);
    if (errmsg != NULL) {
        char buf[4096];
        strncpy(buf, errmsg, sizeof(buf) - 1);
        buf[sizeof(buf) - 1] = '\0';
        free(errmsg);
        error("%s", buf);
    }
    return R_NilValue;
}

/* ---------------------------------------------------------------------------
 * R-callable: .Call(C_dbc_add, drivers, path, pre)
 * --------------------------------------------------------------------------- */
SEXP dbc_add_r(SEXP drivers_sexp, SEXP path_sexp, SEXP pre_sexp) {
    if (!isString(drivers_sexp) || length(drivers_sexp) < 1)
        error("drivers must be a character vector");

    /* Join driver names with newlines for Go */
    int ndrv = length(drivers_sexp);
    int total_len = 0;
    for (int i = 0; i < ndrv; i++)
        total_len += strlen(CHAR(STRING_ELT(drivers_sexp, i))) + 1;

    char *joined = (char *)malloc(total_len + 1);
    if (!joined) error("memory allocation failed");
    joined[0] = '\0';
    for (int i = 0; i < ndrv; i++) {
        if (i > 0) strcat(joined, "\n");
        strcat(joined, CHAR(STRING_ELT(drivers_sexp, i)));
    }

    const char *path = "./dbc.toml";
    if (!isNull(path_sexp) && isString(path_sexp) && length(path_sexp) == 1)
        path = CHAR(STRING_ELT(path_sexp, 0));

    int pre = 0;
    if (!isNull(pre_sexp) && isLogical(pre_sexp) && length(pre_sexp) == 1)
        pre = LOGICAL(pre_sexp)[0];

    char *errmsg = dbc_add(joined, (char *)path, pre);
    free(joined);

    if (errmsg != NULL) {
        char buf[4096];
        strncpy(buf, errmsg, sizeof(buf) - 1);
        buf[sizeof(buf) - 1] = '\0';
        free(errmsg);
        error("%s", buf);
    }
    return R_NilValue;
}

/* ---------------------------------------------------------------------------
 * R-callable: .Call(C_dbc_remove, driver, path)
 * --------------------------------------------------------------------------- */
SEXP dbc_remove_r(SEXP driver_sexp, SEXP path_sexp) {
    if (!isString(driver_sexp) || length(driver_sexp) != 1)
        error("driver must be a single character string");

    const char *driver = CHAR(STRING_ELT(driver_sexp, 0));
    const char *path = "./dbc.toml";
    if (!isNull(path_sexp) && isString(path_sexp) && length(path_sexp) == 1)
        path = CHAR(STRING_ELT(path_sexp, 0));

    char *errmsg = dbc_remove((char *)driver, (char *)path);
    if (errmsg != NULL) {
        char buf[4096];
        strncpy(buf, errmsg, sizeof(buf) - 1);
        buf[sizeof(buf) - 1] = '\0';
        free(errmsg);
        error("%s", buf);
    }
    return R_NilValue;
}

/* ---------------------------------------------------------------------------
 * R-callable: .Call(C_dbc_sync, path, level, no_verify)
 * --------------------------------------------------------------------------- */
SEXP dbc_sync_r(SEXP path_sexp, SEXP level_sexp, SEXP no_verify_sexp) {
    const char *path = "./dbc.toml";
    if (!isNull(path_sexp) && isString(path_sexp) && length(path_sexp) == 1)
        path = CHAR(STRING_ELT(path_sexp, 0));

    const char *level = "";
    if (!isNull(level_sexp) && isString(level_sexp) && length(level_sexp) == 1)
        level = CHAR(STRING_ELT(level_sexp, 0));

    int no_verify = 0;
    if (!isNull(no_verify_sexp) && isLogical(no_verify_sexp) && length(no_verify_sexp) == 1)
        no_verify = LOGICAL(no_verify_sexp)[0];

    char *errmsg = dbc_sync((char *)path, (char *)level, no_verify);
    if (errmsg != NULL) {
        char buf[4096];
        strncpy(buf, errmsg, sizeof(buf) - 1);
        buf[sizeof(buf) - 1] = '\0';
        free(errmsg);
        error("%s", buf);
    }
    return R_NilValue;
}

/* ---------------------------------------------------------------------------
 * R-callable: .Call(C_dbc_docs, driver)
 * --------------------------------------------------------------------------- */
SEXP dbc_docs_r(SEXP driver_sexp) {
    const char *driver = "";
    if (!isNull(driver_sexp) && isString(driver_sexp) && length(driver_sexp) == 1)
        driver = CHAR(STRING_ELT(driver_sexp, 0));

    char *result = dbc_docs((char *)driver);

    if (result != NULL && strncmp(result, "ERROR:", 6) == 0) {
        char buf[4096];
        strncpy(buf, result + 6, sizeof(buf) - 1);
        buf[sizeof(buf) - 1] = '\0';
        free(result);
        error("%s", buf);
    }

    SEXP out = PROTECT(mkString(result));
    free(result);
    UNPROTECT(1);
    return out;
}

/* ---------------------------------------------------------------------------
 * R-callable: .Call(C_dbc_auth_login, registry_url, api_key, client_id)
 * --------------------------------------------------------------------------- */
SEXP dbc_auth_login_r(SEXP registry_url_sexp, SEXP api_key_sexp, SEXP client_id_sexp) {
    const char *registry_url = "";
    if (!isNull(registry_url_sexp) && isString(registry_url_sexp) && length(registry_url_sexp) == 1)
        registry_url = CHAR(STRING_ELT(registry_url_sexp, 0));

    const char *api_key = "";
    if (!isNull(api_key_sexp) && isString(api_key_sexp) && length(api_key_sexp) == 1)
        api_key = CHAR(STRING_ELT(api_key_sexp, 0));

    const char *client_id = "";
    if (!isNull(client_id_sexp) && isString(client_id_sexp) && length(client_id_sexp) == 1)
        client_id = CHAR(STRING_ELT(client_id_sexp, 0));

    char *errmsg = dbc_auth_login((char *)registry_url, (char *)api_key, (char *)client_id);
    if (errmsg != NULL) {
        char buf[4096];
        strncpy(buf, errmsg, sizeof(buf) - 1);
        buf[sizeof(buf) - 1] = '\0';
        free(errmsg);
        error("%s", buf);
    }
    return R_NilValue;
}

/* ---------------------------------------------------------------------------
 * R-callable: .Call(C_dbc_auth_logout, registry_url, purge)
 * --------------------------------------------------------------------------- */
SEXP dbc_auth_logout_r(SEXP registry_url_sexp, SEXP purge_sexp) {
    const char *registry_url = "";
    if (!isNull(registry_url_sexp) && isString(registry_url_sexp) && length(registry_url_sexp) == 1)
        registry_url = CHAR(STRING_ELT(registry_url_sexp, 0));

    int purge = 0;
    if (!isNull(purge_sexp) && isLogical(purge_sexp) && length(purge_sexp) == 1)
        purge = LOGICAL(purge_sexp)[0];

    char *errmsg = dbc_auth_logout((char *)registry_url, purge);
    if (errmsg != NULL) {
        char buf[4096];
        strncpy(buf, errmsg, sizeof(buf) - 1);
        buf[sizeof(buf) - 1] = '\0';
        free(errmsg);
        error("%s", buf);
    }
    return R_NilValue;
}

/* ---------------------------------------------------------------------------
 * R registration table
 * --------------------------------------------------------------------------- */
#include <R_ext/Rdynload.h>

static const R_CallMethodDef call_methods[] = {
    {"dbc_install_c",      (DL_FUNC) &dbc_install_r,      4},
    {"dbc_search_c",       (DL_FUNC) &dbc_search_r,       2},
    {"dbc_uninstall_c",    (DL_FUNC) &dbc_uninstall_r,    2},
    {"dbc_list_c",         (DL_FUNC) &dbc_list_r,         0},
    {"dbc_info_c",         (DL_FUNC) &dbc_info_r,         1},
    {"dbc_init_c",         (DL_FUNC) &dbc_init_r,         1},
    {"dbc_add_c",          (DL_FUNC) &dbc_add_r,          3},
    {"dbc_remove_c",       (DL_FUNC) &dbc_remove_r,       2},
    {"dbc_sync_c",         (DL_FUNC) &dbc_sync_r,         3},
    {"dbc_docs_c",         (DL_FUNC) &dbc_docs_r,         1},
    {"dbc_auth_login_c",   (DL_FUNC) &dbc_auth_login_r,   3},
    {"dbc_auth_logout_c",  (DL_FUNC) &dbc_auth_logout_r,  2},
    {NULL, NULL, 0}
};

void R_init_dbc(DllInfo *dll) {
    R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
    R_forceSymbols(dll, TRUE);
}
