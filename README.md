### PHP FPM + Caddy 2 + supervisor

## Example for symfony app

```
FROM {image}

RUN echo "opcache.preload=/usr/src/app/config/preload.php" >> $PHP_INI_DIR/conf.d/preload.ini && \
echo "opcache.preload_user=www-data" >> $PHP_INI_DIR/conf.d/preload.ini

COPY composer.json composer.lock ./

RUN composer install \
--no-dev \
--no-autoloader \
--no-scripts \
--no-plugins \
--prefer-dist \
--no-progress \
--no-interaction

COPY . .

RUN composer dump-autoload --classmap-authoritative && \
composer check-platform-reqs && \
bin/console cache:warmup && \
bin/console assets:install && \
composer dump-env prod && \
chmod -R 777 var/cache var/log
```
