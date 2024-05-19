#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run with sudo or as root."
   exit 1
fi

CURRENT_VERSION="1.0.0"
VERSION_URL="https://raw.githubusercontent.com/CommunityCAD/docker-community-cad/main/cc-manager-version.txt"
SCRIPT_URL="https://raw.githubusercontent.com/CommunityCAD/docker-community-cad/main/cc-manager.sh"

LOG_FILE="/var/log/community-cad-installer.log"

function log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "$LOG_FILE"
}

function check_for_updates() {
    log "Checking for updates..."
    ONLINE_VERSION=$(curl -s $VERSION_URL)

    if [ "$(printf '%s\n' "$ONLINE_VERSION" "$CURRENT_VERSION" | sort -V | head -n1)" != "$CURRENT_VERSION" ]; then
        log "A new version ($ONLINE_VERSION) is available. Updating now..."
        curl -s $SCRIPT_URL -o "$0.tmp"
        chmod +x "$0.tmp"
        mv "$0.tmp" "$0"
        log "Update complete. Restarting the script."
        exec "$0"
        exit
    else
        log "You are using the latest version ($CURRENT_VERSION)."
    fi
}

check_for_updates

SCRIPT_DIR=$PWD
CC_INSTALL_DIR=$PWD/community-cad-storage
DOCKER_COMPOSE_FILE="$CC_INSTALL_DIR/docker-compose.yml"
ENV_FILE="$CC_INSTALL_DIR/.env"

function print_header() {
    clear
    echo "--------------------------------------------"
    echo "  Community CAD Management Tool"
    echo "--------------------------------------------"
}

function command_exists() {
    type "$1" &> /dev/null
}

function install_package() {
    local package=$1
    local install_cmd=$2
    local msg=$3

    if command_exists $package; then
        log "$package is already installed."
    else
        log "$package is not installed. Installing $package... (Please be patient. May take a bit depending on your system!)"
        provide_feedback "$msg" &
        eval $install_cmd
        wait
    fi
}

jokes=("Still thinking... Why do programmers prefer dark mode? Because light attracts bugs!"
       "We are here, you are the next caller in line. Why do Java developers wear glasses? Because they don’t C#!"
       "Processing... Why did the programmer quit his job? Because he didn't get arrays!"
       "Hang tight! Why do Python programmers have low self-esteem? Because they’re constantly comparing their self to others."
       "Almost there! Why did the database administrator leave his wife? She had one-to-many relationships."
       "Just a moment... How many programmers does it take to change a light bulb? None, that's a hardware problem!")

function provide_feedback() {
    local msg=$1
    local jokes_count=${#jokes[@]}
    local joke_index=0

    log "$msg"
    while kill -0 $! 2> /dev/null; do
        sleep 30
        log "${jokes[$joke_index]}"
        joke_index=$(( (joke_index + 1) % jokes_count ))
    done
}

function install_git() {
    install_package git "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git >/dev/null 2>&1 || sudo yum install -y git >/dev/null 2>&1" "Installing git..."
}

function install_curl() {
    install_package curl "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl >/dev/null 2>&1 || sudo yum install -y curl >/dev/null 2>&1" "Installing curl..."
}

function install_docker() {
    if command_exists docker; then
        log "Docker is already installed."
        return 0
    fi

    log "Installing Docker... (Please be patient. May take a bit depending on your system!)"
    provide_feedback "Installing Docker..." &
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        case $ID in
            ubuntu|debian)
                sudo DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null 2>&1
                sudo DEBIAN_FRONTEND=noninteractive apt-get install -y apt-transport-https ca-certificates curl software-properties-common >/dev/null 2>&1
                sudo DEBIAN_FRONTEND=noninteractive curl -fsSL https://download.docker.com/linux/${ID}/gpg | sudo apt-key add - >/dev/null 2>&1
                sudo DEBIAN_FRONTEND=noninteractive add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/${ID} $(lsb_release -cs) stable" >/dev/null 2>&1
                sudo DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null 2>&1
                sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io >/dev/null 2>&1
                ;;
            centos|rocky|rhel)
                sudo yum install -y yum-utils device-mapper-persistent-data lvm2 >/dev/null 2>&1
                sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >/dev/null 2>&1
                sudo yum install -y docker-ce docker-ce-cli containerd.io >/dev/null 2>&1
                sudo systemctl start docker >/dev/null 2>&1
                sudo systemctl enable docker >/dev/null 2>&1
                ;;
            fedora)
                sudo dnf -y install dnf-plugins-core >/dev/null 2>&1
                sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo >/dev/null 2>&1
                sudo dnf install -y docker-ce docker-ce-cli containerd.io >/dev/null 2>&1
                sudo systemctl start docker >/dev/null 2>&1
                sudo systemctl enable docker >/dev/null 2>&1
                ;;
            arch|manjaro)
                sudo pacman -Syu --noconfirm docker >/dev/null 2>&1
                sudo systemctl start docker.service >/dev/null 2>&1
                sudo systemctl enable docker.service >/dev/null 2>&1
                ;;
            *)
                log "OS not supported for Docker installation. Please install Docker manually."
                return 1
                ;;
        esac
        wait
        if command_exists docker; then
            log "Docker installed successfully."
        else
            log "Failed to install Docker."
            return 1
        fi
    else
        log "Cannot determine the operating system."
        return 1
    fi
}

