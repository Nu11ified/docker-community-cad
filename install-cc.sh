#!/bin/bash

command_exists() {
    type "$1" &> /dev/null ;
}

echo "Starting the installation script..."

install_docker() {
    if command_exists docker ; then
        echo "Docker is already installed."
    else
        echo "Docker is not installed. Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        # Add the current user to the docker group
        sudo usermod -aG docker $USER
        newgrp docker
    fi
}

install_docker_compose() {
    if command_exists docker-compose ; then
        echo "Docker Compose is already installed."
    else
        echo "Docker Compose is not installed. Installing Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
}

OS=$(awk -F= '/^NAME/{print $2}' /etc/os-release)

if [[ $OS == *"Ubuntu"* || $OS == *"Debian"* ]]; then
    sudo apt-get update
    sudo apt-get install -y curl git
elif [[ $OS == *"CentOS"* || $OS == *"Rocky"* ]]; then
    sudo yum update
    sudo yum install -y curl git
fi

install_docker
install_docker_compose

if [ ! -d "./docker-community-cad" ]; then
    echo "Cloning the repository..."
    git clone https://github.com/DrMxrcy/docker-community-cad.git
fi

cd docker-community-cad

if [ ! -f ".env" ]; then
    cp .env.example .env
    echo "A new .env file has been created from .env.example."
fi

echo "Please enter the required environment variables:"
read -p "Enter your APP_NAME: " app_name
read -p "Enter your APP_URL: " app_url
read -p "URL For Steam without https:// communitycad.app: " steam_allowed_hosts
echo "For STEAM_CLIENT_SECRET, visit https://steamcommunity.com/dev/registerkey to register and obtain a key"
read -p "Enter your STEAM_CLIENT_SECRET: " steam_client_secret
echo "For DISCORD_CLIENT_ID, DISCORD_CLIENT_SECRET, and DISCORD_BOT_TOKEN, visit https://discord.com/developers/applications to create an application"
read -p "Enter your DISCORD_CLIENT_ID: " discord_client_id
read -p "Enter your DISCORD_CLIENT_SECRET: " discord_client_secret
read -p "Enter your DISCORD_BOT_TOKEN: " discord_bot_token
read -p "Enter your OWNER_IDS (comma-separated): " owner_ids
read -p "Enter your CAD_TIMEZONE: " cad_timezone

# Write to .env file
{
    echo "APP_NAME=$app_name"
    echo "APP_URL=$app_url"
    echo "STEAM_ALLOWED_HOSTS=$steam_allowed_hosts"
    echo "STEAM_CLIENT_SECRET=$steam_client_secret"
    echo "DISCORD_CLIENT_ID=$discord_client_id"
    echo "DISCORD_CLIENT_SECRET=$discord_client_secret"
    echo "DISCORD_BOT_TOKEN=$discord_bot_token"
    echo "OWNER_IDS=$owner_ids"
    echo "CAD_TIMEZONE=$cad_timezone"
} >> .env

echo "Setup is complete. Starting Docker containers..."
docker-compose up -d

echo "Installation and setup are complete. Your application should now be running."
