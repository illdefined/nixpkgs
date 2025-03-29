{
  rustPlatform,
  fetchFromGitHub,
  lib,
  acl,
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

  useFetchCargoVendor = true;
  cargoHash = "sha256-I1v4DDWflroZwp0vprWP0SXj2PnlCgQ5dusFykoT3zg=";

  checkInputs = [ acl ];

  # disable tests depending on special filesystem features
  checkNoDefaultFeatures = true;
  checkFeatures = [
    "test_no_reflink"
    "test_no_sparse"
    "test_no_extents"
    "test_no_acl"
    "test_no_xattr"
    "test_no_perms"
  ];

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Extended cp(1)";
    homepage = "https://github.com/tarka/xcp";
    changelog = "https://github.com/tarka/xcp/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    maintainers = with lib.maintainers; [ lom ];
    mainProgram = "xcp";
  };
})
