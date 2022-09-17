{ config, lib, pkgs, ... }:

let
  cfg = config.services.birdsitelive;
  json = pkgs.formats.json { };
in
{
  options = {
    services.birdsitelive = with lib; {
      enable = mkEnableOption (lib.mdDoc "BirdsiteLIVE");

      package = mkOption {
        type = types.package;
        default = pkgs.birdsitelive;
        defaultText = literalExpression "pkgs.birdsitelive";
        description = lib.mdDoc "BirdsiteLIVE package to use.";
      };

      user = mkOption {
        type = types.str;
        default = "birdsitelive";
        description = lib.mdDoc "User account under which BirdsiteLIVE runs.";
      };

      group = mkOption {
        type = types.str;
        default = "birdsitelive";
        description = lib.mdDoc "Group account under which BirdsiteLIVE runs.";
      };

      settings = mkOption {
        default = { };
        description = lib.mdDoc ''
          Configuration for BirdsiteLIVE. The attributes are serialised to JSON, overriding defaults in
          [{file}`appsettings.json`](https://github.com/NicolasConstant/BirdsiteLive/blob/master/src/BirdsiteLive/appsettings.json).

          Refer to <https://github.com/NicolasConstant/BirdsiteLive/blob/master/VARIABLES.md> for details.

          Secrets should be passed in by using {option}`secretConfigFile`
        '';

        type = types.submodule {
          freeformType = json.type;
          options = {
            Kestrel = mkOption {
              type = json.type;
              description = lib.mdDoc ''
                Kestrel web server settings.

                Refer to
                <https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/kestrel/endpoints?view=aspnetcore-6.0#configureiconfiguration-1>
                for configuration options.
              '';
              default = {
                EndPoints = {
                  Http = {
                    Url = "http://localhost:5000";
                  };
                };
              };
            };

            Instance = mkOption {
              default = { };
              description = lib.mdDoc "Instance settings.";
              type = types.submodule {
                freeformType = json.type;
                options = {
                  Name = mkOption {
                    type = types.str;
                    default = "BirdsiteLIVE";
                    description = lib.mdDoc "Instance name.";
                  };

                  Domain = mkOption {
                    type = types.str;
                    default = config.networking.fqdn;
                    defaultText = literalExpression "config.networking.fqdn";
                    description = lib.mdDoc "Domain name of the instance.";
                  };
                };
              };
            };

            Db = mkOption {
              default = { };
              description = lib.mdDoc "Postgres database settings.";
              type = types.submodule {
                options = {
                  Host = mkOption {
                    type = types.str;
                    default = "127.0.0.1";
                    description = lib.mdDoc "Database server hostname.";
                  };

                  Name = mkOption {
                    type = types.str;
                    default = "birdsitelive";
                    description = lib.mdDoc "Database name.";
                  };

                  User = mkOption {
                    type = types.str;
                    default = cfg.user;
                    defaultText = literalExpression "config.services.birdsitelive.user";
                    description = lib.mdDoc "Database user name.";
                  };
                };
              };
            };
          };
        };
      };

      secretConfigFile = mkOption {
        type = types.str;
        default = "/var/lib/secrets/birdsitelive.json";
        description = lib.mdDoc ''
          Path to the file containing your secret BirdsiteLIVE configuration. The contents of this
          file are merged into {file}`appsettings.json`, potentially overriding any other settings.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users = {
      users."${cfg.user}" = {
        description = "BirdsiteLIVE user";
        group = cfg.group;
        isSystemUser = true;
      };
      groups."${cfg.group}" = { };
    };

    systemd.services.birdsitelive =
      let
        configFile = pkgs.writeText "appsettings.json" (builtins.toJSON cfg.settings);
        reloadScript = pkgs.writers.writeBashBin "birdsiteliveReload" ''
          set -e -u -o pipefail

          cd "''${RUNTIME_DIRECTORY}"

          ${pkgs.jq}/bin/jq -s '.[0] * .[1] * .[2]' \
            '${cfg.package}/lib/birdsitelive/appsettings.json' \
            '${configFile}' \
            '${cfg.secretConfigFile}' \
            | dd conv=fdatasync of=.appsettings.json status=none
          mv {.,}appsettings.json

          ${pkgs.jq}/bin/jq '{
              "DbType": .Db.Type,
              "DbHost": .Db.Host,
              "DbUser": .Db.User,
              "DbPassword": .Db.Password,
              "InstanceDomain": .Instance.Domain
            }' appsettings.json \
            | dd conv=fdatasync of=.ManagerSettings.json status=none
          chmod 0640 .ManagerSettings.json
          mv {.,}ManagerSettings.json
        '';
      in
      {
        description = "BirdsiteLIVE Twitter to ActivityPub bridge";
        after = [ "network-online.target" "postgresql.service" ];
        wantedBy = [ "multi-user.target" ];
        reloadTriggers = [ configFile cfg.secretConfigFile ];
        serviceConfig = {
          User = cfg.user;
          Group = cfg.group;

          RuntimeDirectory = "birdsitelive";
          RuntimeDirectoryMode = "0750";
          RuntimeDirectoryPreserve = "yes";
          WorkingDirectory = "%t/birdsitelive";

          BindReadOnlyPaths = [
            "${cfg.package}/lib/birdsitelive/wwwroot:%t/birdsitelive/wwwroot:norbind"
          ];

          ExecStartPre = "${reloadScript}/bin/birdsiteliveReload";
          ExecStart = "${cfg.package}/bin/BirdsiteLive";
          ExecReload = "${reloadScript}/bin/birdsiteliveReload";
          KillSignal = "SIGINT";

          ProtectProc = "noaccess";
          ProcSubset = "pid";
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
          PrivateIPC = true;
          ProtectHostname = true;
          ProtectClock = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;

          RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
          RestrictNamespaces = true;
          LockPersonality = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          RemoveIPC = true;

          CapabilityBoundingSet = [ "" ];
          NoNewPrivileges = true;
          SystemCallFilter = [ "@system-service" "~@privileged" ];
          SystemCallArchitectures = "native";

          UMask = "0077";
        };
      };
  };

  meta.maintainers = with lib.maintainers; [ mvs ];
}
