# Quick Start Guide: VPS Deployment with GitHub Actions

This is a condensed guide to get your Django project deployed with automated GitHub Actions. Follow these steps in order.

## Prerequisites

- ✅ VPS with Fedora
- ✅ Domain name pointing to your VPS
- ✅ GitHub repository with your Django project

## 1. VPS Initial Setup (5 minutes)

```bash
# Update system and install packages
sudo dnf update -y
sudo dnf install -y python3-pip python3-virtualenv postgresql17 postgresql17-server postgresql17-contrib postgresql17-devel postgresql17-server-devel python3-devel gcc git caddy

# Setup PostgreSQL
sudo postgresql-setup --initdb
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Create database
sudo -u postgres psql -c "CREATE DATABASE tpdb_db;"
sudo -u postgres psql -c "CREATE USER tpdb_user WITH PASSWORD 'your-strong-password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE tpdb_db TO tpdb_user;"
sudo -u postgres psql -c "ALTER DATABASE tpdb_db OWNER TO tpdb_user;"

# Configure PostgreSQL authentication
sudo sed -i 's/ident/md5/g' /var/lib/pgsql/data/pg_hba.conf
sudo systemctl restart postgresql
```

## 2. Create Project Structure (3 minutes)

```bash
# Create users and directories
sudo useradd --system --home /var/www/tpdb --shell /bin/false tpdb
sudo usermod -aG caddy tpdb
# Modify tpdb user to allow shell access
sudo usermod -s /bin/bash tpdb

# Create directories
sudo mkdir -p /var/www/tpdb /var/log/tpdb /var/backups/tpdb
sudo chown -R tpdb:caddy /var/www/tpdb /var/log/tpdb /var/backups/tpdb
sudo chmod 755 /var/www/tpdb
```

## 3. Deploy Project Initially (5 minutes)

```bash
# Clone and setup project
cd /var/www/tpdb
sudo -u tpdb git clone https://github.com/your-username/your-repo.git .
sudo -u tpdb python3 -m venv venv
sudo -u tpdb /bin/bash -c "source venv/bin/activate && pip install -r requirements.txt"

# Create environment file
sudo -u tpdb cp config/.env.example .env
sudo -u tpdb nano .env  # Edit with your values (see ENVIRONMENT_SETUP.md)

# Run Django setup
sudo -u tpdb /bin/bash -c "source venv/bin/activate && python manage.py migrate"
sudo -u tpdb /bin/bash -c "source venv/bin/activate && python manage.py collectstatic --noinput"

# Setup services
sudo cp config/tpdb.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable tpdb
sudo systemctl start tpdb

# Setup Caddy
sudo cp config/Caddyfile /etc/caddy/Caddyfile
sudo systemctl enable caddy
sudo systemctl start caddy
```

## 4. Configure Firewall (1 minute)

```bash
sudo systemctl enable firewalld
sudo systemctl start firewalld
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --permanent --add-service=https
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload
```

## 5. Setup SSH for GitHub Actions (3 minutes)

```bash
# Generate SSH key (run on your local machine)
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_actions_deploy

# Copy public key to VPS for tpdb user
ssh-copy-id -i ~/.ssh/github_actions_deploy.pub tpdb@tpsdatabase.com.br

# Configure minimal sudo permissions for tpdb user
sudo visudo -f /etc/sudoers.d/tpdb
```

Add to the sudoers file:
```
tpdb ALL=(ALL) NOPASSWD: /bin/systemctl restart tpdb
tpdb ALL=(ALL) NOPASSWD: /bin/systemctl restart caddy
tpdb ALL=(ALL) NOPASSWD: /bin/systemctl status tpdb
tpdb ALL=(ALL) NOPASSWD: /bin/systemctl status caddy
tpdb ALL=(ALL) NOPASSWD: /bin/systemctl is-active tpdb
tpdb ALL=(ALL) NOPASSWD: /bin/systemctl is-active caddy
```

## 6. Configure GitHub Secrets (2 minutes)

In your GitHub repository, go to Settings → Secrets and variables → Actions

Add these secrets:
- **VPS_HOST**: `tpsdatabase.com.br`
- **VPS_USERNAME**: `tpdb`
- **VPS_SSH_KEY**: Content of `~/.ssh/github_actions_deploy` (private key)

## 7. Test Deployment (2 minutes)

```bash
# Make deploy script executable
sudo chmod +x /var/www/tpdb/deploy.sh
sudo chown tpdb:caddy /var/www/tpdb/deploy.sh

# Test the deployment script
sudo -u tpdb /var/www/tpdb/deploy.sh

# Check services are running
sudo systemctl status tpdb
sudo systemctl status caddy
```

## 8. Trigger GitHub Actions (1 minute)

1. Push a commit to your main branch
2. Go to GitHub → Actions tab
3. Watch your deployment workflow run
4. Visit your domain to confirm it's working

## Quick Verification Commands

```bash
# Check all services
sudo systemctl status tpdb caddy postgresql

# Check application logs
sudo journalctl -u tpdb -f

# Check deployment logs
tail -f /var/log/tpdb/deploy.log

# Check web access
curl -I https://tpsdatabase.com.br
```

## What You Get

✅ **Automated deployments** on every push to main
✅ **Backup and rollback** functionality
✅ **Service health checks** and failure notifications
✅ **SSL/HTTPS** automatically configured
✅ **Security headers** and best practices
✅ **Comprehensive logging** and monitoring

## Next Steps

- Set up monitoring (optional)
- Configure email notifications
- Add staging environment
- Set up database backups
- Configure log rotation

## Need Help?

- **Full deployment guide**: See `DEPLOYMENT.md`
- **SSH setup details**: See `SSH_SETUP.md`
- **Environment config**: See `ENVIRONMENT_SETUP.md`
- **Troubleshooting**: Check service logs and GitHub Actions output

**Total setup time: ~20 minutes** ⏱️