# Nautilus CSS Hot Reload

Live CSS reloading for GNOME Files (Nautilus). Automatically reloads `~/.config/gtk-4.0/gtk.css` when it changes — perfect for dynamic theming with [matugen](https://github.com/InioX/matugen).

## The Problem

GTK4 apps like Nautilus read your custom CSS at startup but don't watch for changes. If you use matugen or similar tools to dynamically generate themes, you have to restart Nautilus to see updates.

## The Solution

This patch adds a `GFileMonitor` to Nautilus that watches your CSS file and reloads it instantly when changes are detected.

## Installation

### NixOS (Flakes)

1. Add to your `flake.nix` inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    nautilus-css-hot-reload = {
      url = "github:YOUR_USERNAME/nautilus-css-hot-reload";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # ... your other inputs
  };
}
```

2. Add the module to your NixOS configuration:

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
```

4. Restart Nautilus:

```bash
nautilus -q && nautilus
```

You should see in the terminal:
```
CSS Hot Reload: Watching /home/youruser/.config/gtk-4.0/gtk.css
```

### Complete Example flake.nix

```nix
{
  description = "My NixOS configuration";
  
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    
    nautilus-css-hot-reload = {
      url = "github:YOUR_USERNAME/nautilus-css-hot-reload";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  
  outputs = { nixpkgs, nautilus-css-hot-reload, home-manager, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        nautilus-css-hot-reload.nixosModules.default
        home-manager.nixosModules.home-manager
      ];
    };
  };
}
```

## Usage with matugen

1. Configure matugen to output GTK4 CSS:

```toml
# ~/.config/matugen/config.toml
[templates.gtk4]
input_path = "~/.config/matugen/templates/gtk4.css"
output_path = "~/.config/gtk-4.0/gtk.css"
```

2. Generate theme:

```bash
matugen image ~/wallpaper.png
```

3. Watch Nautilus update instantly!

## How It Works

The patch adds ~100 lines of C code to `nautilus-application.c`:

1. Creates a `GtkCssProvider` at startup
2. Loads existing CSS from `~/.config/gtk-4.0/gtk.css`
3. Registers a `GFileMonitor` on the CSS file
4. On file change, reloads the CSS with 50ms debounce

## Limitations

- Only watches `~/.config/gtk-4.0/gtk.css` (not system themes or `@import`ed files)
- Requires Nautilus rebuild on nixpkgs updates
- First build takes longer (compiling Nautilus from source)

## Contributing

This would be great to have upstream in libadwaita or GTK4 itself. If you're interested in pursuing that:

- [GTK GitLab](https://gitlab.gnome.org/GNOME/gtk)
- [libadwaita GitLab](https://gitlab.gnome.org/GNOME/libadwaita)

## License

GPL-3.0-or-later (matching Nautilus)
