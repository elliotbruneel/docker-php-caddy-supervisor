FROM caddy:2.6-builder AS builder

RUN xcaddy build \
    --with github.com/baldinof/caddy-supervisor

FROM php:8.1-fpm-alpine

WORKDIR /usr/src/app

ENV COMPOSER_ALLOW_SUPERUSER=1
COPY --from=composer/composer:2-bin --link /composer /usr/bin/composer
COPY --from=mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin
COPY --from=builder /usr/bin/caddy /usr/bin/caddy

ENV APP_ENV=prod
ENV PORT=80

ENV FPM_MAX_CHILDREN=5
ENV FPM_START_SERVERS=2
ENV FPM_MIN_SPARE_SERVERS=1
ENV FPM_MAX_SPARE_SERVERS=3

COPY config/symfony-presets.ini $PHP_INI_DIR/conf.d/symfony-presets.ini
COPY config/php-fpm.conf /usr/local/etc/php-fpm.d/zz-docker.conf
COPY config/Caddyfile /usr/local/etc/caddy/Caddyfile

RUN echo "## Installing dependencies" \
    apk add --no-cache tini openssl-dev pcre-dev icu-dev git

RUN echo '## Installing PHP extensions' && \
    install-php-extensions bcmath \
        intl \
        opcache \
        zip \
        sockets \
        apcu && \
    mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

RUN echo "## Validating Caddy & PHP FPM config" && \
    caddy adapt --validate --config=/usr/local/etc/caddy/Caddyfile && \
    php-fpm --test && \
    echo "PHP Version: " && php --version && \
    echo "PHP Modules: " && php -m && \
    echo "## Clean up build files" && \
    rm -rf /tmp/* /root/.composer

EXPOSE 80

CMD ["caddy", "run", "--config", "/usr/local/etc/caddy/Caddyfile"]
