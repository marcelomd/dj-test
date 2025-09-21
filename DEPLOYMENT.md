# VPS Deployment Guide (Fedora + Caddy)

This guide explains how to deploy your Django project to a Fedora VPS using Caddy server with automatic updates via GitHub Actions.

## VPS Setup

### 1. Initial Server Setup

```bash
# Update system
sudo dnf update -y

# Install required packages
sudo dnf install -y python3-pip python3-virtualenv postgresql17 postgresql17-server postgresql17-contrib postgresql17-devel postgresql17-server-devel python3-devel gcc git caddy
```


### 2. Database Setup

```bash
# Initialize PostgreSQL database
sudo postgresql-setup --initdb
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Switch to postgres user
sudo -u postgres psql

# Create database and user
CREATE DATABASE tpdb_db;
CREATE USER tpdb_user WITH PASSWORD 'your-password';
ALTER ROLE tpdb_user SET client_encoding TO 'utf8';
ALTER ROLE tpdb_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE tpdb_user SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE tpdb_db TO tpdb_user;
ALTER DATABASE tpdb_db OWNER TO tpdb_user;
\q

# Configure PostgreSQL authentication
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" /var/lib/pgsql/data/postgresql.conf

# Update pg_hba.conf to use md5 authentication
cp /var/lib/pgsql/data/pg_hba.conf /var/lib/pgsql/data/pg_hba.conf.backup
sed -i 's/host    all             all             127.0.0.1\/32            ident/host    all             all             127.0.0.1\/32            md5/' /var/lib/pgsql/data/pg_hba.conf
sed -i 's/host    all             all             ::1\/128                 ident/host    all             all             ::1\/128                 md5/' /var/lib/pgsql/data/pg_hba.conf

# Restart PostgreSQL
systemctl restart postgresql
```


### 4. Deploy Project

```bash
# Create project user
useradd --system --home /var/www/tpdb --shell /bin/false tpdb
usermod -a -G caddy tpdb

# Create project directory
sudo mkdir -p /var/www/tpdb
sudo chown -R tpdb:caddy /var/www/tpdb
sudo chmod 755 /var/www/tpdb

# Create log directory
mkdir -p /var/log/tpdb
chown -R tpdb:caddy /var/log/tpdb
chmod 775 /var/log/tpdb

# If directory is not empty, remove contents first
rm -rf /var/www/tpdb/*
rm -rf /var/www/tpdb/.*  2>/dev/null || true  # Remove hidden files, ignore errors

# Clone your repository
cd /var/www/tpdb
sudo -u tpdb git clone https://github.com/marcelomd/dj-test.git .
sudo -u tpdb python3 -m venv venv

# Create static and media directories
mkdir -p /var/www/tpdb/static /var/www/tpdb/media
chown tpdb:caddy /var/www/tpdb/static /var/www/tpdb/media

# Activate virtual environment and install dependencies
sudo -u tpdb /bin/bash -c "source venv/bin/activate && pip install -r requirements.txt"

# Create environment file
sudo -u tpdb cp config/.env.example .env
sudo -u tpdb vi .env  # Edit with your values

# Run initial Django setup
sudo -u tpdb /bin/bash -c "source venv/bin/activate && python manage.py migrate"
sudo -u tpdb /bin/bash -c "source venv/bin/activate && python manage.py collectstatic --noinput"

# Copy service file
cp config/tpdb.service /etc/systemd/system/

# Enable and start service
systemctl daemon-reload
systemctl enable tpdb
systemctl start tpdb
systemctl status tpdb
```


### 5. Configure Caddy

```bash
# Copy Caddyfile
cp config/Caddyfile /etc/caddy/Caddyfile

# Test Caddy configuration
caddy validate --config /etc/caddy/Caddyfile

# Enable and start Caddy
systemctl enable caddy
systemctl start caddy

# Configure SELinux for Caddy (if SELinux is enabled)
setsebool -P httpd_can_network_connect 1
chcon -Rt httpd_exec_t /var/www/tpdb/
```

### 6. Configure Firewall

```bash
# Configure firewalld
sudo systemctl enable firewalld
sudo systemctl start firewalld

# Allow HTTP and HTTPS traffic
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload
```
