{
  nix-update-script,
  fetchFromGitHub,
  lib,
  stdenvNoCC,
  coreutils,
  kmod,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "alsa-ucm-conf";
  version = "1.2.15.3-unstable-2026-01-29";

  src = fetchFromGitHub {
    owner = "alsa-project";
    repo = "alsa-ucm-conf";
    rev = "4b0668f670409e13f98ffa6ee434bac886212762";
    hash = "sha256-CbgYe2/CTFBcjEdiJx+eVFIOmLwQRiPH47HdYbSvn3M=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    substituteInPlace ucm2/lib/card-init.conf \
      --replace-fail "/bin/rm" "${coreutils}/bin/rm" \
      --replace-fail "/bin/mkdir" "${coreutils}/bin/mkdir"
  ''
  + lib.optionalString stdenvNoCC.hostPlatform.isLinux ''
    substituteInPlace ucm2/common/ctl/led.conf \
      --replace-fail '/sbin/modprobe' '${kmod}/bin/modprobe'
  ''
  + ''

    mkdir -p $out/share/alsa
    cp -r ucm ucm2 $out/share/alsa

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [ "--version=branch" ];
  };

  meta = {
    homepage = "https://www.alsa-project.org/";
    description = "ALSA Use Case Manager configuration";

    longDescription = ''
      The Advanced Linux Sound Architecture (ALSA) provides audio and
      MIDI functionality to the Linux-based operating system.
    '';

    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [
      roastiek
      mvs
    ];

    platforms = lib.platforms.linux ++ lib.platforms.freebsd;
  };
})
