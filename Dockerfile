FROM php:8.2-apache

ENV APACHE_DOCUMENT_ROOT=/var/www/html \
    COMPOSER_ALLOW_SUPERUSER=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      git unzip curl ca-certificates imagemagick libmagickwand-dev \
      libicu-dev libzip-dev libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" bcmath exif gd intl mbstring pdo_mysql zip \
    && pecl install imagick \
    && docker-php-ext-enable imagick \
    && a2enmod rewrite headers expires \
    && apt-get purge -y --auto-remove libmagickwand-dev libicu-dev libzip-dev libpng-dev libjpeg62-turbo-dev libfreetype6-dev \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

WORKDIR /var/www/html
COPY . /var/www/html

# The project uses index.php at the repository root rather than public/index.php.
# Apache rules below deny direct HTTP access to application source and secrets.
COPY docker/apache-primestock.conf /etc/apache2/conf-available/primestock.conf
RUN a2enconf primestock \
    && composer install --no-dev --prefer-dist --no-interaction --no-progress --optimize-autoloader \
    && mkdir -p storage/app/public storage/framework/cache/data storage/framework/sessions storage/framework/views storage/logs bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && rm -f .env \
    && ln -s storage/.env .env

COPY docker/docker-entrypoint.sh /usr/local/bin/primestock-entrypoint
RUN chmod +x /usr/local/bin/primestock-entrypoint

EXPOSE 80
ENTRYPOINT ["primestock-entrypoint"]
CMD ["apache2-foreground"]
