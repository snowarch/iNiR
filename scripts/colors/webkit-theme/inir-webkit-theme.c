/* inir-webkit-theme: a GTK 3 module that gives every WebKitGTK view in the process a user stylesheet
 * read from a file, and swaps it whenever the file changes. iNiR loads it into WebKitGTK apps that have
 * no theme hook of their own (LiMusic) through GTK_MODULES on their launcher.
 *
 * Built with no headers on purpose: every GLib, GTK and WebKit symbol is resolved at runtime from the
 * libraries the app already loaded (an AppImage bundles its own), so one build works with any of them
 * and a process without WebKit is left alone.
 *
 * INIR_WEBKIT_THEME_CSS    stylesheet path (default $XDG_CONFIG_HOME/limusic/matugen.css)
 * INIR_WEBKIT_THEME_DEBUG  log to stderr
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#define DBG(...) do { if (getenv("INIR_WEBKIT_THEME_DEBUG")) fprintf(stderr, "inir-webkit-theme: " __VA_ARGS__); } while (0)

typedef unsigned long GType;
typedef struct { GType g_type; } GTypeClass;
typedef struct { GTypeClass *g_class; } GTypeInstance;
typedef struct { GType g_type; unsigned long data[2]; } GValue;

#define MAX_VIEWS 16

static struct {
    GType (*widget_get_type)(void);
    unsigned (*signal_lookup)(const char *, GType);
    unsigned long (*add_emission_hook)(unsigned, unsigned, void *, void *, void *);
    void *(*value_get_object)(const GValue *);
    const char *(*type_name)(GType);
    GType (*type_parent)(GType);
    unsigned long (*signal_connect_data)(void *, const char *, void *, void *, void *, int);
    int (*file_get_contents)(const char *, char **, unsigned long *, void **);
    void (*g_free)(void *);
    void *(*file_new_for_path)(const char *);
    void *(*file_monitor_directory)(void *, int, void *, void **);
    char *(*file_get_basename)(void *);
    void *(*get_ucm)(void *);
    void *(*sheet_new)(const char *, int, int, const char *const *, const char *const *);
    void (*add_sheet)(void *, void *);
    void (*remove_sheet)(void *, void *);
    void (*sheet_unref)(void *);
    void *(*object_ref)(void *);
    void *(*type_class_ref)(GType);
} f;

static char *css_path, *css_name;
static char *css_text;
static void *sheet;
static void *views[MAX_VIEWS];
static int n_views;
static void *monitor;

#define SYM(field, name) (f.field = dlsym(RTLD_DEFAULT, name))

static int webkit_ready(void)
{
    return SYM(get_ucm, "webkit_web_view_get_user_content_manager") && SYM(sheet_new, "webkit_user_style_sheet_new")
        && SYM(add_sheet, "webkit_user_content_manager_add_style_sheet")
        && SYM(remove_sheet, "webkit_user_content_manager_remove_style_sheet")
        && SYM(sheet_unref, "webkit_user_style_sheet_unref");
}

static void apply_all(void)
{
    char *text = NULL;
    unsigned long len = 0;
    if (!f.file_get_contents(css_path, &text, &len, NULL))
        text = NULL;
    if (text && css_text && strcmp(text, css_text) == 0) {
        f.g_free(text);
        return;
    }
    DBG("apply %s (%s)\n", css_path, text ? "found" : "missing");
    void *next = text ? f.sheet_new(text, 0 /* all frames */, 1 /* author level */, NULL, NULL) : NULL;
    for (int i = 0; i < n_views; i++) {
        void *ucm = f.get_ucm(views[i]);
        if (!ucm) /* a view the app has destroyed since */
            continue;
        if (sheet)
            f.remove_sheet(ucm, sheet);
        if (next)
            f.add_sheet(ucm, next);
    }
    if (sheet)
        f.sheet_unref(sheet);
    sheet = next;
    if (css_text)
        f.g_free(css_text);
    css_text = text;
}

