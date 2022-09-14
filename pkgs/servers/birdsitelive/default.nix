{ lib
, stdenv
, buildDotnetModule
, fetchFromGitHub
, dotnetCorePackages
}:

buildDotnetModule rec {
  pname = "birdsitelive";
  version = "0.20.0";

  src = fetchFromGitHub {
    owner = "NicolasConstant";
    repo = "BirdsiteLive";
    rev = version;
    hash = "sha256-RAgflgm8EDiRVqP32Q/bcMIol6x4nZYsHJ0z1CA/Sls=";
  };

  projectFile = [
    "src/BirdsiteLive/BirdsiteLive.csproj"
    "src/BSLManager/BSLManager.csproj"
  ];

  nugetDeps = ./deps.nix;

  dotnet-sdk = dotnetCorePackages.sdk_3_1;
  dotnet-runtime = dotnetCorePackages.aspnetcore_3_1;

  doCheck = true;

  meta = with lib; {
    homepage = "https://github.com/NicolasConstant/BirdsiteLive";
    description = "Twitter to ActivityPub bridge";
    license = licenses.agpl3Plus;
    maintainers = with maintainers; [ mvs ];
  };
}
