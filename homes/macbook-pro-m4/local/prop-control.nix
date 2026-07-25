{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;

  cfg = config.services.propControl;
  stateDir = "${config.xdg.stateHome}/prop-control";
  postgresDir = "${stateDir}/postgres";
  postgresSocketDir = "${stateDir}/postgres-socket";
  pkiDir = "${stateDir}/pki";
  envFile = "${stateDir}/control.env";
  logDir = "${stateDir}/logs";

  caddyConfig = pkgs.writeText "prop-control.Caddyfile" ''
    {
      admin off
      auto_https off
      servers {
        protocols h1 h2
        # The agent deliberately uses the fixed host-only IP address instead
        # of a DNS name. This is safe here because this listener has one mTLS
        # protected site only; there is no second virtual host to front.
        strict_sni_host insecure_off
      }
    }

    # This listener exists solely on VMware Fusion's host-only adapter. The
    # client certificate is required before a request can reach the API.
    https://${cfg.hostOnlyAddress}:${toString cfg.agentPort} {
      bind ${cfg.hostOnlyAddress}
      tls ${pkiDir}/server.crt ${pkiDir}/server.key {
        client_auth {
          trust_pool file ${pkiDir}/ca.crt
          mode require_and_verify
        }
      }
      reverse_proxy 127.0.0.1:${toString cfg.apiPort}
    }
  '';

  controlEnvironment = ''
    set -eu
    # The file is created by the Nix activation step with mode 0600. It holds
    # the database password and the browser API token, never the NT bridge
    # secret (which remains in the Windows user's DPAPI state).
    # shellcheck disable=SC1091
    . ${lib.escapeShellArg envFile}
    export PROP_CONTROL_DATABASE_URL PROP_CONTROL_AUTH_TOKEN
    export PGPASSWORD="$PROP_CONTROL_DB_PASSWORD"
  '';

  postgres = pkgs.writeShellApplication {
    name = "prop-control-postgres";
    runtimeInputs = [ pkgs.postgresql_16 ];
    text = ''
      set -eu
      ${controlEnvironment}
      mkdir -p ${lib.escapeShellArg postgresSocketDir}
      chmod 700 ${lib.escapeShellArg postgresSocketDir}
      exec postgres \
        -D ${lib.escapeShellArg postgresDir} \
        -h 127.0.0.1 \
        -k ${lib.escapeShellArg postgresSocketDir} \
        -p ${toString cfg.postgresPort}
    '';
  };

  api = pkgs.writeShellApplication {
    name = "prop-control-api";
    runtimeInputs = [
      pkgs.postgresql_16
      pkgs.uv
    ];
    text = ''
      set -eu
      ${controlEnvironment}
      export UV_PROJECT_ENVIRONMENT=${lib.escapeShellArg "${stateDir}/venv"}
      export UV_CACHE_DIR=${lib.escapeShellArg "${stateDir}/uv-cache"}
      export PROP_CONTROL_BIND_HOST=127.0.0.1
      export PROP_CONTROL_PORT=${toString cfg.apiPort}
      export PROP_CONTROL_CORS_ORIGINS=http://127.0.0.1:${toString cfg.frontendPort}
      export PROP_CONTROL_ALLOW_LIVE=false

      until pg_isready -h 127.0.0.1 -p ${toString cfg.postgresPort} -U prop_control; do
        sleep 1
      done

      if ! psql -h 127.0.0.1 -p ${toString cfg.postgresPort} -U prop_control -d postgres -tAc \
        "SELECT 1 FROM pg_roles WHERE rolname = 'prop_control_app'" | grep -qx 1; then
        # The password is generated as lowercase hexadecimal, so it is safe
        # to interpolate into this quoted SQL literal.
        psql -h 127.0.0.1 -p ${toString cfg.postgresPort} -U prop_control -d postgres \
          -c "CREATE ROLE prop_control_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD '$PROP_CONTROL_APP_PASSWORD'"
      fi

      if ! psql -h 127.0.0.1 -p ${toString cfg.postgresPort} -U prop_control -d postgres -tAc \
        "SELECT 1 FROM pg_database WHERE datname = 'prop_control'" | grep -qx 1; then
        createdb -h 127.0.0.1 -p ${toString cfg.postgresPort} -U prop_control -O prop_control_app prop_control
      fi
      psql -h 127.0.0.1 -p ${toString cfg.postgresPort} -U prop_control -d postgres \
        -c "ALTER DATABASE prop_control OWNER TO prop_control_app"
      psql -h 127.0.0.1 -p ${toString cfg.postgresPort} -U prop_control -d prop_control <<'SQL'
      ALTER SCHEMA public OWNER TO prop_control_app;
      DO $$
      DECLARE object_record record;
      BEGIN
        FOR object_record IN
          SELECT class.relkind, namespace.nspname, class.relname
          FROM pg_class AS class
          INNER JOIN pg_namespace AS namespace ON namespace.oid = class.relnamespace
          WHERE namespace.nspname = 'public'
            AND pg_get_userbyid(class.relowner) = 'prop_control'
            AND class.relkind IN ('r', 'S')
        LOOP
          IF object_record.relkind = 'r' THEN
            EXECUTE format(
              'ALTER TABLE %I.%I OWNER TO prop_control_app',
              object_record.nspname,
              object_record.relname
            );
          ELSE
            EXECUTE format(
              'ALTER SEQUENCE %I.%I OWNER TO prop_control_app',
              object_record.nspname,
              object_record.relname
            );
          END IF;
        END LOOP;
      END $$;
      SQL

      cd ${lib.escapeShellArg cfg.projectDirectory}
      uv run --locked alembic -c alembic.ini upgrade head
      exec uv run --locked prop-control-api
    '';
  };

  worker = pkgs.writeShellApplication {
    name = "prop-calculation-worker";
    runtimeInputs = [ pkgs.uv ];
    text = ''
      set -eu
      ${controlEnvironment}
      export UV_PROJECT_ENVIRONMENT=${lib.escapeShellArg "${stateDir}/venv"}
      export UV_CACHE_DIR=${lib.escapeShellArg "${stateDir}/uv-cache"}
      export PROP_CALC_RESERVED_CORES=${toString cfg.reservedCores}
      cd ${lib.escapeShellArg cfg.projectDirectory}
      exec uv run --locked prop-calculation-worker
    '';
  };

  frontend = pkgs.writeShellApplication {
    name = "prop-control-frontend";
    runtimeInputs = [
      pkgs.nodejs_24
      pkgs.pnpm
    ];
    text = ''
      set -eu
      cd ${lib.escapeShellArg cfg.projectDirectory}
      if [ ! -d frontend/node_modules/.pnpm ]; then
        pnpm --dir frontend install --frozen-lockfile
      fi
      export VITE_CONTROL_API_URL=
      exec pnpm --dir frontend dev --host 127.0.0.1
    '';
  };

  caddy = pkgs.writeShellApplication {
    name = "prop-control-caddy";
    runtimeInputs = [ pkgs.caddy ];
    text = ''
      set -eu
      exec caddy run --config ${lib.escapeShellArg caddyConfig} --adapter caddyfile
    '';
  };

  status = pkgs.writeShellApplication {
    name = "prop-control-status";
    runtimeInputs = [
      pkgs.curl
      pkgs.postgresql_16
      pkgs.lsof
    ];
    text = ''
      set -eu
      ${controlEnvironment}
      export PGPASSWORD="$PROP_CONTROL_DB_PASSWORD"
      printf 'PostgreSQL: '
      pg_isready -h 127.0.0.1 -p ${toString cfg.postgresPort} -U prop_control
      printf '\nControl API: '
      curl --fail --silent http://127.0.0.1:${toString cfg.apiPort}/v1/health
      printf '\n\nListeners:\n'
      lsof -nP -iTCP:${toString cfg.frontendPort} -iTCP:${toString cfg.apiPort} -iTCP:${toString cfg.agentPort} -sTCP:LISTEN || true
      printf '\nVM agent endpoint: https://${cfg.hostOnlyAddress}:${toString cfg.agentPort}\n'
    '';
  };
