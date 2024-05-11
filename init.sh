#!/bin/bash

echo "Installing Composer dependencies..."
composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader

if [ ! -f /app_installed/installed ]; then
    echo "Performing first-time setup..."
    
    php artisan migrate:fresh --seed

    php artisan storage:link

    touch /app_installed/installed

    echo "Setup completed."
else
    echo "Performing update..."

    php artisan migrate --force

    echo "Update completed."
fi
