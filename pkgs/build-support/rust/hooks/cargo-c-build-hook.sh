# shellcheck shell=bash disable=SC2154,SC2164

cargoCBuildHook() {
  echo "Executing cargoCBuildHook"

  # Let stdenv handle stripping.
  export "CARGO_PROFILE_${cargoBuildType@U}_STRIP"=false

  if [[ -v buildAndTestSubdir ]]; then
    local targetDir
    targetDir="$(pwd)/target"
    pushd "$buildAndTestSubdir"
  fi

  @setEnv@ cargo cbuild \
    -j "$NIX_BUILD_CORES" \
    --target "@rustcTarget@" \
    --profile "$cargoBuildType" \
    --offline \
    --library-type "@libraryType@${dontDisableStatic+,staticlib}" \
    ${targetDir+--target-dir "$targetDir"} \
    ${cargoBuildNoDefaultFeatures+--no-default-features} \
    ${cargoBuildFeatures+--features="$(concatStringsSep "," cargoBuildFeatures)"} \
    "${cargoCBuildFlags[@]}"

  if [[ -v buildAndTestSubdir ]]; then
    popd
  fi

  echo "Finished cargoCBuildHook"
}

postBuildHooks+=(cargoCBuildHook)
