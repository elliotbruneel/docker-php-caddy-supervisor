FROM caddy:2.6-builder AS builder

RUN xcaddy build \
    --with github.com/baldinof/caddy-supervisor

FROM php:8.2-fpm-alpine

COPY --from=composer /usr/bin/composer /usr/bin/composer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

ENV APP_ENV=prod
ENV PORT=80

ENV FPM_MAX_CHILDREN=5
ENV FPM_START_SERVERS=2
ENV FPM_MIN_SPARE_SERVERS=1
ENV FPM_MAX_SPARE_SERVERS=3

RUN echo "## Installing dependencies" \
    apk add --no-cache tini openssl-dev pcre-dev icu-dev git

RUN echo '## Installing PHP extensions' && \
    install-php-extensions bcmath \
        intl \
        opcache \
        calendar \
        zip \
        sockets \
        apcu \
        pcntl \
        gd && \
    mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

RUN echo "## Checking iconv & symfony requirements" && \
    php -d zend.assertions=1 -r "assert(iconv('utf-8', 'us-ascii//TRANSLIT//IGNORE', 'éøà') !== false);" && \
    mkdir /tmp/requirements-check && cd /tmp/requirements-check && \
    composer req symfony/requirements-checker && \
    vendor/bin/requirements-checker  -v

COPY docker/symfony-presets.ini $PHP_INI_DIR/conf.d/symfony-presets.ini
COPY docker/php-fpm.conf /usr/local/etc/php-fpm.d/zz-docker.conf
COPY docker/Caddyfile /usr/local/etc/caddy/Caddyfile

RUN echo "## Validating Caddy & PHP FPM config" && \
    caddy adapt --validate --config=/usr/local/etc/caddy/Caddyfile && \
    php-fpm --test && \
    echo "PHP Version: " && php --version && \
    echo "PHP Modules: " && php -m && \
    echo "## Clean up build files" && \
    rm -rf /tmp/* /root/.composer

WORKDIR /usr/src/app

ONBUILD ARG PROJECT_NAME=unknown
ONBUILD ENV PROJECT_NAME=$PROJECT_NAME

RUN echo "opcache.preload=/usr/src/app/config/preload.php" >> $PHP_INI_DIR/conf.d/preload.ini && \
    echo "opcache.preload_user=www-data" >> $PHP_INI_DIR/conf.d/preload.ini

COPY composer.json composer.lock ./

ENV COMPOSER_ALLOW_SUPERUSER=1

RUN composer install \
    --no-dev \
    --no-autoloader \
    --no-scripts \
    --no-plugins \
    --prefer-dist \
    --no-progress \
    --no-interaction

COPY . .

ENV PORT=80

EXPOSE 80

RUN composer dump-autoload --classmap-authoritative && \
    composer check-platform-reqs && \
    bin/console cache:warmup && \
    bin/console assets:install && \
    composer dump-env prod && \
    chmod -R 777 var/cache var/log


CMD ["caddy", "run", "--config", "/usr/local/etc/caddy/Caddyfile"]
