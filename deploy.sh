#!/bin/bash

# Deploy script for Django project on VPS
set -e

PROJECT_DIR="/var/www/tpdb"
VENV_DIR="$PROJECT_DIR/venv"
USER="tpdb"
GROUP="caddy"

echo "Starting deployment..."

# Navigate to project directory
cd $PROJECT_DIR

# Pull latest code
echo "Pulling latest code from Git..."
git pull origin main

# Activate virtual environment
echo "Activating virtual environment..."
source $VENV_DIR/bin/activate

# Install/update dependencies
echo "Installing dependencies..."
pip install -r requirements.txt

# Run database migrations
echo "Running database migrations..."
python manage.py migrate --settings=myproject.production_settings

# Collect static files
echo "Collecting static files..."
python manage.py collectstatic --noinput --settings=myproject.production_settings

# Change ownership
chown -R $USER:$GROUP $PROJECT_DIR

# Restart services
echo "Restarting services..."
systemctl restart tpdb
systemctl restart caddy

echo "Deployment completed successfully!"