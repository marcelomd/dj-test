# VPS Deployment Guide (Fedora + Caddy)

This guide explains how to deploy your Django project to a Fedora VPS using Caddy server with automatic updates via GitHub Actions.

## VPS Setup

### 1. Initial Server Setup

```bash
# Update system
sudo dnf update -y

# Install required packages
sudo dnf install -y python3 python3-pip python3-virtualenv postgresql postgresql-server postgresql-contrib postgresql-devel python3-devel gcc git

# Install Caddy
sudo dnf install -y 'dnf-command(copr)'
sudo dnf copr enable @caddy/caddy -y
sudo dnf install -y caddy

# Initialize PostgreSQL database
sudo postgresql-setup --initdb
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Create project user
sudo useradd --system --home /var/www/tpdb --shell /bin/false tpdb
sudo usermod -a -G caddy tpdb

# Create project directory
sudo mkdir -p /var/www/tpdb
sudo chown tpdb:caddy /var/www/tpdb
sudo chmod 755 /var/www/tpdb
```

### 2. Database Setup

```bash
# Switch to postgres user
sudo -u postgres psql

# Create database and user
CREATE DATABASE tpdb_db;
CREATE USER tpdb_user WITH PASSWORD 'your-password';
ALTER ROLE tpdb_user SET client_encoding TO 'utf8';
ALTER ROLE tpdb_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE tpdb_user SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE tpdb_db TO tpdb_user;
\q

# Configure PostgreSQL authentication
sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = 'localhost'/" /var/lib/pgsql/data/postgresql.conf

# Update pg_hba.conf to use md5 authentication
sudo cp /var/lib/pgsql/data/pg_hba.conf /var/lib/pgsql/data/pg_hba.conf.backup
sudo sed -i 's/local   all             all                                     peer/local   all             all                                     md5/' /var/lib/pgsql/data/pg_hba.conf
sudo sed -i 's/host    all             all             127.0.0.1\/32            ident/host    all             all             127.0.0.1\/32            md5/' /var/lib/pgsql/data/pg_hba.conf
sudo sed -i 's/host    all             all             ::1\/128                 ident/host    all             all             ::1\/128                 md5/' /var/lib/pgsql/data/pg_hba.conf

# Restart PostgreSQL
sudo systemctl restart postgresql
```

### 3. Setup Git Access

Choose one of the following methods:

#### Option A: SSH Key (Recommended for private repos)
```bash
# Generate SSH key for the tpdb user
sudo -u tpdb ssh-keygen -t ed25519 -C "tpdb@your-domain.com" -f /var/www/tpdb/.ssh/id_ed25519 -N ""

# Display the public key to add to GitHub
sudo -u tpdb cat /var/www/tpdb/.ssh/id_ed25519.pub

# Create SSH config
sudo -u tpdb mkdir -p /var/www/tpdb/.ssh
sudo -u tpdb tee /var/www/tpdb/.ssh/config << EOF
Host github.com
    HostName github.com
    User git
    IdentityFile /var/www/tpdb/.ssh/id_ed25519
    StrictHostKeyChecking no
EOF

sudo -u tpdb chmod 600 /var/www/tpdb/.ssh/config
sudo -u tpdb chmod 700 /var/www/tpdb/.ssh
```

**Add the public key to GitHub:**
1. Go to GitHub.com → Settings → SSH and GPG keys
2. Click "New SSH key"
3. Paste the public key displayed above
4. Give it a title like "VPS-tpdb"

#### Option B: HTTPS with Token (Simpler setup)
```bash
# For public repos, use HTTPS directly (no setup needed)

# For private repos, create a Personal Access Token:
# 1. Go to GitHub.com → Settings → Developer settings → Personal access tokens → Tokens (classic)
# 2. Click "Generate new token (classic)"
# 3. Give it a name like "VPS Deployment"
# 4. Select scopes: repo (full control of private repositories)
# 5. Copy the generated token (you won't see it again!)
```

### 4. Deploy Project