in
{
  options.services.propControl = {
    enable = lib.mkEnableOption "local Prop Fund control host";

    projectDirectory = lib.mkOption {
      type = lib.types.path;
      default = "/Users/ianmh/Developer/personal/prop-fund-research";
      description = "Checked-out Prop Fund Research repository used by the local services.";
    };

    hostOnlyAddress = lib.mkOption {
      type = lib.types.str;
      default = "172.16.42.1";
      description = "Mac address on the VMware Fusion host-only network.";
    };

    frontendPort = lib.mkOption {
      type = lib.types.port;
      default = 5173;
    };

    apiPort = lib.mkOption {
      type = lib.types.port;
      default = 8788;
    };

    agentPort = lib.mkOption {
      type = lib.types.port;
      default = 8443;
    };

    postgresPort = lib.mkOption {
      type = lib.types.port;
      default = 5432;
    };

    reservedCores = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = isDarwin;
        message = "services.propControl is implemented for the local macOS control host.";
      }
    ];

    home.packages = [ status ];

    home.activation.propControlState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            set -eu
            umask 0077
            mkdir -p \
              ${lib.escapeShellArg stateDir} \
              ${lib.escapeShellArg postgresSocketDir} \
              ${lib.escapeShellArg pkiDir} \
              ${lib.escapeShellArg logDir}
            chmod 700 \
              ${lib.escapeShellArg stateDir} \
              ${lib.escapeShellArg postgresSocketDir} \
              ${lib.escapeShellArg pkiDir} \
              ${lib.escapeShellArg logDir}

      if [ ! -s ${lib.escapeShellArg envFile} ]; then
        db_password="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
        app_password="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
        api_token="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
        {
          printf 'PROP_CONTROL_DB_PASSWORD=%s\n' "$db_password"
          printf 'PROP_CONTROL_APP_PASSWORD=%s\n' "$app_password"
          printf 'PROP_CONTROL_DATABASE_URL=postgresql://prop_control_app:%s@127.0.0.1:${toString cfg.postgresPort}/prop_control\n' "$app_password"
          printf 'PROP_CONTROL_AUTH_TOKEN=%s\n' "$api_token"
        } > ${lib.escapeShellArg envFile}
        chmod 600 ${lib.escapeShellArg envFile}
      fi

      # The first version of this local setup used the initdb bootstrap role
      # directly. Upgrade existing state in place to the least-privileged app
      # role without rotating the browser token or database data.
      if ! ${pkgs.gnugrep}/bin/grep -q '^PROP_CONTROL_APP_PASSWORD=' ${lib.escapeShellArg envFile}; then
        app_password="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
        {
          printf 'PROP_CONTROL_APP_PASSWORD=%s\n' "$app_password"
          printf 'PROP_CONTROL_DATABASE_URL=postgresql://prop_control_app:%s@127.0.0.1:${toString cfg.postgresPort}/prop_control\n' "$app_password"
        } >> ${lib.escapeShellArg envFile}
      fi

      if [ ! -f ${lib.escapeShellArg "${postgresDir}/PG_VERSION"} ]; then
        password_file="$(${pkgs.coreutils}/bin/mktemp ${lib.escapeShellArg "${stateDir}/postgres-password.XXXXXX"})"
        . ${lib.escapeShellArg envFile}
        printf '%s' "$PROP_CONTROL_DB_PASSWORD" > "$password_file"
              chmod 600 "$password_file"
              ${pkgs.postgresql_16}/bin/initdb \
                -D ${lib.escapeShellArg postgresDir} \
                -U prop_control \
          --pwfile="$password_file" \
          --auth-local=scram-sha-256 \
          --auth-host=scram-sha-256
        ${pkgs.coreutils}/bin/rm -f "$password_file"
            fi

            if [ ! -f ${lib.escapeShellArg "${pkiDir}/ca.crt"} ]; then
              ${pkgs.openssl}/bin/openssl req -x509 -new -nodes -sha256 -days 3650 \
                -newkey rsa:3072 \
                -keyout ${lib.escapeShellArg "${pkiDir}/ca.key"} \
                -out ${lib.escapeShellArg "${pkiDir}/ca.crt"} \
                -subj '/CN=Prop Fund local control CA' \
                -addext 'basicConstraints=critical,CA:TRUE' \
                -addext 'keyUsage=critical,keyCertSign,cRLSign'
              chmod 600 ${lib.escapeShellArg "${pkiDir}/ca.key"}
              chmod 644 ${lib.escapeShellArg "${pkiDir}/ca.crt"}
            fi

      if [ ! -f ${lib.escapeShellArg "${pkiDir}/server.crt"} ]; then
        certificate_extensions="$(${pkgs.coreutils}/bin/mktemp ${lib.escapeShellArg "${stateDir}/server-ext.XXXXXX"})"
        cat > "$certificate_extensions" <<'EOF'
      basicConstraints=critical,CA:FALSE
      keyUsage=critical,digitalSignature,keyEncipherment
      extendedKeyUsage=serverAuth
      subjectAltName=IP:${cfg.hostOnlyAddress}
      EOF
              ${pkgs.openssl}/bin/openssl req -new -nodes -newkey rsa:3072 \
                -keyout ${lib.escapeShellArg "${pkiDir}/server.key"} \
                -out ${lib.escapeShellArg "${pkiDir}/server.csr"} \
                -subj '/CN=${cfg.hostOnlyAddress}'
              ${pkgs.openssl}/bin/openssl x509 -req -sha256 -days 825 \
                -in ${lib.escapeShellArg "${pkiDir}/server.csr"} \
                -CA ${lib.escapeShellArg "${pkiDir}/ca.crt"} \
                -CAkey ${lib.escapeShellArg "${pkiDir}/ca.key"} \
                -CAcreateserial \
          -out ${lib.escapeShellArg "${pkiDir}/server.crt"} \
          -extfile "$certificate_extensions"
        ${pkgs.coreutils}/bin/rm -f "$certificate_extensions"
        chmod 600 ${lib.escapeShellArg "${pkiDir}/server.key"}
              chmod 644 ${lib.escapeShellArg "${pkiDir}/server.crt"}
            fi

      if [ ! -f ${lib.escapeShellArg "${pkiDir}/prop-vm-agent.pfx"} ]; then
        certificate_extensions="$(${pkgs.coreutils}/bin/mktemp ${lib.escapeShellArg "${stateDir}/agent-ext.XXXXXX"})"
        cat > "$certificate_extensions" <<'EOF'
      basicConstraints=critical,CA:FALSE
      keyUsage=critical,digitalSignature,keyEncipherment
      extendedKeyUsage=clientAuth
      EOF
              ${pkgs.openssl}/bin/openssl req -new -nodes -newkey rsa:3072 \
                -keyout ${lib.escapeShellArg "${pkiDir}/prop-vm-agent.key"} \
                -out ${lib.escapeShellArg "${pkiDir}/prop-vm-agent.csr"} \
                -subj '/CN=prop-vm-agent'
              ${pkgs.openssl}/bin/openssl x509 -req -sha256 -days 825 \
                -in ${lib.escapeShellArg "${pkiDir}/prop-vm-agent.csr"} \
                -CA ${lib.escapeShellArg "${pkiDir}/ca.crt"} \
                -CAkey ${lib.escapeShellArg "${pkiDir}/ca.key"} \
                -CAcreateserial \
                -out ${lib.escapeShellArg "${pkiDir}/prop-vm-agent.crt"} \
                -extfile "$certificate_extensions"
              ${pkgs.openssl}/bin/openssl pkcs12 -export \
                -out ${lib.escapeShellArg "${pkiDir}/prop-vm-agent.pfx"} \
                -inkey ${lib.escapeShellArg "${pkiDir}/prop-vm-agent.key"} \
                -in ${lib.escapeShellArg "${pkiDir}/prop-vm-agent.crt"} \
          -certfile ${lib.escapeShellArg "${pkiDir}/ca.crt"} \
          -passout pass:
        ${pkgs.coreutils}/bin/rm -f "$certificate_extensions"
              chmod 600 ${lib.escapeShellArg "${pkiDir}/prop-vm-agent.key"} ${lib.escapeShellArg "${pkiDir}/prop-vm-agent.pfx"}
              chmod 644 ${lib.escapeShellArg "${pkiDir}/prop-vm-agent.crt"}
            fi
    '';

    launchd.agents.prop-control-postgres = {
      enable = true;
      config = {
        Label = "dev.ianmh.prop-control-postgres";
        ProgramArguments = [ "${postgres}/bin/prop-control-postgres" ];
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 10;
        ProcessType = "Background";
        StandardOutPath = "${logDir}/postgres.out.log";
        StandardErrorPath = "${logDir}/postgres.err.log";
      };
    };

    launchd.agents.prop-control-api = {
      enable = true;
      config = {
        Label = "dev.ianmh.prop-control-api";
        ProgramArguments = [ "${api}/bin/prop-control-api" ];
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 10;
        ProcessType = "Background";
        StandardOutPath = "${logDir}/api.out.log";
        StandardErrorPath = "${logDir}/api.err.log";
      };
    };

    launchd.agents.prop-control-worker = {
      enable = true;
      config = {
        Label = "dev.ianmh.prop-control-worker";
        ProgramArguments = [ "${worker}/bin/prop-calculation-worker" ];
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 10;
        ProcessType = "Background";
        StandardOutPath = "${logDir}/worker.out.log";
        StandardErrorPath = "${logDir}/worker.err.log";
      };
    };

    launchd.agents.prop-control-frontend = {
      enable = true;
      config = {
        Label = "dev.ianmh.prop-control-frontend";
        ProgramArguments = [ "${frontend}/bin/prop-control-frontend" ];
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 10;
        ProcessType = "Background";
        StandardOutPath = "${logDir}/frontend.out.log";
        StandardErrorPath = "${logDir}/frontend.err.log";
      };
    };

    launchd.agents.prop-control-caddy = {
      enable = true;
      config = {
        Label = "dev.ianmh.prop-control-caddy";
        ProgramArguments = [ "${caddy}/bin/prop-control-caddy" ];
        RunAtLoad = true;
        KeepAlive = true;
        ThrottleInterval = 10;
        ProcessType = "Background";
        StandardOutPath = "${logDir}/caddy.out.log";
        StandardErrorPath = "${logDir}/caddy.err.log";
      };
    };
  };
}
