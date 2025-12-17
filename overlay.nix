# Overlay that patches Nautilus with CSS hot-reload support
final: prev: {
  nautilus = prev.nautilus.overrideAttrs (old: {
    pname = "nautilus-css-hot-reload";
    
    postPatch = (old.postPatch or "") + ''
      # Add CSS hot-reload source file
      cat > src/nautilus-css-hot-reload.c << 'EOF'
/*
 * nautilus-css-hot-reload.c
 * Watch ~/.config/gtk-4.0/gtk.css and reload on changes
 * 
 * This enables live theme updates with tools like matugen.
 */

#include <gtk/gtk.h>
#include <gio/gio.h>

static GtkCssProvider *hot_reload_provider = NULL;
static GFileMonitor *hot_reload_monitor = NULL;
static guint hot_reload_source = 0;

static gboolean
hot_reload_do_reload (gpointer user_data)
{
    const char *config_dir;
    g_autofree char *css_path = NULL;
    
    hot_reload_source = 0;
    
    config_dir = g_get_user_config_dir ();
    css_path = g_build_filename (config_dir, "gtk-4.0", "gtk.css", NULL);
    
    if (g_file_test (css_path, G_FILE_TEST_EXISTS))
    {
        g_message ("CSS Hot Reload: Reloading %s", css_path);
        gtk_css_provider_load_from_path (hot_reload_provider, css_path);
    }
    else
    {
        gtk_css_provider_load_from_string (hot_reload_provider, "");
    }
    
    return G_SOURCE_REMOVE;
}

static void
hot_reload_on_changed (GFileMonitor      *monitor,
                       GFile             *file,
                       GFile             *other_file,
                       GFileMonitorEvent  event_type,
                       gpointer           user_data)
{
    if (event_type == G_FILE_MONITOR_EVENT_CHANGED ||
        event_type == G_FILE_MONITOR_EVENT_CREATED ||
        event_type == G_FILE_MONITOR_EVENT_ATTRIBUTE_CHANGED)
    {
        /* Debounce rapid changes (editor saves, etc.) */
        if (hot_reload_source > 0)
            g_source_remove (hot_reload_source);
        
        hot_reload_source = g_timeout_add (50, hot_reload_do_reload, NULL);
    }
}

void
nautilus_css_hot_reload_init (void)
{
    const char *config_dir;
    g_autofree char *css_path = NULL;
    g_autoptr(GFile) css_file = NULL;
    g_autoptr(GError) error = NULL;
    GdkDisplay *display;
    
    config_dir = g_get_user_config_dir ();
    css_path = g_build_filename (config_dir, "gtk-4.0", "gtk.css", NULL);
    css_file = g_file_new_for_path (css_path);
    
    /* Create CSS provider */
    hot_reload_provider = gtk_css_provider_new ();
    
    /* Initial load */
    if (g_file_test (css_path, G_FILE_TEST_EXISTS))
        gtk_css_provider_load_from_path (hot_reload_provider, css_path);
    
    /* Register provider */
    display = gdk_display_get_default ();
    if (display != NULL)
    {
        gtk_style_context_add_provider_for_display (
            display,
            GTK_STYLE_PROVIDER (hot_reload_provider),
            GTK_STYLE_PROVIDER_PRIORITY_USER + 1);
    }
    
    /* Setup file monitor */
    hot_reload_monitor = g_file_monitor_file (
        css_file,
        G_FILE_MONITOR_NONE,
        NULL,
        &error);
    
    if (hot_reload_monitor != NULL)
    {
        g_signal_connect (hot_reload_monitor, "changed",
                          G_CALLBACK (hot_reload_on_changed), NULL);
        g_message ("CSS Hot Reload: Watching %s", css_path);
    }
    else if (error != NULL)
    {
        g_warning ("CSS Hot Reload: Failed to monitor: %s", error->message);
    }
}
EOF

      # Add header file
      cat > src/nautilus-css-hot-reload.h << 'EOF'
#pragma once
void nautilus_css_hot_reload_init (void);
EOF

      # Add source to meson.build
      sed -i "s|'nautilus-application.c',|'nautilus-application.c',\n  'nautilus-css-hot-reload.c',|" src/meson.build
      
      # Add include to nautilus-application.c
      sed -i '/#include "nautilus-application.h"/a #include "nautilus-css-hot-reload.h"' src/nautilus-application.c
      
      # Add init call after parent class startup
      sed -i '/G_APPLICATION_CLASS (nautilus_application_parent_class)->startup (app);/a\    nautilus_css_hot_reload_init ();' src/nautilus-application.c
    '';
  });
}