```bash
# Switch to project directory
cd /var/www/tpdb

# If directory is not empty, remove contents first
sudo rm -rf /var/www/tpdb/*
sudo rm -rf /var/www/tpdb/.*  2>/dev/null || true  # Remove hidden files, ignore errors

# Clone your repository (choose one method)
# SSH method:
sudo -u tpdb git clone git@github.com:yourusername/yourrepo.git .

# OR HTTPS method (public repos):
sudo -u tpdb git clone https://github.com/yourusername/yourrepo.git .

# OR HTTPS with token (private repos):
sudo -u tpdb git clone https://your-token@github.com/yourusername/yourrepo.git .

# Alternative: Clone to a temporary directory and move contents
# sudo -u tpdb git clone https://github.com/yourusername/yourrepo.git /tmp/tpdb-repo
# sudo -u tpdb cp -r /tmp/tpdb-repo/* /var/www/tpdb/
# sudo -u tpdb cp -r /tmp/tpdb-repo/.* /var/www/tpdb/ 2>/dev/null || true
# sudo rm -rf /tmp/tpdb-repo

# Create virtual environment
sudo -u tpdb python3 -m venv venv

# Activate virtual environment and install dependencies
sudo -u tpdb /bin/bash -c "source venv/bin/activate && pip install -r requirements.txt"

# Create environment file
sudo -u tpdb cp config/.env.example .env
sudo -u tpdb nano .env  # Edit with your values

# Create log directory
sudo mkdir -p /var/log/tpdb
sudo chown tpdb:caddy /var/log/tpdb

# Create static and media directories
sudo mkdir -p /var/www/tpdb/static /var/www/tpdb/media
sudo chown tpdb:caddy /var/www/tpdb/static /var/www/tpdb/media

# Run initial Django setup
sudo -u tpdb /bin/bash -c "source venv/bin/activate && python manage.py migrate --settings=myproject.production_settings"
sudo -u tpdb /bin/bash -c "source venv/bin/activate && python manage.py collectstatic --noinput --settings=myproject.production_settings"
```

### 4. Configure Systemd Service

```bash
# Copy service file
sudo cp config/tpdb.service /etc/systemd/system/

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable tpdb
sudo systemctl start tpdb
sudo systemctl status tpdb
```

### 5. Configure Caddy

```bash
# Copy Caddyfile
sudo cp config/Caddyfile /etc/caddy/Caddyfile

# Test Caddy configuration
sudo caddy validate --config /etc/caddy/Caddyfile

# Enable and start Caddy
sudo systemctl enable caddy
sudo systemctl restart caddy

# Configure SELinux for Caddy (if SELinux is enabled)
sudo setsebool -P httpd_can_network_connect 1
sudo chcon -Rt httpd_exec_t /var/www/tpdb/
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

### 7. SSL Certificate

Caddy automatically handles SSL certificates via Let's Encrypt! No manual setup required.
Just make sure your domain points to your VPS and Caddy will automatically:
- Obtain SSL certificates
- Renew them automatically
- Redirect HTTP to HTTPS

## GitHub Actions Setup

### 1. Generate SSH Key for Deployment

```bash
# On your VPS, generate a key for GitHub Actions (run as your main user, not tpdb)
ssh-keygen -t ed25519 -C "github-actions@your-domain.com" -f ~/.ssh/github_actions -N ""

# Add the public key to authorized_keys
cat ~/.ssh/github_actions.pub >> ~/.ssh/authorized_keys

