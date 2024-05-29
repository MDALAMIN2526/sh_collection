#!/bin/bash

# Update and upgrade the system packages
sudo apt update && sudo apt upgrade -y

# Install required dependencies
sudo apt install -y software-properties-common curl

# Add PHP repository
sudo add-apt-repository ppa:ondrej/php -y

# Update package list again
sudo apt update

# Install PHP and required PHP extensions
sudo apt install -y php8.2 php8.2-fpm php8.2-cli php8.2-mysql php8.2-xml php8.2-mbstring php8.2-curl php8.2-zip php8.2-bcmath php8.2-json php8.2-tokenizer php8.2-common php8.2-soap

# Install Composer (Dependency Manager for PHP)
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# Install Nginx
sudo apt install -y nginx

# Install MySQL
sudo apt install -y mysql-server
sudo mysql_secure_installation

# Create MySQL database and user for Laravel
MYSQL_ROOT_PASSWORD="your_root_password"
LARAVEL_DB="laravel"
LARAVEL_USER="laraveluser"
LARAVEL_PASSWORD="your_laravel_password"

sudo mysql -u root -p$MYSQL_ROOT_PASSWORD <<MYSQL_SCRIPT
CREATE DATABASE $LARAVEL_DB;
CREATE USER '$LARAVEL_USER'@'localhost' IDENTIFIED BY '$LARAVEL_PASSWORD';
GRANT ALL PRIVILEGES ON $LARAVEL_DB.* TO '$LARAVEL_USER'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Setup Nginx configuration for Laravel
LARAVEL_DOMAIN="your_laravel_domain.com"
NGINX_CONF_PATH="/etc/nginx/sites-available/$LARAVEL_DOMAIN"

sudo tee $NGINX_CONF_PATH > /dev/null <<EOF
server {
    listen 80;
    server_name $LARAVEL_DOMAIN;
    root /var/www/$LARAVEL_DOMAIN/public;

    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Enable Nginx site configuration
sudo ln -s $NGINX_CONF_PATH /etc/nginx/sites-enabled/

# Remove default Nginx site
sudo rm /etc/nginx/sites-enabled/default

# Restart Nginx to apply changes
sudo systemctl restart nginx

# Set up a basic Laravel project
LARAVEL_PROJECT_PATH="/var/www/$LARAVEL_DOMAIN"

sudo mkdir -p $LARAVEL_PROJECT_PATH
sudo chown -R $USER:$USER $LARAVEL_PROJECT_PATH

cd $LARAVEL_PROJECT_PATH
composer create-project --prefer-dist laravel/laravel .

# Set permissions for Laravel storage and cache directories
sudo chown -R www-data:www-data $LARAVEL_PROJECT_PATH/storage $LARAVEL_PROJECT_PATH/bootstrap/cache
sudo chmod -R 775 $LARAVEL_PROJECT_PATH/storage $LARAVEL_PROJECT_PATH/bootstrap/cache

# Setup Laravel environment file
cp .env.example .env
php artisan key:generate

# Update .env file with database credentials
sed -i "s/DB_DATABASE=laravel/DB_DATABASE=$LARAVEL_DB/" .env
sed -i "s/DB_USERNAME=root/DB_USERNAME=$LARAVEL_USER/" .env
sed -i "s/DB_PASSWORD=/DB_PASSWORD=$LARAVEL_PASSWORD/" .env

# Migrate database
php artisan migrate

echo "Laravel 10 installation with Nginx setup completed."
