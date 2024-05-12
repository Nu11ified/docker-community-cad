#!/bin/bash

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run with sudo or as root."
   exit 1
fi

CURRENT_VERSION="1.0.0"
VERSION_URL="https://raw.githubusercontent.com/CommunityCAD/docker-community-cad/main/cc-manager-version.txt"  # URL to a file containing the latest version and download link
SCRIPT_URL="https://raw.githubusercontent.com/CommunityCAD/docker-community-cad/main/cc-manager.sh"     # Direct link to the latest script version

function check_for_updates() {
    echo "Checking for updates..."
    readarray -t version_data < <(curl -s $VERSION_URL)

    ONLINE_VERSION=${version_data[0]}
    SCRIPT_URL=${version_data[1]}

    if [ "$(printf '%s\n' "$ONLINE_VERSION" "$CURRENT_VERSION" | sort -V | head -n1)" != "$CURRENT_VERSION" ]; then
        echo "A new version ($ONLINE_VERSION) is available. Updating now..."
        curl -s $SCRIPT_URL -o "$0.tmp"
        chmod +x "$0.tmp"
        mv "$0.tmp" "$0"
        echo "Update complete. Restarting the script."
        exec "$0"
        exit
    else
        echo "You are using the latest version ($CURRENT_VERSION)."
    fi
}

check_for_updates

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
    echo "Git is not installed. Installing Git... (Please be patient. May take a bit depending on your system!)"
    if [[ $OS == *"Ubuntu"* || $OS == *"Debian"* ]]; then
      sudo apt-get install -y git >/dev/null 2>&1
    elif [[ $OS == *"CentOS"* || $OS == *"Rocky"* ]]; then
      sudo yum install -y git >/dev/null 2>&1
    fi
  fi
}

function install_curl() {
  if command_exists curl; then
    command echo "Curl is already installed."
  else
    echo "Curl is not installed. Installing Curl... (Please be patient. May take a bit!)"
    if [[ $OS == *"Ubuntu"* || $OS == *"Debian"* ]]; then
      sudo apt-get install -y curl >/dev/null 2>&1
    elif [[ $OS == *"CentOS"* || $OS == *"Rocky"* ]]; then
      sudo yum install -y curl >/dev/null 2>&1
    fi
  fi
}

function install_docker() {
    if command_exists docker; then
        echo "Docker is already installed."
        return 0
    fi

    echo "Installing Docker... (Please be patient. May take a bit depending on your system!)"

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
                echo "OS not supported for Docker installation. Please install Docker manually."
                return 1
                ;;
        esac
        if command_exists docker; then
            echo "Docker installed successfully."
        else
            echo "Failed to install Docker."
            return 1
        fi
    else
        echo "Cannot determine the operating system."
        return 1
    fi
}



function install_docker_compose() {
  if command_exists docker-compose; then
    command echo "Docker Compose is already installed."
  else
    echo "Docker Compose is not installed. Installing Docker Compose... (Please be patient. May take a bit depending on your system!)"
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose >/dev/null 2>&1
    sudo chmod +x /usr/local/bin/docker-compose >/dev/null 2>&1
  fi
}

function update_packages() {
    echo "Updating system packages, please wait... (Please be patient. May take a bit depending on your system!)"

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
                echo "Operating system not supported for automatic package updates."
                return 1
                ;;
        esac
        echo "System packages have been updated."
    else
        echo "Cannot determine the operating system."
        return 1
    fi
}

