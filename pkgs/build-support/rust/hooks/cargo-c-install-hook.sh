# shellcheck shell=bash disable=SC2154,SC2164

cargoCInstallHook() {
  echo "Executing cargoCInstallHook"

  if [[ -v buildAndTestSubdir ]]; then
    local targetDir
    targetDir="$(pwd)/target"
    pushd "$buildAndTestSubdir"
  fi

  @setEnv@ cargo cinstall \
    -j "$NIX_BUILD_CORES" \
    --target "@rustcTarget@" \
    --profile "$cargoBuildType" \
    --offline \
    --prefix "$out" \
    --libdir "${lib-$out}/lib" \
    --includedir "${dev-$out}/include" \
    --bindir "${bin-$out}" \
    --pkgconfigdir "${dev-$out}/lib/pkgconfig" \
    ${targetDir+--target-dir "$targetDir"} \
    ${cargoBuildNoDefaultFeatures+--no-default-features} \
    ${cargoBuildFeatures+--features="$(concatStringsSep "," cargoBuildFeatures)"} \
    "${cargoCInstallFlags[@]}"

  if [[ -v buildAndTestSubdir ]]; then
    popd
  fi

  echo "Finished cargoCInstallHook"
}

postInstallHooks+=(cargoCInstallHook)