function install_docker_compose() {
    install_package docker-compose "sudo curl -L \"https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)\" -o /usr/local/bin/docker-compose >/dev/null 2>&1 && sudo chmod +x /usr/local/bin/docker-compose >/dev/null 2>&1" "Installing Docker Compose..."
}

function update_packages() {
    log "Updating system packages, please wait... (Please be patient. May take a bit depending on your system!)"
    provide_feedback "Updating system packages..." &
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        case $ID in
            ubuntu|debian)
                sudo DEBIAN_FRONTEND=noninteractive apt-get update -y >/dev/null 2>&1
                sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y >/dev/null 2>&1
                ;;
            centos|rocky|rhel)
                sudo yum update -y >/dev/null 2>&1
                sudo yum upgrade -y >/dev/null 2>&1
                ;;
            fedora)
                sudo dnf update -y >/dev/null 2>&1
                sudo dnf upgrade -y >/dev/null 2>&1
                ;;
            arch|manjaro)
                sudo pacman -Syu --noconfirm >/dev/null 2>&1
                ;;
            *)
                log "Operating system not supported for automatic package updates."
                return 1
                ;;
        esac
        wait
        log "System packages have been updated."
    else
        log "Cannot determine the operating system."
        return 1
    fi
}

function escape_for_sed() {
    echo "$1" | sed -e 's/[\/&:]/\\&/g'
}

function configure_environment() {
    log "Configuring environment variables..."

    if [ ! -f "$ENV_FILE" ]; then
        log "No .env file found in $CC_INSTALL_DIR. Please check your installation."
        return 1  
    fi

    generate_password() {
        cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 20 | head -n 1
    }

    db_password=$(generate_password)
    log "Generated secure DB password."

    validate_url() {
        if [[ "$1" =~ ^https://.+ ]]; then return 0; else return 1; fi
    }

    log "Setting up environment variables:"
    read -p "Enter your APP_NAME (Community Name): " app_name
    echo "Please generate an APP_KEY from https://laravel-encryption-key-generator.vercel.app/"
    read -p "Enter the generated APP_KEY: " app_key
    read -p "Enter your APP_URL (e.g., https://communitycad.app): " app_url
    until validate_url "$app_url"; do
        echo "Invalid URL. Please ensure it starts with https://"
        read -p "Enter your APP_URL (e.g., https://communitycad.app): " app_url
    done

    log "Collecting other environment variables..."
    read -p "Enter your STEAM_CLIENT_SECRET (from https://steamcommunity.com/dev/registerkey): " steam_client_secret
    read -p "Enter your DISCORD_CLIENT_ID: " discord_client_id
    read -p "Enter your DISCORD_CLIENT_SECRET: " discord_client_secret
    read -p "Enter your DISCORD_BOT_TOKEN: " discord_bot_token
    read -p 'Enter your OWNER_IDS ("ID1|ID2"): ' owner_ids
    read -p "Enter your CAD_TIMEZONE (e.g., America/Chicago): " cad_timezone
    discord_redirect_uri="${app_url}/login/discord/handle"

    cp "$ENV_FILE" "${ENV_FILE}.bak"
    temp_env="$(mktemp)"

    while IFS= read -r line || [[ -n "$line" ]]; do
        key="${line%%=*}"
        case "$key" in
            'APP_NAME') line="APP_NAME=$app_name" ;;
            'APP_KEY') line="APP_KEY=$app_key" ;;
            'APP_URL') line="APP_URL=$app_url" ;;
            'STEAM_ALLOWED_HOSTS') line="STEAM_ALLOWED_HOSTS=${app_url#https://}" ;;
            'STEAM_CLIENT_SECRET') line="STEAM_CLIENT_SECRET=$steam_client_secret" ;;
            'DISCORD_CLIENT_ID') line="DISCORD_CLIENT_ID=$discord_client_id" ;;
            'DISCORD_CLIENT_SECRET') line="DISCORD_CLIENT_SECRET=$discord_client_secret" ;;
            'DISCORD_BOT_TOKEN') line="DISCORD_BOT_TOKEN=$discord_bot_token" ;;
            'OWNER_IDS') line="OWNER_IDS=$owner_ids" ;;
            'DISCORD_REDIRECT_URI') line="DISCORD_REDIRECT_URI=$discord_redirect_uri" ;;
            'CAD_TIMEZONE') line="CAD_TIMEZONE=$cad_timezone" ;;
            'DB_PASSWORD') line="DB_PASSWORD=$db_password" ;;
        esac
        echo "$line" >> "$temp_env"
    done < "$ENV_FILE"

    mv "$temp_env" "$ENV_FILE"
    log "Environment variables configured successfully."
}

