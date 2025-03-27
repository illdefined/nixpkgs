{
  rustPlatform,
  fetchFromGitHub,
  lib,
  nix-update-script,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "xcp";
  version = "0.23.1";

  src = fetchFromGitHub {
    owner = "tarka";
    repo = "xcp";
    rev = "v${finalAttrs.version}";
    hash = "sha256-LtIPuktZYl3JdudsiOtOumR7omF9u5Z4lR1+a2W4qiI=";
  };

  # no such file or directory errors
  doCheck = false;

  useFetchCargoVendor = true;
  cargoHash = "sha256-I1v4DDWflroZwp0vprWP0SXj2PnlCgQ5dusFykoT3zg=";

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Extended cp(1)";
    homepage = "https://github.com/tarka/xcp";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ lom ];
    mainProgram = "xcp";
  };
})
