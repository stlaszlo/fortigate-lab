locals {
  bootstrap_config = {
    database_password        = var.database_password
    guacamole_admin_password = var.guacamole_admin_password
    cloudflare_tunnel_token  = var.cloudflare_tunnel_token
    students                 = var.student_connections
  }

  docker_compose = <<-YAML
    services:
      postgres:
        image: postgres:16-alpine
        restart: unless-stopped
        environment:
          POSTGRES_DB: guacamole
          POSTGRES_USER: guacamole
          POSTGRES_PASSWORD: $${POSTGRES_PASSWORD}
        volumes:
          - /srv/guacamole/postgres:/var/lib/postgresql/data
          - /opt/guacamole/initdb:/docker-entrypoint-initdb.d:ro
        ports:
          - "127.0.0.1:5432:5432"
        healthcheck:
          test: ["CMD-SHELL", "pg_isready -U guacamole -d guacamole"]
          interval: 5s
          timeout: 5s
          retries: 30

      guacd:
        image: guacamole/guacd:${var.guacamole_version}
        restart: unless-stopped

      guacamole:
        image: guacamole/guacamole:${var.guacamole_version}
        restart: unless-stopped
        depends_on:
          postgres:
            condition: service_healthy
          guacd:
            condition: service_started
        environment:
          GUACD_HOSTNAME: guacd
          POSTGRESQL_HOSTNAME: postgres
          POSTGRESQL_DATABASE: guacamole
          POSTGRESQL_USERNAME: guacamole
          POSTGRESQL_PASSWORD: $${POSTGRES_PASSWORD}
          WEBAPP_CONTEXT: ROOT
          REMOTE_IP_VALVE_ENABLED: "true"

      cloudflared:
        image: cloudflare/cloudflared:latest
        restart: unless-stopped
        depends_on:
          - guacamole
        command: tunnel --no-autoupdate run --token $${CLOUDFLARE_TUNNEL_TOKEN}
  YAML

  bootstrap_python = <<-PY
    #!/usr/bin/env python3
    import hashlib
    import json
    import os
    import psycopg2
    import time

    CONFIG = "/opt/guacamole/bootstrap-config.json"

    with open(CONFIG, "r", encoding="utf-8") as fh:
        cfg = json.load(fh)

    db_password = cfg["database_password"]

    conn = None
    for _ in range(60):
        try:
            conn = psycopg2.connect(
                host="127.0.0.1",
                port=5432,
                dbname="guacamole",
                user="guacamole",
                password=db_password,
            )
            break
        except psycopg2.OperationalError:
            time.sleep(2)

    if conn is None:
        raise RuntimeError("PostgreSQL did not become ready")

    conn.autocommit = False

    # PostgreSQL may accept connections briefly while the image is still
    # completing first-run initialization. Wait for Guacamole's schema.
    for _ in range(60):
        with conn.cursor() as cur:
            cur.execute("SELECT to_regclass('public.guacamole_user')")
            if cur.fetchone()[0] is not None:
                break
        conn.rollback()
        time.sleep(2)
    else:
        raise RuntimeError("Guacamole database schema did not initialize")

    def salted_hash(password: str):
        salt = os.urandom(32)
        salt_hex = salt.hex().upper().encode("ascii")
        digest = hashlib.sha256(password.encode("utf-8") + salt_hex).digest()
        return salt, digest

    def ensure_user(cur, username: str, password: str):
        cur.execute(
            """
            INSERT INTO guacamole_entity (name, type)
            SELECT %s, 'USER'
            WHERE NOT EXISTS (
              SELECT 1 FROM guacamole_entity WHERE name = %s AND type = 'USER'
            )
            """,
            (username, username),
        )
        cur.execute(
            "SELECT entity_id FROM guacamole_entity WHERE name = %s AND type = 'USER'",
            (username,),
        )
        entity_id = cur.fetchone()[0]
        cur.execute("SELECT user_id FROM guacamole_user WHERE entity_id = %s", (entity_id,))
        row = cur.fetchone()
        salt, digest = salted_hash(password)
        if row:
            cur.execute(
                """
                UPDATE guacamole_user
                   SET password_salt = %s,
                       password_hash = %s,
                       password_date = CURRENT_TIMESTAMP,
                       disabled = FALSE,
                       expired = FALSE
                 WHERE entity_id = %s
                """,
                (psycopg2.Binary(salt), psycopg2.Binary(digest), entity_id),
            )
        else:
            cur.execute(
                """
                INSERT INTO guacamole_user
                    (entity_id, password_salt, password_hash, password_date, disabled, expired)
                VALUES (%s, %s, %s, CURRENT_TIMESTAMP, FALSE, FALSE)
                """,
                (entity_id, psycopg2.Binary(salt), psycopg2.Binary(digest)),
            )
        return entity_id

    def ensure_connection_group(cur, name: str):
        cur.execute(
            """
            SELECT connection_group_id
              FROM guacamole_connection_group
             WHERE connection_group_name = %s
               AND parent_id IS NULL
            """,
            (name,),
        )
        row = cur.fetchone()
        if row:
            return row[0]

        cur.execute(
            """
            INSERT INTO guacamole_connection_group
                (parent_id, connection_group_name, type)
            VALUES
                (NULL, %s, 'ORGANIZATIONAL')
            RETURNING connection_group_id
            """,
            (name,),
        )
        return cur.fetchone()[0]

    def ensure_connection(cur, name: str, protocol: str, parameters: dict, parent_id: int):
        cur.execute(
            """
            SELECT connection_id
              FROM guacamole_connection
             WHERE connection_name = %s
               AND parent_id = %s
            """,
            (name, parent_id),
        )
        row = cur.fetchone()

        if row:
            connection_id = row[0]
            cur.execute(
                """
                UPDATE guacamole_connection
                   SET protocol = %s,
                       parent_id = %s
                 WHERE connection_id = %s
                """,
                (protocol, parent_id, connection_id),
            )
        else:
            cur.execute(
                """
                INSERT INTO guacamole_connection
                    (connection_name, protocol, parent_id)
                VALUES
                    (%s, %s, %s)
                RETURNING connection_id
                """,
                (name, protocol, parent_id),
            )
            connection_id = cur.fetchone()[0]

        cur.execute(
            "DELETE FROM guacamole_connection_parameter WHERE connection_id = %s",
            (connection_id,),
        )
        for key, value in parameters.items():
            cur.execute(
                """
                INSERT INTO guacamole_connection_parameter
                    (connection_id, parameter_name, parameter_value)
                VALUES
                    (%s, %s, %s)
                """,
                (connection_id, key, value),
            )
        return connection_id

    def ensure_rdp_connection(cur, name: str, hostname: str, username: str, password: str, parent_id: int):
        return ensure_connection(
            cur,
            name=name,
            protocol="rdp",
            parent_id=parent_id,
            parameters={
                "hostname": hostname,
                "port": "3389",
                "username": username,
                "password": password,
                "security": "any",
                "ignore-cert": "true",
                "resize-method": "display-update",
                "enable-wallpaper": "true",
            },
        )

    def ensure_ssh_connection(cur, name: str, hostname: str, username: str, password: str, parent_id: int):
        return ensure_connection(
            cur,
            name=name,
            protocol="ssh",
            parent_id=parent_id,
            parameters={
                "hostname": hostname,
                "port": "22",
                "username": username,
                "password": password,
                "enable-sftp": "true",
                "font-size": "12",
            },
        )

    def grant_connection_read(cur, entity_id: int, connection_id: int):
        cur.execute(
            """
            INSERT INTO guacamole_connection_permission
                (entity_id, connection_id, permission)
            SELECT %s, %s, 'READ'
            WHERE NOT EXISTS (
                SELECT 1
                  FROM guacamole_connection_permission
                 WHERE entity_id = %s
                   AND connection_id = %s
                   AND permission = 'READ'
            )
            """,
            (entity_id, connection_id, entity_id, connection_id),
        )

    def grant_group_read(cur, entity_id: int, group_id: int):
        cur.execute(
            """
            INSERT INTO guacamole_connection_group_permission
                (entity_id, connection_group_id, permission)
            SELECT %s, %s, 'READ'
            WHERE NOT EXISTS (
                SELECT 1
                  FROM guacamole_connection_group_permission
                 WHERE entity_id = %s
                   AND connection_group_id = %s
                   AND permission = 'READ'
            )
            """,
            (entity_id, group_id, entity_id, group_id),
        )

    with conn.cursor() as cur:
        # The official Guacamole schema creates guacadmin. Reset it to the
        # Terraform-supplied password while preserving its ADMINISTER permission.
        ensure_user(cur, "guacadmin", cfg["guacamole_admin_password"])

        for student, details in sorted(cfg["students"].items()):
            entity_id = ensure_user(cur, student, details["linux_password"])

            # student01 -> Student 01
            student_number = student.removeprefix("student")
            group_name = f"Student {student_number}"
            group_id = ensure_connection_group(cur, group_name)

            # Students see only their own folder and connections.
            grant_group_read(cur, entity_id, group_id)

            connections = [
                ensure_rdp_connection(
                    cur,
                    "01 - Client Desktop",
                    details["client_hostname"],
                    details["linux_username"],
                    details["linux_password"],
                    group_id,
                ),
                ensure_ssh_connection(
                    cur,
                    "02 - Client SSH",
                    details["client_hostname"],
                    details["linux_username"],
                    details["linux_password"],
                    group_id,
                ),
                ensure_ssh_connection(
                    cur,
                    "03 - DMZ Server SSH",
                    details["dmz_hostname"],
                    details["linux_username"],
                    details["linux_password"],
                    group_id,
                ),
                ensure_ssh_connection(
                    cur,
                    "04 - FortiGate WAN SSH",
                    details["fortigate_hostname"],
                    details["fortigate_username"],
                    details["fortigate_password"],
                    group_id,
                ),
            ]

            for connection_id in connections:
                grant_connection_read(cur, entity_id, connection_id)

    conn.commit()
    conn.close()
  PY

  start_script = <<-SH
    #!/usr/bin/env bash
    set -euo pipefail

    install -d -m 0755 /opt/guacamole/initdb /srv/guacamole/postgres
    chmod 0700 /srv/guacamole/postgres || true

    base64 -d /opt/guacamole/bootstrap-config.b64 > /opt/guacamole/bootstrap-config.json
    chmod 0600 /opt/guacamole/bootstrap-config.json

    export POSTGRES_PASSWORD
    export CLOUDFLARE_TUNNEL_TOKEN
    POSTGRES_PASSWORD="$(jq -r '.database_password' /opt/guacamole/bootstrap-config.json)"
    CLOUDFLARE_TUNNEL_TOKEN="$(jq -r '.cloudflare_tunnel_token' /opt/guacamole/bootstrap-config.json)"

    systemctl enable --now docker

    cd /opt/guacamole

    # Generate the official PostgreSQL schema only if this is a fresh database.
    if [ ! -s /opt/guacamole/initdb/001-guacamole-schema.sql ]; then
      docker run --rm guacamole/guacamole:${var.guacamole_version} \
        /opt/guacamole/bin/initdb.sh --postgresql \
        > /opt/guacamole/initdb/001-guacamole-schema.sql
    fi

    docker compose up -d postgres

    for i in $(seq 1 60); do
      if docker compose exec -T postgres pg_isready -U guacamole -d guacamole >/dev/null 2>&1; then
        break
      fi
      sleep 2
    done

    python3 /opt/guacamole/bootstrap.py
    docker compose up -d

    # Keep the bootstrap configuration root-only. It is intentionally retained
    # so the deployment can be re-run idempotently if necessary.
    chmod 0600 /opt/guacamole/bootstrap-config.json
  SH
}

