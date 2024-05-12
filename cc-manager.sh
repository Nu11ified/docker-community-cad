#!/bin/bash

SCRIPT_DIR=$PWD
CC_INSTALL_DIR=$PWD/community-cad-storage
DOCKER_COMPOSE_FILE="$CC_INSTALL_DIR/docker-compose.yml"
ENV_FILE="$CC_INSTALL_DIR/.env"  # Define the .env file path

function print_header() {
    clear
    echo "--------------------------------------------"
    echo "  Community CAD Management Tool"
    echo "--------------------------------------------"
}

function command_exists() {
    type "$1" &> /dev/null
}

function install_git() {
  if command_exists git; then
    command echo "Git is already installed."
  else
    echo "Git is not installed. Installing Git... (Please be patient. May take a bit!)"
    if [[ $OS == *"Ubuntu"* || $OS == *"Debian"* ]]; then
      sudo apt-get install -y git > /dev/null 2>&1
    elif [[ $OS == *"CentOS"* || $OS == *"Rocky"* ]]; then
      sudo yum install -y git > /dev/null 2>&1
    fi
  fi
}

function install_curl() {
  if command_exists curl; then
    command echo "Curl is already installed."
  else
    echo "Curl is not installed. Installing Curl... (Please be patient. May take a bit!)"
    if [[ $OS == *"Ubuntu"* || $OS == *"Debian"* ]]; then
      sudo apt-get install -y curl > /dev/null 2>&1
    elif [[ $OS == *"CentOS"* || $OS == *"Rocky"* ]]; then
      sudo yum install -y curl > /dev/null 2>&1
    fi
  fi
}

function install_docker() {
  local os="${1}"
  echo "Installing Docker for OS: ${os}"
  echo "Your sudo password might be asked to install Docker"

  if command_exists docker; then
    command echo "Docker is already installed."
  else
    if [[ "${os}" == "debian" ]]; then
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg lsb-release
      sudo mkdir -p /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
      sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      return 0
    elif [[ "${os}" == "ubuntu" || "${os}" == "pop" ]]; then
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg lsb-release
      sudo mkdir -p /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
      sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
      return 0
    elif [[ "${os}" == "centos" ]]; then
      sudo yum install -y yum-utils
      sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      sudo yum install -y --allowerasing docker-ce docker-ce-cli containerd.io docker-compose-plugin
      sudo systemctl start docker
      sudo systemctl enable docker
      return 0
    elif [[ "${os}" == "rocky" ]]; then
      sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
      sudo systemctl start docker
      sudo systemctl enable docker
      return 0
    elif [[ "${os}" == "fedora" ]]; then
      sudo dnf -y install dnf-plugins-core
      sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
      sudo dnf -y install docker-ce docker-ce-cli containerd.io docker-compose-plugin
      sudo systemctl start docker
      sudo systemctl enable docker
      return 0
    elif [[ "${os}" == "arch" || "${os}" == "manjaro" ]]; then
      sudo pacman -Sy --noconfirm docker docker-compose
      sudo systemctl start docker.service
      sudo systemctl enable docker.service
      return 0
    else
      return 1
    fi
  fi
}

function install_docker_compose() {
  if command_exists docker-compose; then
    command echo "Docker Compose is already installed."
  else
    echo "Docker Compose is not installed. Installing Docker Compose... (Please be patient. May take a bit!)"
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose > /dev/null 2>&1
    sudo chmod +x /usr/local/bin/docker-compose > /dev/null 2>&1
  fi
}

function update_packages() {
  if [[ $OS == *"Ubuntu"* || $OS == *"Debian"* ]]; then
    echo "System packages are updating... (Please be patient. May take a bit!)"
    sudo apt-get update -y
    sudo apt-get upgrade -y
  elif [[ $OS == *"CentOS"* || $OS == *"Rocky"* ]]; then
    sudo yum update > /dev/null 2>&1 
    sudo yum upgrade > /dev/null 2>&1
    echo "System packages are updating... (Please be patient. May take a bit!)"
  fi
}