function escape_for_sed() {
    # This function now escapes all potentially problematic characters for sed
    echo "$1" | sed -e 's/[\/&:]/\\&/g'
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
    echo "Generated secure DB password."

    validate_url() {
        if [[ "$1" =~ ^https://.+ ]]; then return 0; else return 1; fi
    }

    echo "Setting up environment variables:"
    read -p "Enter your APP_NAME (Community Name): " app_name
    echo "Please generate an APP_KEY from https://laravel-encryption-key-generator.vercel.app/"
    read -p "Enter the generated APP_KEY: " app_key
    read -p "Enter your APP_URL (e.g., https://communitycad.app): " app_url
    until validate_url "$app_url"; do
        echo "Invalid URL. Please ensure it starts with https://"
        read -p "Enter your APP_URL (e.g., https://communitycad.app): " app_url
    done
    read -p "Enter your STEAM_CLIENT_SECRET (from https://steamcommunity.com/dev/registerkey): " steam_client_secret
    read -p "Enter your DISCORD_CLIENT_ID: " discord_client_id
    read -p "Enter your DISCORD_CLIENT_SECRET: " discord_client_secret
    read -p "Enter your DISCORD_BOT_TOKEN: " discord_bot_token
    read -p 'Enter your OWNER_IDS ("ID1|ID2"): ' owner_ids
    read -p "Enter your CAD_TIMEZONE (e.g., America/Chicago): " cad_timezone

    steam_allowed_hosts="${app_url#https://}"

    app_name=$(escape_for_sed "$app_name")
    app_key=$(escape_for_sed "$app_key")
    app_url=$(escape_for_sed "$app_url")
    steam_allowed_hosts=$(escape_for_sed "$steam_allowed_hosts")
    steam_client_secret=$(escape_for_sed "$steam_client_secret")
    discord_client_id=$(escape_for_sed "$discord_client_id")
    discord_client_secret=$(escape_for_sed "$discord_client_secret")
    discord_bot_token=$(escape_for_sed "$discord_bot_token")
    owner_ids=$(escape_for_sed "$owner_ids")
    cad_timezone=$(escape_for_sed "$cad_timezone")

    sed -i "s|^APP_NAME=.*|APP_NAME=$app_name|" "$ENV_FILE"
    sed -i "s|^APP_KEY=.*|APP_KEY=$app_key|" "$ENV_FILE"
    sed -i "s|^APP_URL=.*|APP_URL=$app_url|" "$ENV_FILE"
    sed -i "s|^STEAM_ALLOWED_HOSTS=.*|STEAM_ALLOWED_HOSTS=$steam_allowed_hosts|" "$ENV_FILE"
    sed -i "s|^STEAM_CLIENT_SECRET=.*|STEAM_CLIENT_SECRET=$steam_client_secret|" "$ENV_FILE"
    sed -i "s|^DISCORD_CLIENT_ID=.*|DISCORD_CLIENT_ID=$discord_client_id|" "$ENV_FILE"
    sed -i "s|^DISCORD_CLIENT_SECRET=.*|DISCORD_CLIENT_SECRET=$discord_client_secret|" "$ENV_FILE"
    sed -i "s|^DISCORD_BOT_TOKEN=.*|DISCORD_BOT_TOKEN=$discord_bot_token|" "$ENV_FILE"
    sed -i "s|^OWNER_IDS=.*|OWNER_IDS=$owner_ids|" "$ENV_FILE"
    sed -i "s|^CAD_TIMEZONE=.*|CAD_TIMEZONE=$cad_timezone|" "$ENV_FILE"
    sed -i "s|^DB_PASSWORD=.*|DB_PASSWORD=$db_password|" "$ENV_FILE"

    echo "Environment variables configured successfully."
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

    sleep 5

    echo "Setup is complete. Starting Docker containers..."
    docker-compose up -d
    echo "Installation and setup are complete. Community CAD is now running."

    install_reverse_proxy
}

function install_reverse_proxy() {
    echo "Would you like to install a reverse proxy with Caddy? [y/N]"
    read -p "Choice: " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        if command -v caddy &> /dev/null; then
            echo "Caddy is already installed. Skipping installation."
        else
            echo "Caddy is not installed. Proceeding with installation..."
            if [ -f /etc/os-release ]; then
                source /etc/os-release
                case $ID in
                    ubuntu|debian)
                        sudo apt-get update >/dev/null 2>&1
                        sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl >/dev/null 2>&1
                        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo tee /etc/apt/trusted.gpg.d/caddy-stable.asc >/dev/null 2>&1
                        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null 2>&1
                        sudo apt-get update >/dev/null 2>&1
                        sudo apt-get install -y caddy >/dev/null 2>&1
                        ;;
                    centos|rocky)
                        sudo yum install -y 'dnf-command(copr)' >/dev/null 2>&1
                        sudo dnf copr enable @caddy/caddy >/dev/null 2>&1
                        sudo dnf install -y caddy >/dev/null 2>&1
                        ;;
                    *)
                        echo "OS not supported for Caddy installation."
                        return
                        ;;
                esac
            else
                echo "Cannot determine the operating system."
                return
            fi
        fi

        echo "Please enter your domain name (e.g., example.com or www.example.com):"
        read -p "Domain name: " domain
        if [ -z "$domain" ]; then
            echo "Domain name cannot be empty. Aborting installation."
            return
        fi

        echo "Checking if A record exists for the domain..."
        if ! host -t A "$domain" &> /dev/null; then
            echo "No A record found for $domain. Please ensure the A record is correctly set before proceeding."
            return
        fi
        echo "A record exists for $domain."

        echo "Please enter your email for SSL certificate notifications:"
        read -p "Email: " email
        if [ -z "$email" ]; then
            echo "Email cannot be empty. Aborting installation."
            return
        fi

        echo "Configuring Caddy..."
        sudo mkdir -p /etc/caddy
        sudo tee /etc/caddy/Caddyfile <<EOF
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
        echo "Caddyfile has been configured."
        sudo systemctl restart caddy >/dev/null 2>&1
        echo "Caddy has been restarted. Your reverse proxy is now running."
    fi
}