resource "azurerm_network_interface" "this" {
  name                = "${var.name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "primary"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.private_ip
  }

  tags = var.tags
}

resource "azurerm_linux_virtual_machine" "this" {
  name                = var.name
  computer_name       = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size

  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  network_interface_ids = [azurerm_network_interface.this.id]

  custom_data = base64encode(<<-EOT
  #cloud-config
  ${yamlencode({
    hostname         = var.name
    manage_etc_hosts = true
    package_update   = true
    package_upgrade  = false
    packages = [
      "docker.io",
      "docker-compose-v2",
      "jq",
      "python3",
      "python3-psycopg2"
    ]
    write_files = [
      {
        path        = "/opt/guacamole/docker-compose.yml"
        owner       = "root:root"
        permissions = "0600"
        content     = local.docker_compose
      },
      {
        path        = "/opt/guacamole/bootstrap.py"
        owner       = "root:root"
        permissions = "0700"
        content     = local.bootstrap_python
      },
      {
        path        = "/opt/guacamole/bootstrap-config.b64"
        owner       = "root:root"
        permissions = "0600"
        content     = base64encode(jsonencode(local.bootstrap_config))
      },
      {
        path        = "/opt/guacamole/start.sh"
        owner       = "root:root"
        permissions = "0700"
        content     = local.start_script
      },
      {
        path        = "/etc/motd"
        owner       = "root:root"
        permissions = "0644"
        content     = "Fortinet Training Lab\nRole: Guacamole Access Gateway\nIP: ${var.private_ip}\n"
      }
    ]
    runcmd = [
      ["bash", "/opt/guacamole/start.sh"]
    ]
})}
  EOT
)

os_disk {
  caching              = "ReadWrite"
  storage_account_type = "Standard_LRS"
}

source_image_reference {
  publisher = "Canonical"
  offer     = "ubuntu-24_04-lts"
  sku       = "server"
  version   = "latest"
}

tags = var.tags
}