function install() {
    log "Starting the installation of Community CAD on x86_64 architecture..."
    if [ ! -d "$CC_INSTALL_DIR" ]; then
        mkdir -p "$CC_INSTALL_DIR"
    else
        log "Installation directory already exists. Using existing directory."
    fi
    cd "$CC_INSTALL_DIR"

    if [ -d ".git" ]; then
        log "Community CAD repository already exists in the installation directory."
        log "Installation cannot proceed. If you wish to reinstall, please remove the existing directory first."
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
        log "Cloning the Community CAD repository..."
        provide_feedback "Cloning the Community CAD repository..." &
        git clone https://github.com/CommunityCAD/docker-community-cad.git "$CC_INSTALL_DIR"
        wait
    else
        log "Repository already cloned. Updating repository..."
        git pull
    fi

   if [ ! -f ".env" ]; then
       log "No .env file found in the repository. Please check your installation."
       return
   fi

    configure_environment

    sleep 5

    log "Setup is complete. Starting Docker containers..."
    provide_feedback "Starting Docker containers..." &
    docker-compose up -d
    wait
    log "Installation and setup are complete. Community CAD is now running."

    read -p "Would you like to install a reverse proxy with Caddy? [y/N] " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        install_caddy_reverse_proxy
    else
        log "Skipping Caddy reverse proxy installation."
    fi
}

function install_caddy_reverse_proxy() {
    echo "Checking if Caddy is already installed..."
    if command -v caddy &> /dev/null; then
        log "Caddy is already installed."

        echo "Please enter your domain name to check configuration (e.g., example.com or www.example.com):"
        read -p "Domain name: " domain

        if grep -q "$domain" /etc/caddy/Caddyfile; then
            log "The domain $domain is already configured in Caddy."
            return  
        fi
    else
        log "Caddy is not installed. Proceeding with installation..."
        if [ -f /etc/os-release ]; then
            source /etc/os-release
            case $ID in
                ubuntu|debian)
                    provide_feedback "Installing Caddy on Ubuntu/Debian..." &
                    sudo DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null 2>&1
                    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl >/dev/null 2>&1
                    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg >/dev/null 2>&1
                    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null 2>&1
                    sudo DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null 2>&1
                    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y caddy >/dev/null 2>&1
                    wait
                    ;;
                centos|rocky)
                    provide_feedback "Installing Caddy on CentOS/Rocky..." &
                    sudo yum install -y 'dnf-command(copr)' >/dev/null 2>&1
                    sudo dnf copr enable @caddy/caddy >/dev/null 2>&1
                    sudo dnf install -y caddy >/dev/null 2>&1
                    wait
                    ;;
                *)
                    log "OS not supported for Caddy installation."
                    return
                    ;;
            esac
        else
            log "Cannot determine the operating system."
            return
        fi
    fi

    echo "Please enter your domain name (e.g., example.com or www.example.com):"
    read -p "Domain name: " domain

    if [ -z "$domain" ]; then
        log "Domain name cannot be empty. Aborting installation."
        return
    fi

    echo "Please enter your email for SSL certificate notifications (e.g., user@example.com):"
    read -p "Email: " email

    if [ -z "$email" ]; then
        log "Email cannot be empty. Aborting installation."
        return
    fi

    log "Configuring Caddy for $domain..."

    sudo mkdir -p /etc/caddy

    sudo tee /etc/caddy/Caddyfile >/dev/null <<EOF
