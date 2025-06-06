{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  autoreconfHook,
  gnutls,
  c-ares,
  libxml2,
  sqlite,
  zlib,
  libssh2,
  cppunit,
  sphinx,
  nixosTests,
}:

stdenv.mkDerivation rec {
  pname = "aria2";
  version = "1.37.0";

  src = fetchFromGitHub {
    owner = "aria2";
    repo = "aria2";
    rev = "release-${version}";
    sha256 = "sha256-xbiNSg/Z+CA0x0DQfMNsWdA+TATyX6dCeW2Nf3L3Kfs=";
  };

  strictDeps = true;
  nativeBuildInputs = [
    pkg-config
    autoreconfHook
    sphinx
  ];

  buildInputs = [
    gnutls
    c-ares
    libxml2
    sqlite
    zlib
    libssh2
  ];

  outputs = [
    "bin"
    "dev"
    "out"
    "doc"
    "man"
  ];

  configureFlags = [
    "--with-ca-bundle=/etc/ssl/certs/ca-certificates.crt"
    "--enable-libaria2"
    "--with-bashcompletiondir=${placeholder "bin"}/share/bash-completion/completions"
  ];

  prePatch = ''
    patchShebangs --build doc/manual-src/en/mkapiref.py
  '';

  nativeCheckInputs = [ cppunit ];
  doCheck = false; # needs the net

  enableParallelBuilding = true;

  passthru.tests = {
    aria2 = nixosTests.aria2;
  };

  meta = {
    homepage = "https://aria2.github.io";
    changelog = "https://github.com/aria2/aria2/releases/tag/release-${version}";
    description = "Lightweight, multi-protocol, multi-source, command-line download utility";
    mainProgram = "aria2c";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.unix;
    maintainers = with lib.maintainers; [
      Br1ght0ne
      koral
      timhae
    ];
  };
}