function startServices() {
    echo "Starting Community CAD services..."
    sudo docker-compose -f $DOCKER_COMPOSE_FILE up -d
    echo "Services started."
}

function stopServices() {
    echo "Stopping Community CAD services..."
    sudo docker-compose -f $DOCKER_COMPOSE_FILE down
    echo "Services stopped."
}

function restartServices() {
    echo "Restarting Community CAD services..."
    sudo docker-compose -f $DOCKER_COMPOSE_FILE restart
    echo "Services restarted."
}

function upgrade() {
    echo "Upgrading Community CAD services..."
    stopServices
    echo "Pulling latest versions of images..."
    sudo docker-compose -f $DOCKER_COMPOSE_FILE pull
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



function install_caddy_reverse_proxy() {
    echo "Checking if Caddy is already installed..."
    if command -v caddy &> /dev/null; then
        echo "Caddy is already installed."

        echo "Please enter your domain name to check configuration (e.g., example.com or www.example.com):"
        read -p "Domain name: " domain

        if grep -q "$domain" /etc/caddy/Caddyfile; then
            echo "The domain $domain is already configured in Caddy."
            return  
        fi
    else
        echo "Caddy is not installed. Proceeding with installation..."
        if [ -f /etc/os-release ]; then
            source /etc/os-release
            case $ID in
                ubuntu|debian)
                    sudo DEBIAN_FRONTEND=noninteractive apt update >/dev/null 2>&1
                    sudo DEBIAN_FRONTEND=noninteractive apt install -y debian-keyring debian-archive-keyring apt-transport-https curl >/dev/null 2>&1
                    DEBIAN_FRONTEND=noninteractive curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg >/dev/null 2>&1
                    DEBIAN_FRONTEND=noninteractive curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null 2>&1
                    sudo DEBIAN_FRONTEND=noninteractive apt update >/dev/null 2>&1
                    sudo DEBIAN_FRONTEND=noninteractive apt install -y caddy >/dev/null 2>&1
                    ;;
                centos|rocky)
                    sudo yum install -y 'dnf-command(copr)' >/dev/null 2>&1
                    sudo dnf copr enable @caddy/caddy >/dev/null 2>&1
                    sudo dnf install -y caddy >/dev/null 2>&1
                    ;;
                *)
                    echo "OS not supported for Caddy installation."
                    return
                    ;;
            esac
        else
            echo "Cannot determine the operating system."
            return
        fi
    fi

    echo "Please enter your domain name (e.g., example.com or www.example.com):"
    read -p "Domain name: " domain

    # Check if domain has been provided
    if [ -z "$domain" ]; then
        echo "Domain name cannot be empty. Aborting installation."
        return
    fi

    echo "Please enter your email for SSL certificate notifications (e.g., user@example.com):"
    read -p "Email: " email

    # Check if email has been provided
    if [ -z "$email" ]; then
        echo "Email cannot be empty. Aborting installation."
        return
    fi

    echo "Configuring Caddy for $domain..."

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
    echo "Caddy configuration for $domain has been added."

    # Reload Caddy to apply the new configuration
    sudo systemctl reload caddy >/dev/null 2>&1
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
        sudo docker-compose -f $DOCKER_COMPOSE_FILE down --volumes
        sudo docker-compose -f $DOCKER_COMPOSE_FILE rm
        sudo rm -rf $CC_INSTALL_DIR
        echo "Installation has been reset. Please reinstall to use Community CAD."
    else
        echo "Reset canceled."
    fi
}

askForAction
