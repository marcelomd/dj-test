# SSH Setup for GitHub Actions Deployment

This guide explains how to set up SSH key authentication between GitHub Actions and your VPS for automated deployments.

## Step 1: Generate SSH Key Pair on Your Local Machine

```bash
# Generate a new SSH key pair specifically for GitHub Actions
ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/github_actions_deploy

# This creates two files:
# - ~/.ssh/github_actions_deploy (private key)
# - ~/.ssh/github_actions_deploy.pub (public key)
```

## Step 2: Copy Public Key to VPS

```bash
# Copy the public key to your VPS
ssh-copy-id -i ~/.ssh/github_actions_deploy.pub root@tpsdatabase.com.br

# Or manually copy it:
cat ~/.ssh/github_actions_deploy.pub | ssh root@tpsdatabase.com.br "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

## Step 3: Configure SSH for tpdb User

Much simpler approach - use the `tpdb` user directly for deployment:

```bash
# Allow tpdb user to have a shell (modify existing user)
sudo usermod -s /bin/bash tpdb

# Create SSH directory for tpdb user
sudo -u tpdb mkdir -p /var/www/tpdb/.ssh
sudo -u tpdb chmod 700 /var/www/tpdb/.ssh

# Copy the public key content to authorized_keys
sudo -u tpdb bash -c 'echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... github-actions-deploy" >> /var/www/tpdb/.ssh/authorized_keys'
sudo -u tpdb chmod 600 /var/www/tpdb/.ssh/authorized_keys
```

## Step 4: Configure Minimal Sudo for tpdb User

Only grant permission to restart services:

```bash
# Edit sudoers file
sudo visudo -f /etc/sudoers.d/tpdb

# Add only these minimal permissions:
tpdb ALL=(ALL) NOPASSWD: /bin/systemctl restart tpdb
tpdb ALL=(ALL) NOPASSWD: /bin/systemctl restart caddy
tpdb ALL=(ALL) NOPASSWD: /bin/systemctl status tpdb
tpdb ALL=(ALL) NOPASSWD: /bin/systemctl status caddy
tpdb ALL=(ALL) NOPASSWD: /bin/systemctl is-active tpdb
tpdb ALL=(ALL) NOPASSWD: /bin/systemctl is-active caddy
```

## Step 5: Test SSH Connection

Test the connection from your local machine:

```bash
# Test connection
ssh -i ~/.ssh/github_actions_deploy tpdb@tpsdatabase.com.br

# Test sudo permissions
sudo systemctl status tpdb
sudo systemctl status caddy
```

## Step 6: Add GitHub Secrets

1. Go to your GitHub repository
2. Navigate to Settings > Secrets and variables > Actions
3. Add the following secrets:

### Required Secrets:

- **VPS_HOST**: `tpsdatabase.com.br`
- **VPS_USERNAME**: `tpdb`
- **VPS_SSH_KEY**: The contents of your private key file (`~/.ssh/github_actions_deploy`)

### Optional Secrets:

- **VPS_PORT**: SSH port (default: 22)

### How to get the private key content:

```bash
# Display the private key content
cat ~/.ssh/github_actions_deploy

# Copy this entire output (including -----BEGIN and -----END lines)
# and paste it as the VPS_SSH_KEY secret value
```

## Step 7: Prepare Deployment Script

Make the deployment script executable:

```bash
# Make deploy script executable
sudo chmod +x /var/www/tpdb/deploy.sh
sudo chown tpdb:caddy /var/www/tpdb/deploy.sh
```

## Step 8: Test GitHub Actions Deployment

1. Push a commit to the main branch
2. Check the Actions tab in your GitHub repository
3. Monitor the deployment workflow

## Security Best Practices

1. **Use a dedicated SSH key**: Don't reuse existing SSH keys
2. **Limit sudo permissions**: Only grant necessary permissions
3. **Regular key rotation**: Rotate SSH keys periodically
4. **Monitor access logs**: Check `/var/log/auth.log` for SSH access
5. **Use fail2ban**: Install fail2ban to prevent brute force attacks

```bash
# Install and configure fail2ban
sudo dnf install fail2ban -y
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

## Troubleshooting

### Common Issues:

1. **Permission denied**: Check SSH key permissions and authorized_keys file
2. **Sudo password prompt**: Verify sudoers configuration
3. **Service restart fails**: Check systemd service status and logs
4. **File permission errors**: Ensure proper ownership of project files

### Debug Commands:

```bash
# Check SSH connection
ssh -v -i ~/.ssh/github_actions_deploy tpdb@tpsdatabase.com.br

# Check sudo permissions
sudo -l

# Check service status
systemctl status tpdb
systemctl status caddy

# Check deployment logs
tail -f /var/log/tpdb/deploy.log
```

## Alternative: Using GitHub Deploy Keys

If you prefer using GitHub Deploy Keys instead of SSH keys in secrets:

1. Generate a deploy key: `ssh-keygen -t ed25519 -f ~/.ssh/deploy_key`
2. Add the public key to GitHub Repository Settings > Deploy Keys
3. Use the private key in GitHub Secrets

Deploy keys are more secure as they're repository-specific and can be read-only.