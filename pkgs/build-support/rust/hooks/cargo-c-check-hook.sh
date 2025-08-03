# shellcheck shell=bash disable=SC2154,SC2164

cargoCCheckHook() {
  echo "Executing cargoCCheckHook"

  if [[ -v buildAndTestSubdir ]]; then
    local targetDir
    targetDir="$(pwd)/target"
    pushd "$buildAndTestSubdir"
  fi

  @setEnv@ cargo ctest \
    -j "$NIX_BUILD_CORES" \
    --target "@rustcTarget@" \
    --profile "$cargoCheckType" \
    --offline \
    ${targetDir+--target-dir "$targetDir"} \
    ${cargoCheckNoDefaultFeatures+--no-default-features} \
    ${cargoCheckFeatures+--features="$(concatStringsSep "," cargoCheckFeatures)"} \
    "${cargoCCheckFlags[@]}"

  if [[ -v buildAndTestSubdir ]]; then
    popd
  fi

  echo "Finished cargoCCheckHook"
}

postCheckHooks+=(cargoCCheckHook)
