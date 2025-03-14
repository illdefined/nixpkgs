{
  lib,
  stdenv,
  rust,
  hdr10plus_tool,
  cargo-c,
}:

let
  inherit (lib) optionals concatStringsSep;
  inherit (rust.envVars) setEnv;
in
hdr10plus_tool.overrideAttrs (
  finalAttrs: prevAttrs: {
    __structuredAttrs = true;

    pname = "hdr10plus";
    outputs = [
      "out"
      "dev"
    ];

    nativeBuildInputs = prevAttrs.nativeBuildInputs ++ [ cargo-c ];

    cargoCFlags = [
      "--package=hdr10plus"
      "--frozen"
      "--prefix=${placeholder "out"}"
      "--includedir=${placeholder "dev"}/include"
      "--pkgconfigdir=${placeholder "dev"}/lib/pkgconfig"
      "--target=${stdenv.hostPlatform.rust.rustcTarget}"
    ];

    # mirror Cargo flags
    cargoCBuildFlags =
      optionals (finalAttrs.cargoBuildType != "debug") [
        "--profile=${finalAttrs.cargoBuildType}"
      ]
      ++ optionals (finalAttrs.cargoBuildNoDefaultFeatures) [
        "--no-default-features"
      ]
      ++ optionals (finalAttrs.cargoBuildFeatures != [ ]) [
        "--features=${concatStringsSep "," finalAttrs.cargoBuildFeatures}"
      ];

    cargoCTestFlags =
      optionals (finalAttrs.cargoCheckType != "debug") [
        "--profile=${finalAttrs.cargoCheckType}"
      ]
      ++ optionals (finalAttrs.cargoCheckNoDefaultFeatures) [
        "--no-default-features"
      ]
      ++ optionals (finalAttrs.cargoCheckFeatures != [ ]) [
        "--features=${concatStringsSep "," finalAttrs.cargoCheckFeatures}"
      ];

    configurePhase = ''
      # let stdenv handle stripping
      export "CARGO_PROFILE_''${cargoBuildType@U}_STRIP"=false

      prependToVar cargoCFlags -j "$NIX_BUILD_CORES"
    '';

    buildPhase = ''
      runHook preBuild

      ${setEnv} cargo cbuild "''${cargoCFlags[@]}" "''${cargoCBuildFlags[@]}"

      runHook postBuild
    '';

    checkPhase = ''
      runHook preCheck

      ${setEnv} cargo ctest "''${cargoCFlags[@]}" "''${cargoCTestFlags[@]}"

      runHook postCheck
    '';

    installPhase = ''
      runHook preInstall

      ${setEnv} cargo cinstall "''${cargoCFlags[@]}" "''${cargoCBuildFlags[@]}"

      runHook postInstall
    '';

    passthru.tests = { inherit hdr10plus_tool; };

    meta = prevAttrs.meta // {
      description = "Libray to work with HDR10+ in HEVC files";
      maintainers = with lib.maintainers; [ mvs ];
      pkgConfigModules = [ "hdr10plus-rs" ];
    };
  }
)
