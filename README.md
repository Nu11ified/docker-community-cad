# docker-community-cad
Still a WIP



# Install Information 

### Cloning the Repository and Navigating into It

1.  **Clone the Repository**: Open your terminal and run the following command to clone the repository:

```git clone https://github.com/CommunityCAD/docker-community-cad.git
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

# Discord Oauth URL

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
docker-compose up -d
```
    

### Editing .env for Production

1.  **Open .env File Again**: Reopen the `.env` file for editing:
    
2.  **Change APP\_ENV**: Find the line `APP_ENV=local` and change it to `APP_ENV=production`.
    
3.  **Save and Exit**: Press `Ctrl + X`, then press `Y`, and finally press `Enter` to save and exit.
    

## Reverse Proxies

After you deploy the app, you will need to setup a reverse proxy.

Here is a Nginx Example Below

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

