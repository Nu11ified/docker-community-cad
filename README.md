# docker-community-cad
Still a WIP


## Requirements

All the items listed below are required to get the CAD up and running smoothly.

- [Git](https://git-scm.com/downloads)
- Docker
- Reverse Proxy (Nginx, Cloudflare Tunnels, etc)

*Docker Install Guides*

- [Docker Desktop (Windows)](https://docker.com/get-started)
- [Docker Ubuntu 20.04 Guide](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-compose-on-ubuntu-20-04)
- [Docker Ubuntu 22.04 Guide](https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-compose-on-ubuntu-22-04)


# Install Information 

### Cloning the Repository and Navigating into It

1.  **Clone the Repository**: Open your terminal and run the following command to clone the repository:

```
git clone https://github.com/CommunityCAD/docker-community-cad.git
```
    
2.  **Navigate into the Repository**: Change your current directory to the cloned repository:

```
cd docker-community-cad
```
    

### Editing the .env File

1.  **Open the .env File**: Use a text editor like Nano or Vim to open the `.env` file:

    ```
    nano .env
    ```
    
2.  **Edit the Environment Variables**:
    
    -   `APP_NAME`: Change the value after the `=` to the desired name of your community.
        
    -   `APP_KEY`: Generate an app key from [https://laravel-encryption-key-generator.vercel.app/](https://laravel-encryption-key-generator.vercel.app/) and paste it after `APP_KEY=`.
        
    -   `APP_URL`: Set the URL of your community CAD after `APP_URL=`. Example: `APP_URL=https://communitycad.app` (Make sure to include https://)
        
    -   `STEAM_CLIENT_SECRET`: Obtain this value from [https://steamcommunity.com/dev/registerkey](https://steamcommunity.com/dev/registerkey) and paste it after `STEAM_CLIENT_SECRET=`.
        
    -   `STEAM_ALLOWED_HOSTS`: Set this to your community CAD URL. Example: `STEAM_ALLOWED_HOSTS=communitycad.app` (Make sure to remove https://)
        
    -   `DISCORD_CLIENT_ID`: Get this value from [https://discord.com/developers/applications](https://discord.com/developers/applications) and paste it after `DISCORD_CLIENT_ID=`.
        
    -   `DISCORD_CLIENT_SECRET`: Obtain this from your Discord application settings and paste it after 
    
    -   `DISCORD_CLIENT_SECRET=`.  Obtain this from your Discord application settings and paste it after 

    -   `DISCORD_BOT_TOKEN`: Set this to your Discord bot token.
        
3.  **Save and Exit**: After making the changes, press `Ctrl + X`, then press `Y` to confirm, and then press `Enter` to save the changes.

### Discord Oauth URL

1.  **Access Discord Developer Portal**:
    
    -   Go to [https://discord.com/developers/applications](https://discord.com/developers/applications) and log in with your Discord account.
2.  **Select Your Application**:
    
    -   If you haven't created an application yet, click on "New Application" and follow the prompts to create one.
    -   Otherwise, click on your existing application from the list.
3.  **Navigate to OAuth2 Section**:
    
    -   Once inside your application dashboard, find and click on the "OAuth2" tab from the left sidebar menu.
4.  **Configure Redirect URL**:
    
    -   Under the "Redirects" section, locate the "Redirects" input field.
    -   Enter the redirect URL with your with `/login/discord/handle` at the end. Example: `https://communitycad.app/login/discord/handle`.
5.  **Save Changes**:
    
    -   After entering the redirect URL, make sure to scroll down to the bottom of the page and click the "Save Changes" button to apply your modifications

### Docker Compose

1.  **Build and Run Docker Containers**: Run the following command to build and start the Docker containers:

```
docker compose up -d
```
    

### Editing .env for Production

1.  **Open .env File Again**: Reopen the `.env` file for editing:
    
2.  **Change APP\_ENV**: Find the line `APP_ENV=local` and change it to `APP_ENV=production`.
    
3.  **Save and Exit**: Press `Ctrl + X`, then press `Y`, and finally press `Enter` to save and exit.
    

# Reverse Proxies

After you deploy the app, you will need to setup a reverse proxy.

Please Check Below For Examples

## Nginx

```
server {
    listen 80;
    server_name communitycad.app;

    # Redirect all HTTP traffic to HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name communitycad.app;

    ssl_certificate /etc/nginx/ssl/communitycad.app/fullchain.cer;
    ssl_certificate_key /etc/nginx/ssl/communitycad.app/private.key;

    # SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_ecdh_curve secp384r1;
    ssl_stapling on;
    ssl_stapling_verify on;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## Cloudflare Tunnels

# Setting up Cloudflare Tunnels for Community CAD

This guide demonstrates the process of configuring Cloudflare Tunnels for your Community CAD instance. By leveraging Cloudflare Tunnels, you can associate a domain name with SSL certification to your Community CAD deployment.

## Prerequisites

- A domain name managed through Cloudflare DNS
- Community CAD Deploymemnt
- [A Cloudflare account](https://dash.cloudflare.com/sign-up)

## Getting Started

### 1. Access Cloudflare Dashboard

1. Navigate to the [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com) and log in using your Cloudflare account credentials.
2. Within your dashboard, navigate to your account, select Zero Trust (one.dash.cloudflare.com), proceed to Networks, and then Tunnels.

### 2. Establish a Cloudflare Tunnel for Community CAD

1. Click on the "Create a Tunnel" option.
2. Provide a name for your tunnel (e.g., "Community CAD Tunnel").
3. Follow the on-screen instructions to install Cloudflared on your server (Install Connector).
4. Upon successful connection, proceed by clicking "Next".

### 3. Configure Domain Name for Community CAD

1. Specify the settings for your domain:

   - **Subdomain:** Choose a subdomain for your Community CAD instance. For instance, if you prefer `cad.example.com`, input `cad`.
   - **Domain:** Enter your Cloudflare-connected domain. For example, if your domain is `cad.example.com`, enter `example.com`.
   - **Path:** Leave this field empty.

   - **Service Type:** Select `HTTP`.
   - **URL:** Set to `localhost:8000`.

2. Save your tunnel settings.
3. Return to the Tunnels dashboard.

Following these configurations, your Community CAD instance will be accessible through the designated domain name, offering SSL encryption for secure access.


## WIP Install Script

We Offer a Install Scrpt for Linux Servers!

*Notice it is a WIP*

- Steps
1. SSH into your Linux server
2. Run the command below
```
curl -o install-cc.sh https://raw.githubusercontent.com/CommunityCAD/docker-community-cad/main/install-cc.sh && chmod +x install-cc.sh && ./install-cc.sh
```
3. Make sure to follow all the configuration guidelines. Refer above to [Editing the .env File](https://github.com/CommunityCAD/docker-community-cad/blob/main/README.md#editing-the-env-file) for more info!


