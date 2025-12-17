# Nautilus CSS Hot Reload

Live CSS reloading for GNOME Files (Nautilus). Automatically reloads `~/.config/gtk-4.0/gtk.css` when it changes — perfect for dynamic theming with [matugen](https://github.com/InioX/matugen), [pywal](https://github.com/dylanaraps/pywal), or any other theme generator.

## The Problem

GTK4 apps like Nautilus read your custom CSS at startup but don't watch for changes. If you use matugen or similar tools to dynamically generate themes, you have to restart Nautilus to see updates.

## The Solution

This patch adds a `GFileMonitor` to Nautilus that watches your CSS file and reloads it instantly when changes are detected.

## Demo

Run matugen → Nautilus updates instantly. No restart needed!

---

## Installation

### NixOS (Flakes)

1. Add to your `flake.nix` inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    nautilus-css-hot-reload = {
      url = "github:bostannnn/nautilus-css-hot-reload";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
```

2. Add the module and input to outputs:

```nix
{
  outputs = { nixpkgs, nautilus-css-hot-reload, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      modules = [
        ./configuration.nix
        nautilus-css-hot-reload.nixosModules.default
      ];
    };
  };
}
```

3. Rebuild:

```bash
sudo nixos-rebuild switch --flake .#
nautilus -q && nautilus
```

---

### Arch Linux (AUR / Manual)

#### Option 1: Use the PKGBUILD

Create a directory and save this as `PKGBUILD`:

```bash
# Maintainer: Your Name <your@email.com>
pkgname=nautilus-css-hot-reload
pkgver=49.2
pkgrel=1
pkgdesc="GNOME Files with CSS hot-reload support for dynamic theming"
arch=('x86_64')
url="https://github.com/bostannnn/nautilus-css-hot-reload"
license=('GPL3')
depends=('glib2' 'gtk4' 'libadwaita' 'gnome-autoar' 'gnome-desktop-4'
         'libcloudproviders' 'libgexiv2' 'gst-plugins-base-libs' 'localsearch'
         'libportal-gtk4')
makedepends=('git' 'meson' 'gobject-introspection' 'gi-docgen')
provides=('nautilus')
conflicts=('nautilus')
source=("https://download.gnome.org/sources/nautilus/${pkgver%.*}/nautilus-${pkgver}.tar.xz")
sha256sums=('SKIP')

prepare() {
    cd "nautilus-$pkgver"
    
    # Add CSS hot-reload source file
    cat > src/nautilus-css-hot-reload.c << 'EOF'
#include "nautilus-css-hot-reload.h"
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
    if (g_file_test (css_path, G_FILE_TEST_EXISTS)) {
        g_message ("CSS Hot Reload: Reloading %s", css_path);
        gtk_css_provider_load_from_path (hot_reload_provider, css_path);
    } else {
        gtk_css_provider_load_from_string (hot_reload_provider, "");
    }
    return G_SOURCE_REMOVE;
}

static void
hot_reload_on_changed (GFileMonitor *monitor, GFile *file, GFile *other_file,
                       GFileMonitorEvent event_type, gpointer user_data)
{
    if (event_type == G_FILE_MONITOR_EVENT_CHANGED ||
        event_type == G_FILE_MONITOR_EVENT_CREATED ||
        event_type == G_FILE_MONITOR_EVENT_ATTRIBUTE_CHANGED) {
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
    hot_reload_provider = gtk_css_provider_new ();
    
    if (g_file_test (css_path, G_FILE_TEST_EXISTS))
        gtk_css_provider_load_from_path (hot_reload_provider, css_path);
    
    display = gdk_display_get_default ();
    if (display != NULL) {
        gtk_style_context_add_provider_for_display (display,
            GTK_STYLE_PROVIDER (hot_reload_provider),
            GTK_STYLE_PROVIDER_PRIORITY_USER + 1);
    }
    
    hot_reload_monitor = g_file_monitor_file (css_file, G_FILE_MONITOR_NONE, NULL, &error);
    if (hot_reload_monitor != NULL) {
        g_signal_connect (hot_reload_monitor, "changed",
                          G_CALLBACK (hot_reload_on_changed), NULL);
        g_message ("CSS Hot Reload: Watching %s", css_path);
    }
}
EOF

    # Add header file
    cat > src/nautilus-css-hot-reload.h << 'EOF'
#pragma once
#include <glib.h>
G_BEGIN_DECLS
void nautilus_css_hot_reload_init (void);
G_END_DECLS
EOF

    # Patch meson.build
    sed -i "s|'nautilus-application.c',|'nautilus-application.c',\n  'nautilus-css-hot-reload.c',|" src/meson.build
    
    # Patch nautilus-application.c
    sed -i '/#include "nautilus-application.h"/a #include "nautilus-css-hot-reload.h"' src/nautilus-application.c
    sed -i 's|G_APPLICATION_CLASS (nautilus_application_parent_class)->startup (G_APPLICATION (self));|G_APPLICATION_CLASS (nautilus_application_parent_class)->startup (G_APPLICATION (self));\n    nautilus_css_hot_reload_init ();|' src/nautilus-application.c
}

build() {
    arch-meson "nautilus-$pkgver" build
    meson compile -C build
}

package() {
    meson install -C build --destdir "$pkgdir"
}
```

Then build and install:

```bash
makepkg -si
```

#### Option 2: Patch existing installation

```bash
# Install build dependencies
sudo pacman -S base-devel meson ninja git

# Get the source
cd /tmp
curl -O https://download.gnome.org/sources/nautilus/49/nautilus-49.2.tar.xz
tar xf nautilus-49.2.tar.xz
cd nautilus-49.2

# Download and apply patch
curl -O https://raw.githubusercontent.com/bostannnn/nautilus-css-hot-reload/main/nautilus-css-hot-reload.patch
patch -p1 < nautilus-css-hot-reload.patch

# Build
meson setup build --prefix=/usr
meson compile -C build

# Install (backs up original)
sudo meson install -C build
```

---

### Fedora

```bash
# Install build dependencies
sudo dnf install meson ninja-build gcc glib2-devel gtk4-devel libadwaita-devel \
    gnome-autoar-devel gnome-desktop4-devel libcloudproviders-devel \
    libgexiv2-devel gstreamer1-plugins-base-devel tracker-devel libportal-gtk4-devel

# Get the source (match your Fedora's nautilus version)
dnf download --source nautilus
rpm -ivh nautilus-*.src.rpm
cd ~/rpmbuild/SOURCES

# Or download directly
cd /tmp
curl -O https://download.gnome.org/sources/nautilus/49/nautilus-49.2.tar.xz
tar xf nautilus-49.2.tar.xz
cd nautilus-49.2

# Download and apply patch
curl -O https://raw.githubusercontent.com/bostannnn/nautilus-css-hot-reload/main/nautilus-css-hot-reload.patch
patch -p1 < nautilus-css-hot-reload.patch

# Build
meson setup build --prefix=/usr
meson compile -C build

# Install
sudo meson install -C build
```

---

### Ubuntu / Debian

```bash
# Install build dependencies
sudo apt install build-essential meson ninja-build libglib2.0-dev libgtk-4-dev \
    libadwaita-1-dev libgnome-autoar-0-dev libgnome-desktop-4-dev \
    libcloudproviders-dev libgexiv2-dev libgstreamer-plugins-base1.0-dev \
    tracker libportal-gtk4-dev

# Get source
cd /tmp
curl -O https://download.gnome.org/sources/nautilus/49/nautilus-49.2.tar.xz
tar xf nautilus-49.2.tar.xz
cd nautilus-49.2

# Download and apply patch  
curl -O https://raw.githubusercontent.com/bostannnn/nautilus-css-hot-reload/main/nautilus-css-hot-reload.patch
patch -p1 < nautilus-css-hot-reload.patch

# Build
meson setup build --prefix=/usr
meson compile -C build

# Install
sudo meson install -C build
```

---

### Generic (Any Distro)

1. Install meson, ninja, and Nautilus build dependencies for your distro
2. Download Nautilus source matching your installed version:
   ```bash
   curl -O https://download.gnome.org/sources/nautilus/49/nautilus-49.2.tar.xz
   tar xf nautilus-49.2.tar.xz
   cd nautilus-49.2
   ```
3. Apply the patch:
   ```bash
   curl -O https://raw.githubusercontent.com/bostannnn/nautilus-css-hot-reload/main/nautilus-css-hot-reload.patch
   patch -p1 < nautilus-css-hot-reload.patch
   ```
4. Build and install:
   ```bash
   meson setup build --prefix=/usr
   meson compile -C build
   sudo meson install -C build
   ```

---

## Usage

After installation, restart Nautilus:

```bash
nautilus -q && nautilus
```

You should see in the terminal:
```
CSS Hot Reload: Watching /home/youruser/.config/gtk-4.0/gtk.css
```

Now any changes to `~/.config/gtk-4.0/gtk.css` will be applied instantly!

### With matugen

```bash
matugen image ~/wallpaper.png
```

Nautilus updates live — no restart needed.

### Manual test

```bash
# Add some CSS
echo "window { background: red; }" >> ~/.config/gtk-4.0/gtk.css
# Nautilus turns red instantly!

# Revert
sed -i '/background: red/d' ~/.config/gtk-4.0/gtk.css
```

---

## How It Works

The patch adds ~100 lines of C code:

1. Creates a `GtkCssProvider` at startup
2. Loads existing CSS from `~/.config/gtk-4.0/gtk.css`  
3. Registers a `GFileMonitor` on the CSS file
4. On file change, reloads the CSS with 50ms debounce

---

## Limitations

- Only watches `~/.config/gtk-4.0/gtk.css` (not system themes or `@import`ed files)
- Need to rebuild when Nautilus updates
- Other GTK4 apps won't hot-reload (only Nautilus is patched)

---

## Contributing

This would be great to have upstream in libadwaita or GTK4. PRs welcome!

- [GTK GitLab](https://gitlab.gnome.org/GNOME/gtk) — for toolkit-level CSS reload
- [libadwaita GitLab](https://gitlab.gnome.org/GNOME/libadwaita) — for Adwaita-specific implementation
- [Nautilus GitLab](https://gitlab.gnome.org/GNOME/nautilus) — for Nautilus-specific features

---

## License

GPL-3.0-or-later (matching Nautilus)
