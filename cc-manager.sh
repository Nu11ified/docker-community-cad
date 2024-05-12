#!/bin/bash

SCRIPT_DIR=$PWD
CC_INSTALL_DIR=$PWD/community-cad
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
        echo "Git is already installed."
    else
        echo "Git is not installed. Installing Git..."
        if [[ $OS == *"Ubuntu"* || $OS == *"Debian"* ]]; then
            sudo apt-get update
            sudo apt-get install -y git
        elif [[ $OS == *"CentOS"* || $OS == *"Rocky"* ]]; then
            sudo yum update
            sudo yum install -y git
        fi
    fi
}

function install_docker() {
    if command_exists docker; then
        echo "Docker is already installed."
    else
        echo "Docker is not installed. Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        newgrp docker
    fi
}

function install_docker_compose() {
    if command_exists docker-compose; then
        echo "Docker Compose is already installed."
    else
        echo "Docker Compose is not installed. Installing Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
}

function update_and_install_packages() {
    if [[ $OS == *"Ubuntu"* || $OS == *"Debian"* ]]; then
        sudo apt-get update
        sudo apt-get install -y curl git
    elif [[ $OS == *"CentOS"* || $OS == *"Rocky"* ]]; then
        sudo yum update
        sudo yum install -y curl git
    fi
}

function configure_environment() {
    echo "Configuring environment variables..."
    
    if [ ! -f "$ENV_FILE" ]; then
        echo "No .env file found in $CC_INSTALL_DIR. Please check your installation."
        return 1  
    fi


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
}

function install() {
    echo "Starting the installation of Community CAD on x86_64 architecture..."
    if [ ! -d "$CC_INSTALL_DIR" ]; then
        mkdir -p "$CC_INSTALL_DIR"
    else
        echo "Installation directory already exists. Using existing directory."
    fi
    cd "$CC_INSTALL_DIR"

    # Prevent installation if the repository is already cloned
    if [ -d ".git" ]; then
        echo "Community CAD repository already exists in the installation directory."
        echo "Installation cannot proceed. If you wish to reinstall, please remove the existing directory first."
        return
    fi

    # Detect OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
    else
        OS=$(uname -s)
    fi

    install_git
    install_docker
    install_docker_compose
    update_and_install_packages

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
        echo "Installing Caddy..."

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

        if command -v caddy &> /dev/null; then
            echo "Caddy installed successfully."

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
        else
            echo "Caddy could not be installed."
        fi
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
    echo "   6) Exit"
    echo
    read -p "Select an option [2]: " action
    case $action in
        1) install ;;
        2) startServices ;;
        3) stopServices ;;
        4) restartServices ;;
        5) upgrade ;;
        6) exit 0 ;;
        *) echo "Invalid option, please try again."; askForAction ;;
    esac
}

askForAction
