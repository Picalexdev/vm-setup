#!/bin/bash

# Exit on error
set -e

echo "Starting VM setup..."

# Update system
echo "Updating system packages..."
sudo apt update
sudo apt upgrade -y

# Install essential tools and dependencies
echo "Installing dependencies..."
sudo apt install -y \
    python3-pip \
    python3-dev \
    nginx \
    certbot \
    python3-certbot-nginx \
    git \
    docker.io \
    docker-compose \
    fonts-liberation \
    fontconfig \
    fonts-dejavu \
    fonts-liberation2 \
    fonts-urw-base35 \
    fonts-texgyre \
    unattended-upgrades \
    logrotate \
    ufw

# Start and enable Docker
echo "Configuring Docker..."
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER

# Create necessary directories
echo "Creating directories..."
mkdir -p ~/web-esg
sudo mkdir -p /var/lib/letsencrypt/

# Set proper permissions
sudo chown -R $USER:$USER ~/web-esg

# Clone repository
echo "Cloning repository..."
cd ~/web-esg
git clone https://github.com/Picalexdev/web-esg.git .  # Replace with your actual repo URL

# Create environment file
echo "Setting up environment..."
cat > .env << EOL
DEBUG=False
DJANGO_SECRET_KEY=your_secret_key_here
TYPEFORM_TOKEN=your_token_here
EOL

# Set up Docker and run the application
echo "Building and starting Docker containers..."
docker-compose build
docker-compose up -d

# Configure firewall
echo "Configuring firewall..."
sudo ufw allow 22/tcp  # SSH
sudo ufw allow 80/tcp  # HTTP
sudo ufw allow 443/tcp # HTTPS
sudo ufw --force enable

# Set up automatic security updates
echo "Configuring automatic updates..."
sudo dpkg-reconfigure -f noninteractive unattended-upgrades

# Enable automatic SSL renewal
echo "Setting up SSL auto-renewal..."
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer

# Secure shared memory
echo "Implementing security measures..."
echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" | sudo tee -a /etc/fstab

# SSH hardening
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# Set up log rotation
echo "Configuring log rotation..."
sudo tee /etc/logrotate.d/web-esg << EOF
/var/log/nginx/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        [ ! -f /var/run/nginx.pid ] || kill -USR1 \`cat /var/run/nginx.pid\`
    endscript
}
EOF

echo "Setup complete! Please update the .env file with your actual values."
echo "Next steps:"
echo "1. Update the .env file with your actual secret key and tokens"
echo "2. Configure your domain in Nginx"
echo "3. Set up SSL with: sudo certbot --nginx -d your-domain.com -d www.your-domain.com" 