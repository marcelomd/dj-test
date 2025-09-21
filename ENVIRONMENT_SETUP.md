# Environment Configuration Guide

This guide explains how to configure environment variables and GitHub Secrets for automated deployment.

## Environment Variables Overview

Your Django application uses environment variables for configuration. These are stored in a `.env` file on the production server.

## Required Environment Variables

Based on your `config/.env.example`, you need to configure:

### Django Settings
- `SECRET_KEY`: Django secret key for cryptographic signing
- `DEBUG`: Set to `False` for production
- `ALLOWED_HOSTS`: Your domain name(s)

### Database Configuration
- `DB_NAME`: PostgreSQL database name (`tpdb_db`)
- `DB_USER`: PostgreSQL user (`tpdb_user`)
- `DB_PASSWORD`: PostgreSQL password
- `DB_HOST`: Database host (`localhost`)
- `DB_PORT`: Database port (`5432`)

## Step 1: Create Production Environment File

On your VPS, create the production `.env` file:

```bash
# On your VPS as tpdb user
sudo -u tpdb cp /var/www/tpdb/config/.env.example /var/www/tpdb/.env
sudo -u tpdb nano /var/www/tpdb/.env
```

## Step 2: Configure Environment Variables

Edit `/var/www/tpdb/.env` with your production values:

```bash
# Django Settings
SECRET_KEY=your-very-long-random-secret-key-here
DEBUG=False
ALLOWED_HOSTS=tpsdatabase.com.br,www.tpsdatabase.com.br

# Database Configuration
DB_NAME=tpdb_db
DB_USER=tpdb_user
DB_PASSWORD=your-strong-database-password
DB_HOST=localhost
DB_PORT=5432

# Additional Production Settings
DJANGO_SETTINGS_MODULE=myproject.settings
```

## Step 3: Generate Django Secret Key

Generate a secure secret key:

```python
# Run this on your local machine or VPS
python -c "
import secrets
import string
alphabet = string.ascii_letters + string.digits + '!@#$%^&*(-_=+)'
secret_key = ''.join(secrets.choice(alphabet) for _ in range(50))
print(f'SECRET_KEY={secret_key}')
"
```

## Step 4: Configure GitHub Secrets

### Required GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these repository secrets:

#### VPS Connection
- **VPS_HOST**: `tpsdatabase.com.br`
- **VPS_USERNAME**: `tpdb`
- **VPS_SSH_KEY**: Your private SSH key content (see SSH_SETUP.md)
- **VPS_PORT**: `22` (optional, defaults to 22)

#### Database (Optional - for automated setup)
- **DB_PASSWORD**: Your PostgreSQL password
- **DJANGO_SECRET_KEY**: Your Django secret key

### Optional Secrets for Enhanced Security

- **SLACK_WEBHOOK**: For deployment notifications
- **SENTRY_DSN**: For error tracking
- **EMAIL_HOST_PASSWORD**: For email functionality

## Step 5: Update Django Settings

Create or update your Django settings to use environment variables:

```python
# myproject/settings.py or myproject/production_settings.py
import os
from decouple import config

# Security
SECRET_KEY = config('SECRET_KEY')
DEBUG = config('DEBUG', default=False, cast=bool)
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='').split(',')

# Database
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': config('DB_NAME'),
        'USER': config('DB_USER'),
        'PASSWORD': config('DB_PASSWORD'),
        'HOST': config('DB_HOST'),
        'PORT': config('DB_PORT'),
    }
}

# Static files
STATIC_URL = '/static/'
STATIC_ROOT = '/var/www/tpdb/static'

# Media files
MEDIA_URL = '/media/'
MEDIA_ROOT = '/var/www/tpdb/media'

# Security settings for production
if not DEBUG:
    SECURE_SSL_REDIRECT = True
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
    SECURE_HSTS_SECONDS = 31536000
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
    SECURE_CONTENT_TYPE_NOSNIFF = True
    SECURE_BROWSER_XSS_FILTER = True
    X_FRAME_OPTIONS = 'DENY'
```

## Step 6: Install Python Decouple

Add python-decouple to your requirements.txt if not already present:

```bash
# Add to requirements.txt
python-decouple==3.8
```

## Step 7: Environment File Security

Set proper permissions for the `.env` file:

```bash
# On your VPS
sudo chmod 600 /var/www/tpdb/.env
sudo chown tpdb:caddy /var/www/tpdb/.env
```

## Step 8: Test Configuration

Test your environment configuration:

```bash
# On your VPS as tpdb user
cd /var/www/tpdb
source venv/bin/activate
python manage.py check --deploy
python manage.py migrate --check
```

## Environment Variables Reference

### Complete .env Template

```bash
# Django Core Settings
SECRET_KEY=your-50-character-random-secret-key
DEBUG=False
ALLOWED_HOSTS=tpsdatabase.com.br,www.tpsdatabase.com.br

# Database Configuration
DB_NAME=tpdb_db
DB_USER=tpdb_user
DB_PASSWORD=your-strong-password-here
DB_HOST=localhost
DB_PORT=5432

# Email Configuration (Optional)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password

# Logging (Optional)
LOG_LEVEL=INFO

# Cache (Optional)
CACHE_URL=redis://localhost:6379/1

# Celery (Optional)
CELERY_BROKER_URL=redis://localhost:6379/0

# File Storage (Optional)
AWS_ACCESS_KEY_ID=your-aws-key
AWS_SECRET_ACCESS_KEY=your-aws-secret
AWS_STORAGE_BUCKET_NAME=your-bucket-name
```

## Security Best Practices

1. **Never commit .env files**: Add `.env` to `.gitignore`
2. **Use strong passwords**: Generate random, complex passwords
3. **Rotate secrets regularly**: Update keys and passwords periodically
4. **Limit access**: Only necessary users should access production secrets
5. **Use different keys**: Never reuse development keys in production

## Monitoring and Validation

### Validate Environment Setup

```bash
# Check environment variables are loaded
python -c "
import os
from decouple import config
print('SECRET_KEY:', config('SECRET_KEY')[:10] + '...')
print('DEBUG:', config('DEBUG'))
print('DB_NAME:', config('DB_NAME'))
"
```

### Monitor Configuration

```bash
# Check Django configuration
python manage.py diffsettings
python manage.py check --deploy --settings=myproject.settings
```

## Troubleshooting

### Common Issues:

1. **Missing environment variables**: Check `.env` file exists and has correct permissions
2. **Database connection errors**: Verify PostgreSQL is running and credentials are correct
3. **Static files not loading**: Check STATIC_ROOT and run collectstatic
4. **SSL errors**: Verify domain name and SSL certificate configuration

### Debug Commands:

```bash
# Check environment file
cat /var/www/tpdb/.env

# Test database connection
python manage.py dbshell

# Check static files
python manage.py collectstatic --dry-run

# Validate deployment
python manage.py check --deploy
```