# Copy the private key for GitHub secrets
cat ~/.ssh/github_actions
```

**Important:** Make sure your main user has sudo access and the tpdb user can be accessed via sudo commands.

### 2. Configure GitHub Secrets

In your GitHub repository, go to Settings > Secrets and variables > Actions, and add:

- `VPS_HOST`: Your VPS IP address or domain
- `VPS_USERNAME`: Your VPS username (usually root or your user)
- `VPS_SSH_KEY`: The private SSH key content

### 3. Prepare Repository

**Before deploying, ensure your repository contains all necessary files:**

```bash
# On your local machine, commit and push these files to GitHub:
git add requirements.txt
git add config/
git add myproject/production_settings.py
git add .github/workflows/deploy.yml
git add deploy.sh
git add DEPLOYMENT.md
git commit -m "Add deployment configuration"
git push origin main
```

**Required files checklist:**
- ✅ `requirements.txt` - Python dependencies
- ✅ `config/Caddyfile` - Web server configuration
- ✅ `config/tpdb.service` - Systemd service file
- ✅ `config/.env.example` - Environment variables template
- ✅ `myproject/production_settings.py` - Production Django settings
- ✅ `.github/workflows/deploy.yml` - GitHub Actions workflow
- ✅ `deploy.sh` - Deployment script

### 4. Update Deployment Variables

Edit these files with your actual values:

1. `myproject/production_settings.py` - Update ALLOWED_HOSTS
2. `config/Caddyfile` - Update domain names
3. `.env` - Set your actual environment variables

## Deployment Process

1. Push code to main branch
2. GitHub Actions will:
   - Run tests
   - Deploy to VPS if tests pass
   - Restart services

## Manual Deployment

If needed, you can deploy manually:

```bash
cd /var/www/tpdb
sudo ./deploy.sh
```

## Monitoring

```bash
# Check service status
sudo systemctl status tpdb
sudo systemctl status caddy

