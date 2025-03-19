{
  lib,
  config,
  utils,
  pkgs,
  ...
}:

let
  inherit (lib)
    concatStringsSep
    flatten
    floatToString
    foldl'
    head
    isAttrs
    isDerivation
    isFloat
    isList
    length
    listToAttrs
    match
    mapAttrsToList
    nameValuePair
    removePrefix
    tail
    throwIf
    ;

  inherit (lib.options)
    showDefs
    showOption
    ;

  inherit (lib.strings)
    escapeC
    isConvertibleWithToString
    ;

  inherit (lib.path.subpath) join;

  inherit (utils) escapeSystemdPath;

  cfg = config.boot.kernel.sysfs;

  sysfsAttrs = with lib.types; nullOr (either sysfsValue (attrsOf sysfsAttrs));
  sysfsValue = lib.mkOptionType {
    name = "sysfs value";
    description = "sysfs attribute value";
    descriptionClass = "noun";
    check = v: isConvertibleWithToString v;
    merge =
      loc: defs:
      if length defs == 1 then
        (head defs).value
      else
        (foldl' (
          first: def:
          # merge definitions if they produce the same value string
          throwIf (mkValueString first.value != mkValueString def.value)
            "The option \"${showOption loc}\" has conflicting definition values:${
              showDefs [
                first
                def
              ]
            }"
            first
        ) (head defs) (tail defs)).value;
  };

  mapAttrsToListRecursive =
    fn: set:
    let
      recurse =
        p: v:
        if isAttrs v && !isDerivation v then mapAttrsToList (n: v: recurse (p ++ [ n ]) v) v else fn p v;
    in
    flatten (recurse [ ] set);

  mkPath = p: "/sys" + removePrefix "." (join p);

  mkValueString =
    v:
    # true will be converted to "1" by toString, saving one branch
    if v == false then
      "0"
    else if isFloat v then
      floatToString v # warn about loss of precision
    else if isList v then
      concatStringsSep "," (map mkValueString v)
    else
      toString v;

  paths = listToAttrs (
    mapAttrsToListRecursive (
      p: v:
      let
        path = mkPath p;
      in
      if v == null then
        [ ]
      else
        nameValuePair (escapeSystemdPath path) {
          unitConfig = {
            DefaultDependencies = false;
          };

          pathConfig.PathExists = path;
          wantedBy = [ "sysinit.target" ];
        }
    ) cfg
  );

  # escape whitespace and linebreaks, as well as the escape character itself,
  # to ensure that field boundaries are always preserved
  escapeTmpfiles = escapeC [
    "\t"
    "\n"
    "\r"
    " "
    "\\"
  ];

  services = listToAttrs (
    mapAttrsToListRecursive (
      p: v:
      let
        path = mkPath p;
        value = mkValueString v;
        escapedPath = escapeSystemdPath path;
        tmpfilesConf = pkgs.writeText "${escapedPath}.conf" ''
          w ${escapeTmpfiles path} - - - - ${escapeTmpfiles value}
        '';
      in
      if v == null then
        [ ]
      else
        nameValuePair (escapedPath) {
          unitConfig = {
            Description = "${concatStringsSep "." p} setter";
            AssertPathIsMountPoint = "/sys";
            AssertPathExistsGlob = path;
          };

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;

            # while we could be tempted to use simple shell script to set the
            # sysfs attributes specified by the path or glob pattern, it is
            # almost impossible to properly escape a glob pattern so that it
            # can be used safely in a shell script
            ExecStart = "${lib.getExe' config.systemd.package "systemd-tmpfiles"} --create ${tmpfilesConf}";

            # deny access to anything but /sys
            ProtectProc = "noaccess";
            ProtectSystem = "strict";
            PrivateDevices = true;
            SystemCallErrorNumber = "EPERM";
            SystemCallFilter = [
              "@basic-io"
              "@file-system"
            ];
          };
        }
    ) cfg
  );
in
{
  options = {
    boot.kernel.sysfs = lib.mkOption {
      type = lib.types.submodule {
        freeformType = lib.types.attrsOf sysfsAttrs // {
          description = "nested attribute set of null or sysfs attribute values";
        };
      };

      description = ''
        sysfs attributes to be set as soon as they become available.

        Attribute names represent path components in the sysfs filesystem and
        cannot be `.` or `..` nor contain any slash character (`/`).

        Names may contain shell‐style glob patterns (`*`, `?` and `[…]`)
        matching a single path component, these should however be used with
        caution, as they may produce unexpected results if attribute paths
        overlap.

        Values will be converted to strings, with list elements concatenated
        with commata and booleans converted to numeric values (`0` or `1`).

        `null` values are ignored, allowing removal of values defined in other
        modules, as are empty attribute sets.

        List values defined in different modules will _not_ be concatenated.

        This option may only be used for attributes which can be set
        idempotently, as the configured values might be written more than once.
      '';

      default = { };

      example = lib.literalExpression ''
        {
          # enable transparent hugepages with deferred defragmentaion
          kernel.mm.transparent_hugepage = {
            enabled = "always";
            defrag = "defer";
            shmem_enabled = "within_size";
          };

          devices.system.cpu = {
            # configure powesave frequency governor for all CPUs
            # the [0-9]* glob pattern ensures that other paths
            # like cpufreq or cpuidle are not matched
            "cpu[0-9]*" = {
              scaling_governor = "powersave";
              energy_performance_preference = 8;
            };

            # disable frequency boost
            intel_pstate.no_turbo = true;
          };
        }
      '';
    };
  };

  config = lib.mkIf (cfg != { }) {
    # set attributes early during boot
    boot.initrd.systemd = {
      inherit paths services;
    };

    systemd = {
      inherit paths services;
    };

    warnings = mapAttrsToListRecursive (
      p: v:
      if lib.any (n: match ''.*[*?[\]].*'' n != null) p then
        "Attribute path \"${concatStringsSep "." p}\" contains glob patterns which may produce unexpected results."
      else
        [ ]
    ) cfg;

    assertions = mapAttrsToListRecursive (p: v: {
      assertion = lib.all (n: match ''(\.\.?|.*/.*)'' n == null) p;
      message = "Attribute path \"${concatStringsSep "." p}\" has invalid components.";
    }) cfg;
  };

  meta.maintainers = with lib.maintainers; [ mvs ];
}
