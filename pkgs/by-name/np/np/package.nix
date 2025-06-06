{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "np";
  version = "0.11.0";

  src = fetchFromGitHub {
    owner = "leesoh";
    repo = "np";
    tag = "v${version}";
    hash = "sha256-4krjQi/zEC4a+CjacgbnQIMKKFVr6H2FSwRVB6pkHf0=";
  };

  vendorHash = "sha256-rSg4YFLZdtyC/tm/EULyt7r0O9PXI72W8y6/ltDSbj4=";

  ldflags = [
    "-s"
    "-w"
  ];

  meta = {
    description = "Tool to parse, deduplicate, and query multiple port scans";
    homepage = "https://github.com/leesoh/np";
    changelog = "https://github.com/leesoh/np/releases/tag/v${version}";
    license = lib.licenses.agpl3Only;
    maintainers = with lib.maintainers; [ fab ];
    mainProgram = "np";
  };
}