# View logs
sudo journalctl -u tpdb -f
sudo journalctl -u caddy -f
sudo tail -f /var/log/tpdb/django.log
```

## Troubleshooting

Common issues and solutions:

### Git/GitHub Issues

1. **"Could not open requirements file: No such file or directory"**:
   ```bash
   # This means requirements.txt is missing from your repository
   # On your local machine, add and commit the file:
   git add requirements.txt
   git commit -m "Add requirements.txt"
   git push origin main

   # Then on the server, pull the latest changes:
   cd /var/www/tpdb
   sudo -u tpdb git pull origin main
   ```

2. **"Permission denied (publickey)" when cloning**:
   ```bash
   # Test SSH connection to GitHub
   sudo -u tpdb ssh -T git@github.com

   # If fails, check SSH key:
   sudo -u tpdb cat /var/www/tpdb/.ssh/id_ed25519.pub
   # Make sure this key is added to GitHub

   # Alternative: Use HTTPS with token
   sudo -u tpdb git clone https://your-token@github.com/username/repo.git .
   ```

2. **"destination path '.' already exists and is not an empty directory"**:
   ```bash
   # Option 1: Clear the directory and clone
   cd /var/www/tpdb
   sudo rm -rf /var/www/tpdb/*
   sudo rm -rf /var/www/tpdb/.*  2>/dev/null || true
   sudo -u tpdb git clone https://github.com/username/repo.git .

   # Option 2: Clone to temp directory and move
   sudo -u tpdb git clone https://github.com/username/repo.git /tmp/tpdb-repo
   sudo -u tpdb cp -r /tmp/tpdb-repo/* /var/www/tpdb/
   sudo -u tpdb cp -r /tmp/tpdb-repo/.git /var/www/tpdb/
   sudo rm -rf /tmp/tpdb-repo
   ```

3. **"Repository not found" error**:
   - Check repository URL is correct
   - For private repos, ensure SSH key or token has access
   - Use HTTPS for public repos: `https://github.com/username/repo.git`

4. **Git pull fails in deployment**:
   ```bash
   # Check git configuration for tpdb user
   sudo -u tpdb git config --global user.email "tpdb@your-domain.com"
   sudo -u tpdb git config --global user.name "TPDB Server"

   # Reset remote if needed
   cd /var/www/tpdb
   sudo -u tpdb git remote set-url origin git@github.com:username/repo.git
   ```

### Installation Issues

5. **"psycopg2 build error" or "pg_config not found"**:
   ```bash
   # Install PostgreSQL development headers
   sudo dnf install -y postgresql-devel python3-devel gcc

   # Then retry pip install
   cd /var/www/tpdb
   sudo -u tpdb /bin/bash -c "source venv/bin/activate && pip install -r requirements.txt"
   ```

6. **"_PyInterpreterState_Get" compilation error with psycopg2**:
   ```bash
   # This is a Python version compatibility issue. Try these solutions:

   # Option 1: Use newer psycopg2-binary version
   cd /var/www/tpdb
   sudo -u tpdb /bin/bash -c "source venv/bin/activate && pip install psycopg2-binary==2.9.9"

   # Option 2: Use system package instead
   sudo dnf install -y python3-psycopg2
   # Then install other requirements without psycopg2
   sudo -u tpdb /bin/bash -c "source venv/bin/activate && pip install Django==5.2.5 gunicorn==21.2.0 python-dotenv==1.0.0"

   # Option 3: Use psycopg (psycopg3) instead
   sudo -u tpdb /bin/bash -c "source venv/bin/activate && pip install 'psycopg[binary]'"
   ```

### Database Issues

7. **"Ident authentication failed" for PostgreSQL**:
   ```bash
   # Fix PostgreSQL authentication method
   sudo cp /var/lib/pgsql/data/pg_hba.conf /var/lib/pgsql/data/pg_hba.conf.backup

   # Change ident/peer to md5 for password authentication
   sudo sed -i 's/local   all             all                                     peer/local   all             all                                     md5/' /var/lib/pgsql/data/pg_hba.conf
   sudo sed -i 's/host    all             all             127.0.0.1\/32            ident/host    all             all             127.0.0.1\/32            md5/' /var/lib/pgsql/data/pg_hba.conf
   sudo sed -i 's/host    all             all             ::1\/128                 ident/host    all             all             ::1\/128                 md5/' /var/lib/pgsql/data/pg_hba.conf

   # Restart PostgreSQL
   sudo systemctl restart postgresql

   # Test connection
   sudo -u tpdb /bin/bash -c "source venv/bin/activate && python manage.py dbshell --settings=myproject.production_settings"
   ```

8. **Reset/recreate database completely**:
   ```bash
   # Stop services first
   sudo systemctl stop tpdb

   # Connect to PostgreSQL as superuser
   sudo -u postgres psql

   # Drop and recreate database and user
   DROP DATABASE IF EXISTS tpdb_db;
   DROP USER IF EXISTS tpdb_user;
   CREATE DATABASE tpdb_db;
   CREATE USER tpdb_user WITH PASSWORD 'your-new-password';
   ALTER ROLE tpdb_user SET client_encoding TO 'utf8';
   ALTER ROLE tpdb_user SET default_transaction_isolation TO 'read committed';
   ALTER ROLE tpdb_user SET timezone TO 'UTC';
   GRANT ALL PRIVILEGES ON DATABASE tpdb_db TO tpdb_user;
   \q

   # Update .env file with new password
   sudo -u tpdb nano /var/www/tpdb/.env

   # Run migrations
   cd /var/www/tpdb
   sudo -u tpdb /bin/bash -c "source venv/bin/activate && python manage.py migrate --settings=myproject.production_settings"

   # Restart services
   sudo systemctl start tpdb
   ```

### Service Issues

9. **Permission denied**: Check file ownership and permissions
10. **Database connection**: Verify PostgreSQL is running and credentials are correct
11. **Static files not loading**: Run `collectstatic` and check Caddyfile configuration
12. **502 Bad Gateway**: Check if gunicorn service is running
13. **SSL issues**: Caddy handles SSL automatically, ensure domain DNS points to your VPS

### Quick Fixes

```bash
# Fix ownership issues
sudo chown -R tpdb:caddy /var/www/tpdb
sudo chmod -R 755 /var/www/tpdb

# Restart all services
sudo systemctl restart tpdb caddy

# Check logs for errors
sudo journalctl -u tpdb -n 50
sudo journalctl -u caddy -n 50
```