function configure_environment() {
    echo "Configuring environment variables..."
    
    if [ ! -f "$ENV_FILE" ]; then
        echo "No .env file found in $CC_INSTALL_DIR. Please check your installation."
        return 1  
    fi

    generate_password() {
        cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1
    }

    db_password=$(generate_password)

    echo "Generated DB password: $db_password"

    echo "Generate an app key from https://laravel-encryption-key-generator.vercel.app/ and paste it below:"
    read -p "Enter your APP_KEY: " app_key
    read -p "Enter your APP_NAME: " app_name
    read -p "Enter your APP_URL (https://communitycad.app): " app_url
    read -p "URL For Steam without https:// (communitycad.app): " steam_allowed_hosts
    echo "For STEAM_CLIENT_SECRET, visit https://steamcommunity.com/dev/registerkey to register and obtain a key"
    read -p "Enter your STEAM_CLIENT_SECRET: " steam_client_secret
    echo "For DISCORD_CLIENT_ID, DISCORD_CLIENT_SECRET, and DISCORD_BOT_TOKEN, visit https://discord.com/developers/applications to create an application"
    read -p "Enter your DISCORD_CLIENT_ID: " discord_client_id
    read -p "Enter your DISCORD_CLIENT_SECRET: " discord_client_secret
    read -p "Enter your DISCORD_BOT_TOKEN: " discord_bot_token
    read -p 'Enter your OWNER_IDS ("ID1|ID2"): ' owner_ids
    read -p "Enter your CAD_TIMEZONE: " cad_timezone


    sed -i "s|^APP_KEY=.*|APP_KEY=$app_key|" "$ENV_FILE"
    sed -i "s|^APP_NAME=.*|APP_NAME=$app_name|" "$ENV_FILE"
    sed -i "s|^APP_URL=.*|APP_URL=$app_url|" "$ENV_FILE"
    sed -i "s|^STEAM_ALLOWED_HOSTS=.*|STEAM_ALLOWED_HOSTS=$steam_allowed_hosts|" "$ENV_FILE"
    sed -i "s|^STEAM_CLIENT_SECRET=.*|STEAM_CLIENT_SECRET=$steam_client_secret|" "$ENV_FILE"
    sed -i "s|^DISCORD_CLIENT_ID=.*|DISCORD_CLIENT_ID=$discord_client_id|" "$ENV_FILE"
    sed -i "s|^DISCORD_CLIENT_SECRET=.*|DISCORD_CLIENT_SECRET=$discord_client_secret|" "$ENV_FILE"
    sed -i "s|^DISCORD_BOT_TOKEN=.*|DISCORD_BOT_TOKEN=$discord_bot_token|" "$ENV_FILE"
    sed -i "s|^OWNER_IDS=.*|OWNER_IDS=$owner_ids|" "$ENV_FILE"
    sed -i "s|^CAD_TIMEZONE=.*|CAD_TIMEZONE=$cad_timezone|" "$ENV_FILE"
    sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=$db_password|" "$ENV_FILE"
}


function install() {
    echo "Starting the installation of Community CAD on x86_64 architecture..."
    if [ ! -d "$CC_INSTALL_DIR" ]; then
        mkdir -p "$CC_INSTALL_DIR"
    else
        echo "Installation directory already exists. Using existing directory."
    fi
    cd "$CC_INSTALL_DIR"

    if [ -d ".git" ]; then
        echo "Community CAD repository already exists in the installation directory."
        echo "Installation cannot proceed. If you wish to reinstall, please remove the existing directory first."
        return
    fi


    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
    else
        OS=$(uname -s)
    fi

    update_packages
    install_git
    install_curl
    install_docker
    install_docker_compose

    if [ ! -d "$CC_INSTALL_DIR/.git" ]; then
        echo "Cloning the Community CAD repository..."
        git clone https://github.com/CommunityCAD/docker-community-cad.git "$CC_INSTALL_DIR"
    else
        echo "Repository already cloned. Updating repository..."
        git pull
    fi

    if [ ! -f ".env" ]; then
        echo "Creating a new .env file..."
        cp .env.example .env
        echo "A new .env file has been created from .env.example."
    fi

    configure_environment

    echo "Setup is complete. Starting Docker containers..."
    docker-compose up -d
    echo "Installation and setup are complete. Community CAD is now running."

    install_reverse_proxy
}