static void on_dir_changed(void *mon, void *file, void *other, int event, void *data)
{
    (void)mon; (void)event; (void)data;
    /* A rename into place reports the new name as `other`. */
    void *files[2] = { file, other };
    for (int i = 0; i < 2; i++) {
        if (!files[i])
            continue;
        char *base = f.file_get_basename(files[i]);
        int match = base && strcmp(base, css_name) == 0;
        f.g_free(base);
        if (match) {
            apply_all();
            return;
        }
    }
}

static int is_webview(void *obj)
{
    for (GType t = ((GTypeInstance *)obj)->g_class->g_type; t; t = f.type_parent(t)) {
        const char *name = f.type_name(t);
        if (name && strcmp(name, "WebKitWebView") == 0)
            return 1;
    }
    return 0;
}

static int on_map(void *ihint, unsigned n_params, const GValue *params, void *data)
{
    (void)ihint; (void)data;
    if (n_params < 1 || n_views >= MAX_VIEWS)
        return 1;
    void *obj = f.value_get_object(&params[0]);
    if (!obj || !is_webview(obj))
        return 1;
    DBG("webview mapped\n");
    for (int i = 0; i < n_views; i++)
        if (views[i] == obj)
            return 1;
    if (!f.get_ucm && !webkit_ready()) {
        DBG("webkit symbols missing\n");
        return 1;
    }
    views[n_views++] = f.object_ref(obj);
    if (sheet && f.get_ucm(obj))
        f.add_sheet(f.get_ucm(obj), sheet);
    else
        apply_all();
    if (!monitor) {
        char *dir = strdup(css_path);
        char *slash = strrchr(dir, '/');
        if (slash) {
            *slash = '\0';
            monitor = f.file_monitor_directory(f.file_new_for_path(dir), 8 /* watch moves */, NULL, NULL);
            if (monitor)
                f.signal_connect_data(monitor, "changed", (void *)on_dir_changed, NULL, NULL, 0);
        }
        free(dir);
    }
    return 1;
}

void gtk_module_init(int *argc, char ***argv)
{
    (void)argc; (void)argv;
    DBG("init\n");
    if (!(SYM(widget_get_type, "gtk_widget_get_type") && SYM(signal_lookup, "g_signal_lookup")
          && SYM(add_emission_hook, "g_signal_add_emission_hook") && SYM(value_get_object, "g_value_get_object")
          && SYM(type_name, "g_type_name") && SYM(type_parent, "g_type_parent")
          && SYM(signal_connect_data, "g_signal_connect_data") && SYM(file_get_contents, "g_file_get_contents")
          && SYM(g_free, "g_free") && SYM(file_new_for_path, "g_file_new_for_path")
          && SYM(file_monitor_directory, "g_file_monitor_directory") && SYM(file_get_basename, "g_file_get_basename")
          && SYM(object_ref, "g_object_ref") && SYM(type_class_ref, "g_type_class_ref")))
        return;

    const char *env = getenv("INIR_WEBKIT_THEME_CSS");
    if (env && *env) {
        css_path = strdup(env);
    } else {
        const char *cfg = getenv("XDG_CONFIG_HOME"), *home = getenv("HOME");
        const char *tail = "/limusic/matugen.css";
        if (cfg && *cfg) {
            css_path = malloc(strlen(cfg) + strlen(tail) + 1);
            strcpy(css_path, cfg);
        } else if (home) {
            css_path = malloc(strlen(home) + strlen("/.config") + strlen(tail) + 1);
            strcpy(css_path, home);
            strcat(css_path, "/.config");
        } else {
            return;
        }
        strcat(css_path, tail);
    }
    css_name = strrchr(css_path, '/') ? strrchr(css_path, '/') + 1 : css_path;

    /* Signals exist once the class is initialised, which has not happened yet at module load. */
    f.type_class_ref(f.widget_get_type());
    unsigned map = f.signal_lookup("map", f.widget_get_type());
    if (map)
        f.add_emission_hook(map, 0, (void *)on_map, NULL, NULL);
}
