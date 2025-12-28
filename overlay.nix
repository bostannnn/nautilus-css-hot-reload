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
        --run 'for d in /run/current-system/sw/share /etc/xdg; do case ":''${XDG_DATA_DIRS:-}:" in *:"$d":*) ;; "") XDG_DATA_DIRS="$d" ;; *) XDG_DATA_DIRS="''${XDG_DATA_DIRS}:$d" ;; esac; done; export XDG_DATA_DIRS' \
        --run 'for d in /run/current-system/sw/lib/nautilus/extensions-4; do case ":''${NAUTILUS_EXTENSION_DIRS:-}:" in *:"$d":*) ;; "") NAUTILUS_EXTENSION_DIRS="$d" ;; *) NAUTILUS_EXTENSION_DIRS="''${NAUTILUS_EXTENSION_DIRS}:$d" ;; esac; done; export NAUTILUS_EXTENSION_DIRS'
    '';
  });
}