function install_reverse_proxy() {
    echo "Would you like to install a reverse proxy with Caddy? [y/N]"
    read -p "Choice: " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        # Check if Caddy is already installed
        if command -v caddy &> /dev/null; then
            echo "Caddy is already installed. Skipping installation."
        else
            echo "Caddy is not installed. Proceeding with installation..."
            case $OS in
                ubuntu|debian)
                    sudo apt update
                    sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
                    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo tee /etc/apt/trusted.gpg.d/caddy-stable.asc
                    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
                    sudo apt update
                    sudo apt install caddy
                    ;;
                centos|rocky)
                    sudo yum install -y 'dnf-command(copr)'
                    sudo dnf copr enable @caddy/caddy
                    sudo dnf install -y caddy
                    ;;
                *)
                    echo "OS not supported for Caddy installation."
                    return
                    ;;
            esac
        fi

        # Prompt user for domain name and check A record
        echo "Please enter your domain name (e.g., example.com or www.example.com):"
        read -p "Domain name: " domain

        echo "Checking if A record exists for the domain..."
        if host -t A $domain &> /dev/null; then
            echo "A record exists for $domain."
        else
            echo "No A record found for $domain. Please ensure the A record is correctly set before proceeding."
            return
        fi

        echo "If you are using Cloudflare, please ensure your DNS settings for this domain are set to 'DNS only' to allow Caddy to handle HTTPS."

        echo "Configuring Caddy..."
        sudo tee /etc/caddy/Caddyfile <<EOF
$domain {
    reverse_proxy 127.0.0.1:8000
    encode gzip
    header {
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
}
EOF
        echo "Caddyfile has been configured."
        sudo systemctl restart caddy
        echo "Caddy has been restarted. Your reverse proxy is now running."
    fi
}


function startServices() {
    echo "Starting Community CAD services..."
    docker-compose -f $DOCKER_COMPOSE_FILE up -d
    echo "Services started."
}

function stopServices() {
    echo "Stopping Community CAD services..."
    docker-compose -f $DOCKER_COMPOSE_FILE down
    echo "Services stopped."
}

function restartServices() {
    echo "Restarting Community CAD services..."
    docker-compose -f $DOCKER_COMPOSE_FILE restart
    echo "Services restarted."
}

function upgrade() {
    echo "Upgrading Community CAD services..."
    stopServices
    echo "Pulling latest versions of images..."
    docker-compose -f $DOCKER_COMPOSE_FILE pull
    startServices
    echo "Upgrade completed."
}


function askForAction() {
    print_header
    echo "Select an action:"
    echo "   1) Install (x86_64)"
    echo "   2) Start"
    echo "   3) Stop"
    echo "   4) Restart"
    echo "   5) Upgrade"
    echo "   6) Other"
    echo "   7) Exit"
    echo
    read -p "Select an option [2]: " action
    case $action in
        1) install ;;
        2) startServices ;;
        3) stopServices ;;
        4) restartServices ;;
        5) upgrade ;;
        6) otherOptions ;;
        7) exit 0 ;;
        *) echo "Invalid option, please try again."; askForAction ;;
    esac
}

function otherOptions() {
    print_header
    echo "Other Options:"
    echo "   1) Reverse Proxies"
    echo "   2) Reset Install"
    echo "   3) Return to Main Menu"
    echo
    read -p "Select an option: " otherOption
    case $otherOption in
        1) reverseProxyMenu ;;
        2) resetInstall ;;
        3) askForAction ;;
        *) echo "Invalid option, please try again."; otherOptions ;;
    esac
}

function reverseProxyMenu() {
    print_header
    echo "Reverse Proxy Options:"
    echo "   1) Install Caddy Reverse Proxy"
    echo "   2) Install Nginx Reverse Proxy"
    echo "   3) Return to Other Options"
    echo
    read -p "Select an option: " proxyOption
    case $proxyOption in
        1) install_caddy_reverse_proxy ;;
        2) install_nginx_reverse_proxy ;;
        3) otherOptions ;;
        *) echo "Invalid option, please try again."; reverseProxyMenu ;;
    esac
}

