# Dockerfile for image vrokdd/php:api-8

# The PIE image only exists for amd64 and arm64, but /pie is a platform
# independent PHAR, so take it from the image of the build platform
FROM --platform=$BUILDPLATFORM ghcr.io/php/pie:1.5.5-bin AS pie

FROM php:8.5-fpm-alpine

# persistent / runtime deps
RUN apk add --no-cache \
    acl \
    file \
    gettext \
    git \
    icu-data-full \
    supervisor \
    zip \
    ;

# PIE (https://github.com/php/pie) installs extensions from Packagist, it
# selects the newest release compatible with the PHP version and enables it
COPY --from=pie /pie /usr/bin/pie

RUN set -eux; \
    apk add --no-cache --virtual .build-deps \
    $PHPIZE_DEPS \
    icu-dev \
    freetype-dev \
    gmp-dev \
    jpeg-dev \
    libpng-dev \
    openssl-dev \
    postgresql-dev \
    libzip-dev \
    zlib-dev \
    ; \
    docker-php-ext-configure gd --with-jpeg --with-freetype; \
    docker-php-ext-install -j$(nproc) \
    gd \
    gmp \
    intl \
    pdo_mysql \
    pdo_pgsql \
    zip \
    ; \
    pie install apcu/apcu; \
    pie install mongodb/mongodb-extension; \
    pie install phpredis/phpredis; \
    # apfd has no stable release on Packagist yet
    pecl install apfd; \
    pecl clear-cache; \
    docker-php-ext-enable apfd; \
    runDeps="$( \
      scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
       | tr ',' '\n' \
       | sort -u \
       | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )"; \
    apk add --no-cache --virtual .api-phpexts-rundeps $runDeps; \
    \
    apk del .build-deps

# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# install Symfony Flex globally to speed up download of Composer packages (parallelized prefetching)
RUN set -eux; \
    composer config --global --no-plugins allow-plugins.symfony/flex true; \
    composer global require "symfony/flex" --no-progress --classmap-authoritative; \
    composer clear-cache
ENV PATH="${PATH}:/root/.composer/vendor/bin"

WORKDIR /srv/api

RUN mkdir -p var/cache var/log /var/uploads templates_custom translations_custom; \
    mkdir -p /log/supervisor; chown -R www-data:www-data /log
