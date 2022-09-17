{ config, lib, pkgs, ... }:

let
  cfg = config.services.birdsitelive;
  json = pkgs.formats.json { };
  isSecret = v: isAttrs v && v ? _secret && isString v._secret;
  toJson = lib.generators.toJSON {
    mkKeyValue = lib.flip lib.generators.mkKeyValueDefault "=" {
      mkValueString = v:
        if isSecret v
        then hashString "sha256" v._secret
        else builtins.toJSON v;
    };
  };
  inherit (builtins) isAttrs isList isString hashString;
in
{
  options = {
    services.birdsitelive = with lib; {
      enable = mkEnableOption (mdDoc "BirdsiteLIVE");

      package = mkOption {
        type = types.package;
        default = pkgs.birdsitelive;
        defaultText = literalExpression "pkgs.birdsitelive";
        description = mdDoc "BirdsiteLIVE package to use.";
      };

      user = mkOption {
        type = types.str;
        default = "birdsitelive";
        description = mdDoc "User account under which BirdsiteLIVE runs.";
      };

      group = mkOption {
        type = types.str;
        default = "birdsitelive";
        description = mdDoc "Group account under which BirdsiteLIVE runs.";
      };

      settings = mkOption {
        default = { };
        description = mdDoc ''
          Configuration for BirdsiteLIVE. The attributes are serialised to JSON.

          Refer to <https://github.com/NicolasConstant/BirdsiteLive/blob/master/VARIABLES.md> for
          details.

          Settings containing secret data should be set to an attribute set containing the attribute
          `_secret` - a string pointing to a file containing the value the option should be set to.
        '';

        type = types.submodule {
          freeformType = json.type;
          options = {
            Logging = mkOption {
              type = json.type;
              description = mdDoc ''
                Logging settings.

                Refer to
                <https://learn.microsoft.com/en-us/aspnet/core/fundamentals/logging/?view=aspnetcore-6.0>
                for configuration options.
              '';
              default = {
                Type = "none";
                InstrumentationKey = "key";
                ApplicationInsights = {
                  LogLevel = {
                    Default = "Warning";
                  };
                };
                LogLevel = {
                  Default = "Information";
                  Microsoft = "Warning";
                  "Microsoft.Hosting.Lifetime" = "Information";
                };
              };
            };

            AllowedHosts = mkOption {
              type = types.listOf types.str;
              default = [
                "localhost"
                cfg.settings.Instance.Domain
              ];
              defaultText = literalExpression ''
                [
                  "localhost"
                  config.services.birdsitelive.settings.Instance.Domain
                ];
              '';
              description = mdDoc "List of allowed host name patterns.";
              apply = x: if isList x then concatStringSep ";" x else x;
            };

            Kestrel = mkOption {
              type = json.type;
              description = mdDoc ''
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

            Instance = {
              Name = mkOption {
                type = types.str;
                default = "BirdsiteLIVE";
                description = mdDoc "Instance name.";
              };

              Domain = mkOption {
                type = types.str;
                default = config.networking.fqdn;
                defaultText = literalExpression "config.networking.fqdn";
                description = mdDoc "Domain name of the instance.";
              };

              AdminEmail = mkOption {
                type = types.str;
                description = mdDoc "Instance administrator email address.";
              };

              ResolveMentionsInProfiles = mkOption {
                type = types.bool;
                default = true;
                description = mdDoc "Whether to enable mentions parsing in Twitter profile descriptions.";
              };

              PublishReplies = mkOption {
                type = types.bool;
                default = false;
                description = mdDoc "Whether to publish replies.";
              };

              UnlistedTwitterAccounts = mkOption {
                type = types.listOf types.str;
                description = mdDoc "List of Twitter account for which to enable unlisted publication.";
                apply = x: if isList x then concatStringSep ";" x else x;
              };

              SensitiveTwitterAccounts = mkOption {
                type = types.listOf types.str;
                description = mdDoc "List of Twitter account to mark all media from as sensitive by default.";
                apply = x: if isList x then concatStringSep ";" x else x;
              };

              FailingTwitterUserCleanUpThreshold = mkOption {
                type = types.int;
                default = 700;
                description = mdDoc "Maximum error count before auto-removal of a Twitter account.";
              };

              FailingFollowerCleanUpThreshold = mkOption {
                type = types.int;
                default = 30000;
                description = mdDoc "Maximum error count before auto-removal of a Fediverse account.";
              };

              UserCacheCapacity = mkOption {
                type = types.int;
                default = 10000;
                description = mdDoc "Caching limit for Twitter user retrieval.";
              };
            };

            Db = {
              Host = mkOption {
                type = types.str;
                default = "localhost";
                description = mdDoc "Database server hostname.";
              };

              Name = mkOption {
                type = types.str;
                default = "birdsitelive";
                description = mdDoc "Database name.";
              };

              User = mkOption {
                type = types.str;
                default = cfg.user;
                defaultText = literalExpression "config.services.birdsitelive.user";
                description = mdDoc "Database user name.";
              };

              Password = mkOption {
                type = types.str;
                default = null;
                defaultText = literalExpression "null";
                description = mdDoc ''
                  Database user password.

                  Always handled as a secret whether the value is wrapped in a `{ _secret = ...; }`
                  attrset or not.
                '';
                apply = x: if isAttrs x || x == null then x else { _secret = x; };
              };
            };

            Twitter = {
              ConsumerKey = mkOption {
                type = types.str;
                description = mdDoc "Twitter API key";
              };

              ConsumerSecret = mkOption {
                type = types.str;
                description = mdDoc ''
                  Twitter API secret

                  Always handled as a secret whether the value is wrapped in a `{ _secret = ...; }`
                  attrset or not.
                '';
                apply = x: if isAttrs x || x == null then x else { _secret = x; };
              };
            };

            Moderation = {
              FollowersWhiteListing = mkOption {
                type = types.listOf types.str;
                description = mdDoc "List of Fediverse user or instance patterns to allow as followers.";
                apply = x: if isList x then concatStringSep ";" x else x;
              };

              FollowersBlackListing = mkOption {
                type = types.listOf types.str;
                description = mdDoc "List of Fediverse user or instance patterns to disallow as followers.";
                apply = x: if isList x then concatStringSep ";" x else x;
              };

              TwitterAccountsWhiteListing = mkOption {
                type = types.listOf types.str;
                description = mdDoc "List of Twitter handles to allow following.";
                apply = x: if isList x then concatStringSep ";" x else x;
              };

              TwitterAccountsBlackListing = mkOption {
                type = types.listOf types.str;
                description = mdDoc "List of Twitter handles to disallow following.";
                apply = x: if isList x then concatStringSep ";" x else x;
              };
            };
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    warnings = let mod = cfg.settings.Moderation; in
      if mod.FollowersWhiteListing != null && mod.FollowersBlackListing != null ||
        mod.TwitterAccountsWhiteListing != null && mod.TwitterAccountsBlackListing != null
      then [ ''
        If both both a whitelist and a blacklist are set for Fediverse or Twitter
        accounts, only the whitelist will be used.
      '' ]
      else [ ];

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
        configFile = pkgs.writeText "appsettings.json" (toJson cfg.settings);
        secretPaths = lib.catAttrs "_secret" (lib.collect isSecret cfg.settings);
        mkSecretReplacement = file: ''
          replace-secret ${lib.escapeShellArgs [ (hashString "sha256" file) file ".appsettings.json" ]}
        '';
        secretReplacements = lib.concatMapStrings mkSecretReplacement secretPaths;
        reloadScript = pkgs.writers.writeBashBin "birdsiteliveReload" ''
          set -e -u -o pipefail

          cd "''${RUNTIME_DIRECTORY}"

          cp ${lib.escapeShellArgs [ configFile ]} .appsettings.json
          ${secretReplacements}
          mv {.,}appsettings.json

          ${pkgs.jq}/bin/jq '{
              "DbType": .Db.Type,
              "DbHost": .Db.Host,
              "DbUser": .Db.User,
              "DbPassword": .Db.Password,
              "InstanceDomain": .Instance.Domain
            }' appsettings.json \
            >.ManagerSettings.json
          chmod 0640 .ManagerSettings.json
          mv {.,}ManagerSettings.json
        '';
      in
      {
        description = "BirdsiteLIVE Twitter to ActivityPub bridge";
        after = [ "network-online.target" "postgresql.service" ];
        wantedBy = [ "multi-user.target" ];
        reloadTriggers = [ configFile ] ++ secretPaths;
        serviceConfig = {
          User = cfg.user;
          Group = cfg.group;

          RuntimeDirectory = "birdsitelive";
          RuntimeDirectoryMode = "0750";
          WorkingDirectory = "%t/birdsitelive";

          BindReadOnlyPaths = [
            "${cfg.package}/lib/birdsitelive/wwwroot:%t/birdsitelive/wwwroot:norbind"
          ];

          ExecStartPre = "+${reloadScript}/bin/birdsiteliveReload";
          ExecStart = "${cfg.package}/bin/BirdsiteLive";
          ExecReload = "+${reloadScript}/bin/birdsiteliveReload";
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