function install_caddy_reverse_proxy() {
    echo "Checking if Caddy is already installed..."
    if command -v caddy &> /dev/null; then
        echo "Caddy is already installed."

        # Prompt user for domain name to check if it's already configured
        echo "Please enter your domain name to check configuration (e.g., example.com or www.example.com):"
        read -p "Domain name: " domain

        # Check if domain configuration already exists in Caddyfile
        if grep -q "$domain" /etc/caddy/Caddyfile; then
            echo "The domain $domain is already configured in Caddy."
            return  # Exit the function if domain is already configured
        fi
    else
        echo "Caddy is not installed. Proceeding with installation..."
        # Installation process based on the operating system
        case $OS in
            ubuntu|debian)
                sudo apt update
                sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
                curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo tee /etc/apt/trusted.gpg.d/caddy-stable.asc
                curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
                sudo apt update
                sudo apt install caddy
                ;;
            centos|rocky)
                sudo yum install -y 'dnf-command(copr)'
                sudo dnf copr enable @caddy/caddy
                sudo dnf install -y caddy
                ;;
            *)
                echo "OS not supported for Caddy installation."
                return
                ;;
        esac
    fi

    # Configure Caddy with the new domain
    echo "Configuring Caddy for $domain..."
    sudo tee -a /etc/caddy/Caddyfile <<EOF
$domain {
    reverse_proxy 127.0.0.1:8000
    encode gzip
    header {
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
}
EOF
    echo "Caddy configuration for $domain has been added."
    sudo systemctl reload caddy
    echo "Caddy has been reloaded to apply new configuration."
}


function install_nginx_reverse_proxy() {
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root" 1>&2
        return 1
    fi

    echo "Installing Nginx Reverse Proxy..."

    echo "Please enter your domain name (e.g., example.com or www.example.com):"
    read -p "Domain name: " domain

    if [ -f "/etc/nginx/conf.d/$domain.conf" ]; then
        echo "Nginx configuration for $domain already exists. Skipping configuration."
        return 0
    fi

    # Check if Nginx is installed and install if not
    if command -v nginx &> /dev/null; then
        echo "Nginx is already installed."
    else
        echo "Nginx is not installed. Installing Nginx..."
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$ID
            case $OS in
                ubuntu|debian)
                    sudo apt update
                    sudo apt install -y nginx
                    ;;
                centos|rocky)
                    sudo yum install -y nginx
                    ;;
                *)
                    echo "OS not supported."
                    return 1
                    ;;
            esac
        else
            echo "Cannot determine the operating system."
            return 1
        fi
        echo "Nginx installed successfully."
    fi

    # Install Certbot for SSL
    echo "Installing Certbot..."
    case $OS in
        ubuntu|debian)
            sudo apt install -y certbot python3-certbot-nginx
            ;;
        centos|rocky)
            sudo yum install -y epel-release
            sudo yum install -y certbot python3-certbot-nginx
            ;;
        *)
            echo "OS not supported for Certbot."
            return 1
            ;;
    esac

    # Configure Nginx
    echo "Configuring Nginx..."
    sudo tee /etc/nginx/conf.d/$domain.conf <<EOF
server {
    listen 80;
    server_name $domain;

    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name $domain;

    ssl_certificate /etc/letsencrypt/live/$domain/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
	
	ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_ecdh_curve secp384r1;
    ssl_stapling on;
    ssl_stapling_verify on;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
	
	gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}
EOF
    echo "Nginx configuration has been set."

    # Obtain and install SSL certificate
    sudo certbot --nginx -d $domain --redirect --agree-tos --no-eff-email --keep-until-expiring --non-interactive

    # Reload Nginx to apply changes
    sudo systemctl reload nginx
    echo "Nginx has been reloaded. Your reverse proxy with SSL is now running."

    # Set up automatic renewal of the certificate
    echo "Setting up automatic renewal..."
    sudo tee -a /etc/crontab <<EOF
0 12 * * * root certbot renew --quiet --no-self-upgrade --post-hook 'systemctl reload nginx'
EOF
    echo "Certificate renewal setup is complete."
}


function resetInstall() {
    echo "WARNING: This will completely remove the installation and all associated data."
    read -p "Are you sure you want to reset the installation? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo "Resetting Installation..."
        docker-compose -f $DOCKER_COMPOSE_FILE down
        docker-compose -f $DOCKER_COMPOSE_FILE rm
        sudo rm -rf $CC_INSTALL_DIR
        echo "Installation has been reset. Please reinstall to use Community CAD."
    else
        echo "Reset canceled."
    fi
}
askForAction