$domain {
    reverse_proxy https://127.0.0.1:8000 {
        transport http {
            tls_insecure_skip_verify
        }
    }
    encode gzip
    header {
        X-Content-Type-Options "nosniff"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
        Strict-Transport-Security "max-age=31536000;"
    }
    tls $email {
        curves secp384r1
    }
    log {
        output file /var/log/caddy/$domain.log
    }
}
EOF
    log "Caddy configuration for $domain has been added."

    sudo systemctl reload caddy >/dev/null 2>&1
    log "Caddy has been reloaded to apply new configuration."
}

function install_nginx_reverse_proxy() {
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root" 1>&2
        return 1
    fi

    log "Installing Nginx Reverse Proxy..."

    echo "Please enter your domain name (e.g., example.com or www.example.com):"
    read -p "Domain name: " domain

    if [ -f "/etc/nginx/conf.d/$domain.conf" ]; then
        log "Nginx configuration for $domain already exists. Skipping configuration."
        return 0
    fi

    if command -v nginx &> /dev/null; then
        log "Nginx is already installed."
    else
        log "Nginx is not installed. Installing Nginx..."
        provide_feedback "Installing Nginx..." &
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$ID
            case $OS in
                ubuntu|debian)
                    sudo DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null 2>&1
                    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y nginx >/dev/null 2>&1
                    ;;
                centos|rocky)
                    sudo yum install -y nginx >/dev/null 2>&1
                    ;;
                *)
                    log "OS not supported."
                    return 1
                    ;;
            esac
        else
            log "Cannot determine the operating system."
            return 1
        fi
        wait
        log "Nginx installed successfully."
    fi

    log "Installing Certbot..."
    case $OS in
        ubuntu|debian)
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y certbot python3-certbot-nginx >/dev/null 2>&1
            ;;
        centos|rocky)
            sudo yum install -y epel-release >/dev/null 2>&1
            sudo yum install -y certbot python3-certbot-nginx >/dev/null 2>&1
            ;;
        *)
            log "OS not supported for Certbot."
            return 1
            ;;
    esac

    log "Configuring Nginx..."
    sudo tee /etc/nginx/conf.d/$domain.conf >/dev/null <<EOF
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
        proxy_pass https://127.0.0.1:8000;
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
    log "Nginx configuration has been set."

    sudo certbot --nginx -d $domain --redirect --agree-tos --no-eff-email --keep-until-expiring --non-interactive >/dev/null 2>&1

    sudo systemctl reload nginx >/dev/null 2>&1
    log "Nginx has been reloaded. Your reverse proxy with SSL is now running."

    log "Setting up automatic renewal..."
    sudo tee -a /etc/crontab >/dev/null <<EOF
0 12 * * * root certbot renew --quiet --no-self-upgrade --post-hook 'systemctl reload nginx'
EOF
    log "Certificate renewal setup is complete."
}

function resetInstall() {
    log "WARNING: This will completely remove the installation and all associated data."
    read -p "Are you sure you want to reset the installation? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        log "Resetting Installation..."
        sudo docker-compose -f $DOCKER_COMPOSE_FILE down --volumes >/dev/null 2>&1
        sudo docker-compose -f $DOCKER_COMPOSE_FILE rm -f >/dev/null 2>&1
        sudo rm -rf $CC_INSTALL_DIR
        log "Installation has been reset. Please reinstall to use Community CAD."
    else
        log "Reset canceled."
    fi
}

function startServices() {
    log "Starting Community CAD services..."
    sudo docker-compose -f $DOCKER_COMPOSE_FILE up -d
    log "Services started."
}

function stopServices() {
    log "Stopping Community CAD services..."
    sudo docker-compose -f $DOCKER_COMPOSE_FILE down
    log "Services stopped."
}

function restartServices() {
    log "Restarting Community CAD services..."
    sudo docker-compose -f $DOCKER_COMPOSE_FILE restart
    log "Services restarted."
}

function upgrade() {
    log "Upgrading Community CAD services..."
    stopServices
    log "Pulling latest versions of images..."
    provide_feedback "Pulling latest versions of images..." &
    sudo docker-compose -f $DOCKER_COMPOSE_FILE pull
    wait
    startServices
    log "Upgrade completed."
}

function askForAction() {
    print_header
    echo "Select an action:"
    echo "   1) Install Community CAD"
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
    echo "   2) Update System Packages"
    echo "   3) Reset Install"
    echo "   4) Return to Main Menu"
    echo
    read -p "Select an option: " otherOption
    case $otherOption in
        1) reverseProxyMenu ;;
        2) update_packages ;;
        3) resetInstall ;;
        4) askForAction ;;
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

askForAction
