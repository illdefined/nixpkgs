{ lib, buildGoModule, fetchFromGitHub }:

buildGoModule rec {
  pname = "flex-ncat";
  version = "0.1-20221007.0";

  src = fetchFromGitHub {
    owner = "kc2g-flex-tools";
    repo = "nCAT";
    rev = "v${version}";
    hash = "sha256-LOJLQdW1gyIe1YT+GioFSdDzFuAoYq3ote5osf6sCZk=";
  };

  vendorSha256 = "sha256-TfEsRxd3JWmcVTv5030CYi4cQm3gub2knXcHpkv+wN0=";

  meta = with lib; {
    homepage = "https://github.com/kc2g-flex-tools/nCAT";
    description = "FlexRadio remote control (CAT) via hamlib/rigctl protocol";
    license = licenses.mit;
    maintainers = with maintainers; [ mvs ];
    mainProgram = "nCAT";
  };
}
