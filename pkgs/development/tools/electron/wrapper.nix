{
  stdenv,
  electron-unwrapped,
  wrapGAppsHook3,
  makeWrapper,
  gsettings-desktop-schemas,
  glib,
  gtk3,
  gtk4,
}:

stdenv.mkDerivation {
  pname = "electron";
  inherit (electron-unwrapped) version;

  nativeBuildInputs = [
    wrapGAppsHook3
    makeWrapper
  ];
  buildInputs = [
    # needed for GSETTINGS_SCHEMAS_PATH
    gsettings-desktop-schemas
    glib
    gtk3
    gtk4
  ];
  dontWrapGApps = true;

  buildCommand = ''
    gappsWrapperArgsHook
    mkdir -p $out/bin
    makeShellWrapper "${electron-unwrapped}/libexec/electron/electron" "$out/bin/electron" \
      "''${gappsWrapperArgs[@]}" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}" \
      --set CHROME_DEVEL_SANDBOX $out/libexec/electron/chrome-sandbox

    ln -s ${electron-unwrapped}/libexec $out/libexec
  '';

  passthru = {
    unwrapped = electron-unwrapped;
    inherit (electron-unwrapped) headers dist;
  };
  inherit (electron-unwrapped) meta;
}
