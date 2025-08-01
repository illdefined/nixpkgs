{
  stdenv,
  lib,
  fetchurl,
  meson,
  ninja,
  pkg-config,
  replaceVars,
  gettext,
  dbus,
  glib,
  udevSupport ? stdenv.hostPlatform.isLinux,
  libgudev,
  udisks2,
  libgcrypt,
  libcap,
  polkit,
  libgphoto2,
  avahi,
  libarchive,
  fuse3,
  libcdio,
  libxml2,
  libsoup_3,
  libxslt,
  docbook_xsl,
  docbook_xml_dtd_42,
  samba,
  libmtp,
  gnomeSupport ? false,
  gnome,
  gcr_4,
  glib-networking,
  gnome-online-accounts,
  wrapGAppsHook3,
  libimobiledevice,
  libbluray,
  libcdio-paranoia,
  libnfs,
  openssh,
  libsecret,
  libgdata,
  libmsgraph,
  python3,
  gsettings-desktop-schemas,
  googleSupport ? false, # dependency on vulnerable libsoup versions
}:

assert googleSupport -> gnomeSupport;
stdenv.mkDerivation (finalAttrs: {
  pname = "gvfs";
  version = "1.57.2";

  src = fetchurl {
    url = "mirror://gnome/sources/gvfs/${lib.versions.majorMinor finalAttrs.version}/gvfs-${finalAttrs.version}.tar.xz";
    hash = "sha256-8Wvvjsof1sEX6F2wEdIekVZpeQ1VhnNJxfGykSmelYU=";
  };

  patches = [
    (replaceVars ./hardcode-ssh-path.patch {
      ssh_program = "${lib.getBin openssh}/bin/ssh";
    })
  ];

  postPatch = ''
    patchShebangs test
  '';

  nativeBuildInputs = [
    meson
    ninja
    python3
    pkg-config
    gettext
    wrapGAppsHook3
    libxslt
    docbook_xsl
    docbook_xml_dtd_42
  ];

  buildInputs = [
    glib
    libgcrypt
    dbus
    libgphoto2
    avahi
    libarchive
    libimobiledevice
    libbluray
    libnfs
    libxml2
    gsettings-desktop-schemas
    libsoup_3
  ]
  ++ lib.optionals udevSupport [
    libgudev
    udisks2
    fuse3
    libcdio
    samba
    libmtp
    libcap
    polkit
    libcdio-paranoia
  ]
  ++ lib.optionals gnomeSupport [
    gcr_4
    glib-networking # TLS support
    gnome-online-accounts
    libsecret
    libmsgraph
  ]
  ++ lib.optionals googleSupport [
    libgdata
  ];

  mesonFlags = [
    "-Dsystemduserunitdir=${placeholder "out"}/lib/systemd/user"
    "-Dtmpfilesdir=no"
  ]
  ++ lib.optionals (!udevSupport) [
    "-Dgudev=false"
    "-Dudisks2=false"
    "-Dfuse=false"
    "-Dcdda=false"
    "-Dsmb=false"
    "-Dmtp=false"
    "-Dadmin=false"
    "-Dgphoto2=false"
    "-Dlibusb=false"
    "-Dlogind=false"
  ]
  ++ lib.optionals (!gnomeSupport) [
    "-Dgcr=false"
    "-Dgoa=false"
    "-Dkeyring=false"
    "-Donedrive=false"
  ]
  ++ lib.optionals (!googleSupport) [
    "-Dgoogle=false"
  ]
  ++ lib.optionals (avahi == null) [
    "-Ddnssd=false"
  ]
  ++ lib.optionals (samba == null) [
    # Xfce don't want samba
    "-Dsmb=false"
  ];

  doCheck = false; # fails with "ModuleNotFoundError: No module named 'gi'"
  doInstallCheck = finalAttrs.finalPackage.doCheck;

  separateDebugInfo = true;

  passthru = {
    updateScript = gnome.updateScript {
      packageName = "gvfs";
      versionPolicy = "odd-unstable";
    };
  };

  meta = with lib; {
    description =
      "Virtual Filesystem support library" + optionalString gnomeSupport " (full GNOME support)";
    license = licenses.lgpl2Plus;
    platforms = platforms.unix;
    teams = [ teams.gnome ];
  };
})
