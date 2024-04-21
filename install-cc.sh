#!/bin/bash

command_exists() {
    type "$1" &> /dev/null
}

echo "Starting the installation script..."

install_docker() {
    if command_exists docker; then
        echo "Docker is already installed."
    else
        echo "Docker is not installed. Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        # Add the current user to the docker group
        sudo usermod -aG docker $USER
        newgrp docker
    fi
}

install_docker_compose() {
    if command_exists docker-compose; then
        echo "Docker Compose is already installed."
    else
        echo "Docker Compose is not installed. Installing Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
}

update_and_install_packages() {
    if [[ $OS == *"Ubuntu"* || $OS == *"Debian"* ]]; then
        sudo apt-get update
        sudo apt-get install -y curl git
    elif [[ $OS == *"CentOS"* || $OS == *"Rocky"* ]]; then
        sudo yum update
        sudo yum install -y curl git
    fi
}

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si)
else
    OS=$(uname -s)
fi

install_docker
install_docker_compose
update_and_install_packages

echo "Cloning the repository..."
git clone https://github.com/CommunityCAD/docker-community-cad.git
cd docker-community-cad || exit 1

if [ ! -f ".env" ]; then
    echo "Creating a new .env file..."
    cp .env.example .env
    echo "A new .env file has been created from .env.example."
fi

# Prompting for App Key
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

{
    sed -i "s|^APP_KEY=.*|APP_KEY=$app_key|" .env
    sed -i "s|^APP_NAME=.*|APP_NAME=$app_name|" .env
    sed -i "s|^APP_URL=.*|APP_URL=$app_url|" .env
    sed -i "s|^STEAM_ALLOWED_HOSTS=.*|STEAM_ALLOWED_HOSTS=$steam_allowed_hosts|" .env
    sed -i "s|^STEAM_CLIENT_SECRET=.*|STEAM_CLIENT_SECRET=$steam_client_secret|" .env
    sed -i "s|^DISCORD_CLIENT_ID=.*|DISCORD_CLIENT_ID=$discord_client_id|" .env
    sed -i "s|^DISCORD_CLIENT_SECRET=.*|DISCORD_CLIENT_SECRET=$discord_client_secret|" .env
    sed -i "s|^DISCORD_BOT_TOKEN=.*|DISCORD_BOT_TOKEN=$discord_bot_token|" .env
    sed -i "s|^OWNER_IDS=.*|OWNER_IDS=$owner_ids|" .env
    sed -i "s|^CAD_TIMEZONE=.*|CAD_TIMEZONE=$cad_timezone|" .env
} > /dev/null 2>&1

echo "Setup is complete. Starting Docker containers..."
docker-compose up -d

echo "Installation and setup are complete. Please Read on how to setup a reverse proxy!"
