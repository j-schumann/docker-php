FROM php:7.4-fpm-alpine

# persistent / runtime deps
RUN apk add --no-cache \
	acl \
	file \
	gettext \
	git \
	supervisor \
        zip \
    ;

RUN set -eux; \
    apk add --no-cache --virtual .build-deps \
	$PHPIZE_DEPS \
	icu-dev \
	freetype-dev \
        jpeg-dev \
        libpng-dev \
        rabbitmq-c-dev \
        openssl-dev \
	libzip-dev \
	zlib-dev \
    ; \
    docker-php-ext-configure gd --with-jpeg --with-freetype; \
    docker-php-ext-install -j$(nproc) \
        gd \
	intl \
	pdo_mysql \
	zip \
    ; \
    pecl install \
        amqp \
	apcu \
        mongodb \
    ; \
    pecl clear-cache; \
    docker-php-ext-enable \
        amqp \
	apcu \
	mongodb \
	opcache \
    ; \
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
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# install Symfony Flex globally to speed up download of Composer packages (parallelized prefetching)
RUN set -eux; \
	composer global require "symfony/flex" --prefer-dist --no-progress --no-suggest --classmap-authoritative; \
	composer clear-cache
ENV PATH="${PATH}:/root/.composer/vendor/bin"

WORKDIR /srv/api

RUN mkdir -p var/cache var/log /var/uploads templates_custom translations_custom; \
    mkdir -p /log/supervisor; chown -R www-data:www-data /log
