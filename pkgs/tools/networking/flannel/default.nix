{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nixosTests,
}:

buildGoModule rec {
  pname = "flannel";
  version = "0.27.1";
  rev = "v${version}";

  vendorHash = "sha256-FR9jeHVZS87Tlv1jtO4h5ZDqKIRLfa4xGlpCj1IWoXU=";

  src = fetchFromGitHub {
    inherit rev;
    owner = "flannel-io";
    repo = "flannel";
    sha256 = "sha256-xmKXemr/qSLsBOwLhJIewF7Iu/ERpZX8kUFgotz4Yyw=";
  };

  ldflags = [ "-X github.com/flannel-io/flannel/pkg/version.Version=${rev}" ];

  # TestRouteCache/TestV6RouteCache fail with "Failed to create newns: operation not permitted"
  doCheck = false;

  passthru.tests = { inherit (nixosTests) flannel; };

  meta = with lib; {
    description = "Network fabric for containers, designed for Kubernetes";
    license = licenses.asl20;
    homepage = "https://github.com/flannel-io/flannel";
    maintainers = with maintainers; [
      johanot
      offline
    ];
    platforms = with platforms; linux;
    mainProgram = "flannel";
  };
}
