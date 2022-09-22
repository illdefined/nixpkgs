{ lib
, mkYarnPackage
, fetchFromGitea, fetchYarnDeps
, jpegoptim, oxipng, nodePackages
}:

mkYarnPackage rec {
  pname = "pleroma-fe";
  version = "2022-09-10";

  src = fetchFromGitea {
    domain = "akkoma.dev";
    owner = "AkkomaGang";
    repo = pname;
    rev = "d7499a1f91fb5e4ec947445c566f8ae41cec6c72";
    hash = "sha256-I+d+oTOTNaMPkk9vdFHhm/g8EtPTZnsWv8yPUa0uNHQ=";
  };

  offlineCache = fetchYarnDeps {
    yarnLock = src + "/yarn.lock";
    hash = "sha256-UkSdVRqFp6bj7zz4ZRMD47tVpuS7x7F1MiEei+87kyg=";
  };

  extraNativeBuildInputs = [ jpegoptim oxipng nodePackages.svgo ];

  doDist = false;

  # Build scripts assume to be used within a Git repository checkout
  patchPhase = ''
    sed -E -i \
      -e '/^let commitHash =/,/;$/clet commitHash = "${builtins.substring 0 7 src.rev}";' \
      build/webpack.prod.conf.js
  '';

  configurePhase = ''
    cp -r $node_modules node_modules
    chmod +w node_modules
  '';

  buildPhase = ''
    export HOME="$PWD/tmp"
    mkdir -p "$HOME"

    NODE_OPTIONS="--openssl-legacy-provider" \
      yarn --offline run build
  '';

  installPhase = ''
    # (Losslessly) optimise compression of image artifacts
    find dist -type f -name '*.jpg' -execdir ${jpegoptim}/bin/jpegoptim -w$NIX_BUILD_CORES {} \;
    find dist -type f -name '*.png' -execdir ${oxipng}/bin/oxipng -o max -t $NIX_BUILD_CORES {} \;
    find dist -type f -name '*.svg' -execdir ${nodePackages.svgo}/bin/svgo {} \;

    mkdir -p $out
    cp -R dist/* $out
  '';

  meta = with lib; {
    description = "Frontend for Akkoma and Pleroma";
    homepage = "https://akkoma.dev/AkkomaGang/pleroma-fe/";
    license = licenses.agpl3;
    maintainers = with maintainers; [ mvs ];
  };
}
