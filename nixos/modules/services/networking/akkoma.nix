{ config, lib, pkgs, ... }:

let
  cfg = config.services.akkoma;
  format = pkgs.formats.elixirConf { };
  feFormat = pkgs.formats.json { };

  isSecret = v: with builtins; isAttrs v && v ? _secret && isString v._secret;
  secret = with lib; mkOptionType {
    name = "secret";
    description = "secret value";
    descriptionClass = "noun";
    check = isSecret;
    getSubOptions = prefix: prefix ++ [ "_secret" ];
    nestedTypes = {
      _secret = types.str;
    };
  };
in
{
  options = {
    services.akkoma = with lib; {
      enable = mkEnableOption (mdDoc "Akkoma");

      package = mkOption {
        type = types.package;
        default = pkgs.akkoma;
        defaultText = literalExpression "pkgs.akkoma";
        description = mdDoc "Akkoma package to use.";
      };

      user = mkOption {
        type = types.str;
        default = "akkoma";
        description = mdDoc "User account under which Akkoma runs.";
      };

      group = mkOption {
        type = types.str;
        default = "akkoma";
        description = mdDoc "Group account under which Akkoma runs.";
      };

      stateDir = mkOption {
        type = types.str;
        default = "/var/lib/akkoma";
        readOnly = true;
        description = mdDoc "Directory where Akkoma will save uploads and static files.";
      };

      frontend = {
        package = mkOption {
          type = with types; nullOr package;
          default = pkgs.akkoma-frontends.pleroma-fe;
          defaultText = literalExpression "pkgs.akkoma-frontends.pleroma-fe";
          description = mdDoc ''
            Akkoma frontend package.

            If set to `null`, the user-managed frontend in {path}`/var/lib/akkoma/static`
            will be used.
          '';
        };

        config = mkOption {
          type = feFormat.type;
          default = { };
          description = mdDoc ''
            Frontend configuration. The attributes are serialised to JSON and merged with the
            default configuration.
          '';
        };

        styles = mkOption {
          type = feFormat.type;
          default = { };
          description = mdDoc ''
            Styles configuration. The attributes are serialised to JSON and merged with the
            default configuration.
          '';
        };

        themes = mkOption {
          type = with types; attrsOf (either str path);
          default = { };
          description = mdDoc ''
            Extra themes to include.

            The themes will be automatically added to the styles configuration.
          '';
        };

        termsOfService = mkOption {
          type = with types; nullOr (either str path);
          default = null;
          description = mdDoc ''
            Path of Terms of Service file.

            If set to `null`, the default from the frontend will be used.
          '';
        };
      };

      releaseCookie = mkOption {
        type = types.nullOr secret;
        default = null;
        example = { _secret = "/run/keys/akkoma/releaseCookie"; };
        description = mdDoc ''
          Erlang release cookie.

          If set to `null`, a random cookie will be generated.
        '';
      };

      config = mkOption {
        description = mdDoc ''
          Configuration for Akkoma. The attributes are serialised to Elixir DSL.

          Refer to <https://docs.akkoma.dev/stable/configuration/cheatsheet/> for
          configuration options.

          Settings containing secret data should be set to an attribute set containing the
          attribute `_secret` - a string pointing to a file containing the value the option
          should be set to.
        '';
        type = types.submodule {
          freeformType = format.type;
          options = {
            ":pleroma" = {
              ":instance" = {
                name = mkOption {
                  type = types.str;
                  description = mdDoc "Instance name.";
                };

                email = mkOption {
                  type = types.str;
                  description = mdDoc "Instance administrator email.";
                };

                description = mkOption {
                  type = types.str;
                  description = mdDoc "Instance description.";
                };

                static_dir = mkOption {
                  type = types.str;
                  visible = false;
                  default = "${cfg.stateDir}/static";
                };

                upload_dir = mkOption {
                  type = types.str;
                  visible = false;
                  default = "${cfg.stateDir}/uploads";
                };
              };

              "Pleroma.Repo" = {
                adapter = with format.lib; mkOption {
                  type = types.rawElixir;
                  visible = false;
                  default = mkRaw "Ecto.Adapters.Postgres";
                  description = mdDoc "Database adapter.";
                };

                username = mkOption {
                  type = types.str;
                  default = cfg.user;
                  defaultText = literalExpression "config.services.akkoma.user";
                  description = mdDoc "Database user name.";
                };

                password = mkOption {
                  type = secret;
                  example = { _secret = "/run/keys/akkoma/db-password"; };
                  description = mdDoc ''
                    Database user password.

                    The attribute `_secret` should point to a file containing the secret.
                  '';
                };

                database = mkOption {
                  type = types.str;
                  default = "akkoma";
                  description = mdDoc "Database name.";
                };

                hostname = mkOption {
                  type = types.str;
                  default = "localhost";
                  description = mdDoc "Database server hostname.";
                };
              };

              "Pleroma.Web.Endpoint" = {
                url = {
                  host = mkOption {
                    type = types.str;
                    default = config.networking.fqdn;
                    defaultText = literalExpression "config.networking.fqdn";
                    description = mdDoc "Domain name of the instance.";
                  };

                  scheme = mkOption {
                    type = types.str;
                    default = "https";
                    description = mdDoc "URL scheme.";
                  };

                  port = mkOption {
                    type = types.port;
                    default = 443;
                    description = mdDoc "External port number";
                  };
                };

                http = {
                  ip = with format.lib; mkOption {
                    type = types.tuple;
                    default = mkTuple [ 127 0 0 1 ];
                    description = mdDoc "Listener IP address";
                  };

                  port = mkOption {
                    type = types.port;
                    default = 4000;
                    description = mdDoc "Listener port number";
                  };
                };

                secret_key_base = mkOption {
                  type = secret;
                  example = { _secret = "/run/keys/akkoma/secret-key-base"; };
                  description = mdDoc ''
                    base64-encoded secret key used as a base to generate further secrets for
                    encrypting and signing data.

                    The attribute `_secret` should point to a file containing the secret.

                    This key can generated can be generated as follows:

                    ```ShellSession
                    $ dd if=/dev/urandom bs=64 count=1 iflag=fullblock status=none | base64 -w 0
                    ```
                  '';
                };

                live_view = {
                  signing_salt = mkOption {
                    type = secret;
                    example = { _secret = "/run/keys/akkoma/live-view-signing-salt"; };
                    description = mdDoc ''
                      base64-encoded LiveView signing salt.

                      The attribute `_secret` should point to a file containing the secret.

                      This salt can be generated as follows:

                      ```ShellSession
                      $ dd if=/dev/urandom bs=8 count=1 iflag=fullblock status=none | base64 -w 0
                      ```
                    '';
                  };
                };

                signing_salt = mkOption {
                  type = secret;
                  example = { _secret = "/run/keys/akkoma/signing-salt"; };
                  description = mdDoc ''
                    base64-encoded signing salt.

                    The attribute `_secret` should point to a file containing the secret.

                    This salt can be generated as follows:

                    ```ShellSession
                    $ dd if=/dev/urandom bs=8 count=1 iflag=fullblock status=none | base64 -w 0
                    ```
                  '';
                };
              };
            };

            ":web_push_encryption" = mkOption {
              description = mdDoc ''
                Web Push Notifications configuration.

                The necessary key pair can be generated as follows:

                ```ShellSession
                $ nix-shell -p nodejs --run 'npx web-push generate-vapid-keys'
                ```
              '';
              type = types.submodule {
                freeformType = format.type;
                options = {
                  ":vapid_details" = {
                    subject = mkOption {
                      type = types.str;
                      example = "mailto:fediadmin@example.com";
                      description = mdDoc "mailto URI for administrative contact.";
                    };

                    public_key = mkOption {
                      type = types.str;
                      description = mdDoc "base64-encoded public ECDH key.";
                    };

                    private_key = mkOption {
                      type = secret;
                      example = { _secret = "/run/keys/akkoma/vapid-private-key"; };
                      description = mdDoc ''
                        base64-encoded private ECDH key.

                        The attribute `_secret` should point to a file containing the secret.
                      '';
                    };
                  };
                };
              };
            };

            ":joken" = {
              ":default_signer" = mkOption {
                type = secret;
                example = { _secret = "/run/keys/akkoma/jwt-signer"; };
                description = mdDoc ''
                  base64-encoded JWT signing secret.

                  The attribute `_secret` should point to a file containing the secret.

                  This secret can be generated as follows:

                  ```ShellSession
                  $ dd if=/dev/urandom bs=64 count=1 iflag=fullblock status=none | base64 -w 0
                  ```
                '';
              };
            };

            ":tzdata" = {
              ":data_dir" = mkOption {
                type = types.str;
                internal = true;
                default = "${cfg.stateDir}/elixir_tzdata_data";
                defaultText = literalExpression ''
                  "''${config.services.akkoma.stateDir}/elixir_tzdata_data"
                '';
              };
            };
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    users = {
      users."${cfg.user}" = {
        description = "Akkoma user";
        group = cfg.group;
        isSystemUser = true;
      };
      groups."${cfg.group}" = { };
    };

    systemd.services.akkoma =
      let
        replaceSec =
          let
            replaceSec' = {}@args: v: with builtins;
              if isSecret v then
                hashString "sha256" v._secret
              else if isAttrs v then
                listToAttrs
                  (lib.mapAttrsToList
                    (key: val: { name = key; value = replaceSec' args val; })
                    v)
              else if isList v then
                map (replaceSec' args) v
              else
                v;
          in
          replaceSec' { };

        mergeFeConfig = name: value: pkgs.runCommand name
          {
            value = builtins.toJSON value;
            passAsFile = [ "value" ];
          } ''
          ${pkgs.jq}/bin/jq -s add \
            ${lib.escapeShellArg cfg.frontend.package}/${lib.escapeShellArg name} \
            "$valuePath" >$out
        '';

        styles = cfg.frontend.styles // builtins.mapAttrs
          (name: _: "/static/themes/${name}.json")
          cfg.frontend.themes;

        frontendOverlays =
          lib.optional (cfg.frontend.package != null)
            "${cfg.frontend.package}:${cfg.stateDir}/static:norbind"
          ++ lib.optional (cfg.frontend.config != { })
            "${mergeFeConfig "config.json" cfg.frontend.config}:${cfg.stateDir}/static/config.json:norbind"
          ++ lib.optional (styles != { })
            "${mergeFeConfig "styles.json" styles}:${cfg.stateDir}/static/styles.json:norbind"
          ++ lib.optional (cfg.frontend.termsOfService != null)
            "{cfg.termsOfService}:${cfg.stateDir}/static/terms-of-service.html:norbind"
          ++ lib.mapAttrsToList
            (name: path:
              "${path}:${cfg.stateDir}/static/themes/${name}.json:norbind")
            cfg.frontend.themes;

        configFile = format.generate "config.exs" (replaceSec cfg.config);
        secretPaths = lib.catAttrs "_secret" (lib.collect isSecret cfg.config);
        mkSecretReplacement = file: with builtins; ''
          ${pkgs.replace-secret}/bin/replace-secret ${lib.escapeShellArgs [
            (hashString "sha256" file) file ".config.exs" ]}
        '';

        genScript = pkgs.writers.writeBashBin "akkomaGenCookie" ''
          set -e -u -o pipefail

          dd if=/dev/urandom bs=16 count=1 iflag=fullblock status=none \
            | ${pkgs.util-linux}/bin/hexdump -e '16/1 "%02x"' \
            >"''${RUNTIME_DIRECTORY}/COOKIE"
        '';

        copyScript = pkgs.writers.writeBashBin "akkomaCopyCookie" ''
          set -e -u -o pipefail

          install \
            -m 0640 \
            -g ${lib.escapeShellArg cfg.group} \
            ${lib.escapeShellArg cfg.releaseCookie._secret} \
            >"''${RUNTIME_DIRECTORY}/COOKIE"
        '';

        reloadScript = pkgs.writers.writeBashBin "akkomaReload" ''
          set -e -u -o pipefail

          cd "''${RUNTIME_DIRECTORY}"

          cp ${lib.escapeShellArg configFile} .config.exs
          ${lib.concatMapStrings mkSecretReplacement secretPaths}

          chgrp ${lib.escapeShellArg cfg.group} .config.exs
          chmod 0640 .config.exs
          mv {.,}config.exs
        '';
      in
      {
        description = "Akkoma social network";
        after = [ "network-online.target" "postgresql.service" ];
        wantedBy = [ "multi-user.target" ];
        reloadTriggers = [ configFile ] ++ secretPaths;

        environment = {
          AKKOMA_CONFIG_PATH = "%t/akkoma/config.exs";
          RELEASE_COOKIE = "%t/akkoma/COOKIE";
        };

        serviceConfig = {
          Type = "exec";
          User = cfg.user;
          Group = cfg.group;

          RuntimeDirectory = "akkoma";
          RuntimeDirectoryMode = "0700";
          StateDirectory = "akkoma akkoma/static akkoma/uploads";
          StateDirectoryMode = "0700";
          WorkingDirectory = "~";

          BindReadOnlyPaths = frontendOverlays;

          ExecStartPre =
            (if cfg.releaseCookie == null
            then [ "${genScript}/bin/akkomaGenCookie" ]
            else [ "+${copyScript}/bin/akkomaCopyCookie" ])
            ++ [
              "+${reloadScript}/bin/akkomaReload"
              "${cfg.package}/bin/pleroma_ctl migrate"
            ];

          ExecStart = "${cfg.package}/bin/pleroma start";
          ExecStop = "${cfg.package}/bin/pleroma stop";
          ExecReload = "+${reloadScript}/bin/akkomaReload; ${pkgs.coreutils}/bin/kill -HUP $MAINPID";

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

          RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
          RestrictNamespaces = true;
          LockPersonality = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          RemoveIPC = true;

          CapabilityBoundingSet = [ "" ];
          NoNewPrivileges = true;
          SystemCallFilter = [ "@system-service" "~@privileged" "@chown" ];
          SystemCallArchitectures = "native";

          UMask = "0077";
        };
      };
  };

  meta.maintainers = with lib.maintainers; [ mvs ];
}
