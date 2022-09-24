/*
  Akkoma E2E VM test.

  Copy-edited from pleroma.nix.

  Abstract:
  =========
  Using akkoma, postgresql, a local CA cert, a nginx reverse proxy
  and a toot-based client, we're going to:

  1. Provision a akkoma service from scratch (akkoma config + postgres db).
  2. Create a "jamy" admin user.
  3. Send a toot from this user.
  4. Send a upload from this user.
  5. Check the toot is part of the server public timeline

  Notes:
  - We need a fully functional TLS setup without having any access to
    the internet. We do that by issuing a self-signed cert, add this
    self-cert to the hosts pki trust store and finally spoof the
    hostnames using /etc/hosts.
  - For this NixOS test, we *had* to store some DB-related and
    akkoma-related secrets to the store. Keep in mind the store is
    world-readable, it's the worst place possible to store *any*
    secret. **DO NOT DO THIS IN A REAL WORLD DEPLOYMENT**.
*/

import ./make-test-python.nix ({ pkgs, package ? pkgs.akkoma, ... }:
  let
  send-toot = pkgs.writeScriptBin "send-toot" ''
    set -eux
    # toot is using the requests library internally. This library
    # sadly embed its own certificate store instead of relying on the
    # system one. Overriding this pretty bad default behaviour.
    export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt

    echo "jamy-password" | toot login_cli -i "akkoma.nixos.test" -e "jamy@nixos.test"
    echo "Login OK"

    # Send a toot then verify it's part of the public timeline
    echo "y" | toot post "hello world Jamy here"
    echo "Send toot OK"
    echo "y" | toot timeline | grep -c "hello world Jamy here"
    echo "Get toot from timeline OK"

    # Test file upload
    echo "y" | toot upload ${db-seed} | grep -c "https://akkoma.nixos.test/media"
    echo "File upload OK"

    echo "====================================================="
    echo "=                   SUCCESS                         ="
    echo "=                                                   ="
    echo "=    We were able to sent a toot + a upload and     ="
    echo "=   retrieve both of them in the public timeline.   ="
    echo "====================================================="
  '';

  provision-db = pkgs.writeScriptBin "provision-db" ''
    set -eux
    sudo -u postgres psql -f ${db-seed}
  '';

  test-db-passwd = "SccZOvTGM//BMrpoQj68JJkjDkMGb4pHv2cECWiI+XhVe3uGJTLI0vFV/gDlZ5jJ";

  /* For this NixOS test, we *had* to store this secret to the store.
    Keep in mind the store is world-readable, it's the worst place
    possible to store *any* secret. **DO NOT DO THIS IN A REAL WORLD
    DEPLOYMENT**.*/
  db-seed = pkgs.writeText "provision.psql" ''
    CREATE USER akkoma WITH ENCRYPTED PASSWORD '${test-db-passwd}';
    CREATE DATABASE akkoma OWNER akkoma;
    \c akkoma;
    --Extensions made by ecto.migrate that need superuser access
    CREATE EXTENSION IF NOT EXISTS citext;
    CREATE EXTENSION IF NOT EXISTS pg_trgm;
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
  '';

  /* For this NixOS test, we *had* to store these secrets to the store.
    Keep in mind the store is world-readable, it's the worst place
    possible to store *any* secret. **DO NOT DO THIS IN A REAL WORLD
    DEPLOYMENT**.
    In a real-word deployment, you'd handle this either by:
    - manually upload your Akkoma secrets
    - use a deployment tool such as morph or NixOps to deploy your secrets.
  */
  akkoma-db-password = pkgs.writeText "akkoma-db-password" test-db-passwd;
  akkoma-secret-key-base = pkgs.writeText "akkoma-secret-key-base"
    "NvfmU7lYaQrmmxt4NACm0AaAfN9t6WxsrX0NCB4awkGHvr1S7jyshlEmrjaPFhhq";
  akkoma-live-view-signing-salt = pkgs.writeText "akkoma-live-view-signing-salt"
    "3L41+BuJ";
  akkoma-signing-salt = pkgs.writeText "akkoma-signing-salt"
    "3L41+BuJ";
  akkoma-vapid-private-key = pkgs.writeText "akkoma-vapid-private-key"
    "k7o9onKMQrgMjMb6l4fsxSaXO0BTNAer5MVSje3q60k";
  akkoma-jwt-signer = pkgs.writeText "akkoma-jwt-signer"
    "PS69/wMW7X6FIQPABt9lwvlZvgrJIncfiAMrK9J5mjVus/7/NJJi1DsDA1OghBE5";

  akkoma-conf = {
    ":pleroma" = {
      ":instance" = {
        name = "NixOS test Akkoma server";
        description = "NixOS test Akkoma server";
        email = "akkoma@nixos.test";
        notify_email = "akkoma@nixos.test";
        registration_open = true;
      };

      ":media_proxy" = {
        enabled = false;
      };

      "Pleroma.Repo" = {
        password = {
          _secret = "${akkoma-db-password}";
        };
      };

      "Pleroma.Web.Endpoint" = {
        url = {
          host = "akkoma.nixos.test";
        };

        secret_key_base = {
          _secret = "${akkoma-secret-key-base}";
        };

        live_view = {
          signing_salt = {
            _secret = "${akkoma-live-view-signing-salt}";
          };
        };

        signing_salt = {
          _secret = "${akkoma-signing-salt}";
        };
      };
    };

    ":web_push_encryption" = {
      ":vapid_details" = {
        subject = "mailto:akkoma@nixos.test";
        public_key = "BKjfNX9-UqAcncaNqERQtF7n9pKrB0-MO-juv6U5E5XQr_Tg5D-f8AlRjduAguDpyAngeDzG8MdrTejMSL4VF30";
        private_key = {
          _secret = "${akkoma-vapid-private-key}";
        };
      };
    };

    ":joken" = {
      ":default_signer" = {
        _secret = "${akkoma-jwt-signer}";
      };
    };
  };

  /* For this NixOS test, we *had* to store this secret to the store.
    Keep in mind the store is world-readable, it's the worst place
    possible to store *any* secret. **DO NOT DO THIS IN A REAL WORLD
    DEPLOYMENT**.
  */
  provision-user = pkgs.writeScriptBin "provision-user" ''
    set -eux

    # Waiting for akkoma to be up.
    timeout 5m bash -c 'while [[ "$(curl -s -o /dev/null -w '%{http_code}' https://akkoma.nixos.test/api/v1/instance)" != "200" ]]; do sleep 2; done'
    # Toremove the RELEASE_COOKIE bit when https://github.com/NixOS/nixpkgs/issues/166229 gets fixed.
    RELEASE_COOKIE="/run/akkoma/COOKIE" \
      ${package}/bin/pleroma_ctl user new jamy jamy@nixos.test --password 'jamy-password' --moderator --admin -y
  '';

  tls-cert = pkgs.runCommand "selfSignedCerts" { buildInputs = [ pkgs.openssl ]; } ''
    openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -nodes -subj '/CN=akkoma.nixos.test' -days 36500
    mkdir -p $out
    cp key.pem cert.pem $out
  '';

  hosts = nodes: ''
    ${nodes.akkoma.config.networking.primaryIPAddress} akkoma.nixos.test
    ${nodes.client.config.networking.primaryIPAddress} client.nixos.test
  '';
  in {
  name = "akkoma";
  nodes = {
    client = { nodes, pkgs, config, ... }: {
      security.pki.certificateFiles = [ "${tls-cert}/cert.pem" ];
      networking.extraHosts = hosts nodes;
      environment.systemPackages = with pkgs; [
        toot
        send-toot
      ];
    };
    akkoma = { nodes, pkgs, config, ... }: {
      security.pki.certificateFiles = [ "${tls-cert}/cert.pem" ];
      networking.extraHosts = hosts nodes;
      networking.firewall.enable = false;
      environment.systemPackages = with pkgs; [
        provision-db
        provision-user
      ];
      services = {
        akkoma = {
          enable = true;
          package = package;
          config = akkoma-conf;
        };
        postgresql = {
          enable = true;
          package = pkgs.postgresql_14;
        };
        nginx = {
          enable = true;
          virtualHosts."akkoma.nixos.test" = {
            addSSL = true;
            sslCertificate = "${tls-cert}/cert.pem";
            sslCertificateKey = "${tls-cert}/key.pem";
            locations."/" = {
              proxyPass = "http://127.0.0.1:4000";
              extraConfig = ''
                add_header 'Access-Control-Allow-Origin' '*' always;
                add_header 'Access-Control-Allow-Methods' 'POST, PUT, DELETE, GET, PATCH, OPTIONS' always;
                add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type, Idempotency-Key' always;
                add_header 'Access-Control-Expose-Headers' 'Link, X-RateLimit-Reset, X-RateLimit-Limit, X-RateLimit-Remaining, X-Request-Id' always;
                if ($request_method = OPTIONS) {
                    return 204;
                }
                add_header X-XSS-Protection "1; mode=block";
                add_header X-Permitted-Cross-Domain-Policies none;
                add_header X-Frame-Options DENY;
                add_header X-Content-Type-Options nosniff;
                add_header Referrer-Policy same-origin;
                add_header X-Download-Options noopen;
                proxy_http_version 1.1;
                proxy_set_header Upgrade $http_upgrade;
                proxy_set_header Connection "upgrade";
                proxy_set_header Host $host;
                client_max_body_size 16m;
              '';
            };
          };
        };
      };
    };
  };

  testScript = { nodes, ... }: ''
    akkoma.wait_for_unit("postgresql.service")
    akkoma.succeed("provision-db")
    akkoma.systemctl("restart akkoma.service")
    akkoma.wait_for_unit("akkoma.service")
    akkoma.succeed("provision-user")
    client.succeed("send-toot")
  '';
})
