# Overlay that patches Nautilus with CSS hot-reload support
final: prev: {
  nautilus = prev.nautilus.overrideAttrs (old: {
    pname = "nautilus-css-hot-reload";
    nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.makeWrapper ];

    postPatch = (old.postPatch or "") + ''
      patch -p1 < ${./nautilus-css-hot-reload.patch}
    '';

    postFixup = (old.postFixup or "") + ''
      wrapProgram "$out/bin/nautilus" \
        --run 'if [ -z "''${XDG_DATA_DIRS:-}" ]; then export XDG_DATA_DIRS=/run/current-system/sw/share:/etc/xdg; else export XDG_DATA_DIRS="''${XDG_DATA_DIRS}:/run/current-system/sw/share:/etc/xdg"; fi' \
        --run 'if [ -z "''${NAUTILUS_EXTENSION_DIRS:-}" ]; then export NAUTILUS_EXTENSION_DIRS=/run/current-system/sw/lib/nautilus/extensions-4; else export NAUTILUS_EXTENSION_DIRS="''${NAUTILUS_EXTENSION_DIRS}:/run/current-system/sw/lib/nautilus/extensions-4"; fi'
    '';
  });
}
