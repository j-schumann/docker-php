# Dockerfile for image vrokdd/php:symfony-8
FROM php:8.6-fpm
LABEL company="Vrok"
LABEL version="1.3.0"

ENV START_FPM=true
ENV START_CRON=true
ENV START_MESSENGER=true

###########################################
# Install dependencies for extensions etc #
###########################################
# cron: application specific tasks
# gnupg: for nodejs install
# libfreetype6-dev: for ext-gd
# libicu-dev: for ext-intl
# libjpeg-dev: for ext-gd
# libpng-dev: for ext-gd
# librabbitmq-dev: for ext-amqp / rabbitmq access
# libssl-dev: for ext-mongodb auth support
# libzip-dev: for ext-zip
# locales: for setting locale to de_DE.UTF8
# lsb-release: for nodejs install
# supervisor: entrypoint, keeps FPM + Cron running
RUN apt-get update && \
    apt-get install -yq --no-install-recommends \
      cron \
      git \
      gnupg \
      libfreetype6-dev \
      libicu-dev \
      libjpeg-dev \
      libpng-dev \
      libssl-dev \
      libzip-dev \
      locales \
      lsb-release \
      supervisor \
      zip \
    && rm -rf /var/lib/apt/lists*

###################################################
# Some extensions must need special configuration #
###################################################
RUN docker-php-ext-configure gd --with-jpeg --with-freetype

#####################################
# Install additional PHP extensions #
#####################################
# further possible extensions:
## bcmath:
## bz2: [requires libbz2-dev]
## gettext:
## gmp: [requires libgmp-dev]
## mbstring: multibyte character handling - already in default image
## mysqli: basic db access to MySQL/MariaDB

# gd: image handling, e.g. for NextGen
# intl: translation, number formatting
# pdo_mysql: MySQL/MariaDB driver for PDO - PDO is already in the default image
# zip: (de)compression
RUN docker-php-ext-install gd intl pdo_mysql zip

##################################################################
# Install extensions with PIE (https://github.com/php/pie)       #
# Versions are pinned, Renovate proposes updates (tested by CI). #
# PIE enables the extension. It needs ext-zip, installed above.  #
##################################################################
# further possible extensions:
## gnupg: [requires gnupg libgpgme-dev]
COPY --from=ghcr.io/php/pie:1.5.5-bin /pie /usr/bin/pie

# apcu: very fast user cache, e.g. for api platform
# mongodb: MongoDB driver
# PIE downloads the sources via the GitHub API. Without a token the runner's
# shared IP quickly hits the rate limit, so CI passes its GITHUB_TOKEN as a
# build secret (it is not stored in the image). Local builds work without it.
# redis: session storage & cache
RUN --mount=type=secret,id=github_token,env=GITHUB_TOKEN \
    { [ -z "$GITHUB_TOKEN" ] || export COMPOSER_AUTH="{\"github-oauth\":{\"github.com\":\"$GITHUB_TOKEN\"}}"; } \
    && pie install apcu/apcu:v5.1.28 \
    && pie install mongodb/mongodb-extension:2.5.8 \
    && pie install phpredis/phpredis:6.3.0

RUN --mount=type=secret,id=github_token,env=GITHUB_TOKEN \
    { [ -z "$GITHUB_TOKEN" ] || export COMPOSER_AUTH="{\"github-oauth\":{\"github.com\":\"$GITHUB_TOKEN\"}}"; } \
    && apt-get install -yq --no-install-recommends $PHPIZE_DEPS \
    && pie install xdebug/xdebug:3.5.3

#############################
# Install Node + NPM + Yarn #
#############################
RUN curl -sL https://deb.nodesource.com/setup_26.x | bash \
    && apt-get install -yq --no-install-recommends nodejs \
    && npm install -g npm yarn

##################################################################################
# Localize by generating locales for PHP to translate / number-format for German #
# and setting the timezone                                                       #
##################################################################################
ENV TZ=Europe/Berlin
RUN echo "de_DE.UTF8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone

#############################
# Create folder for logging #
#############################
RUN mkdir -p /var/www/log && chown -R www-data:www-data /var/www/log

###########################
# Customize configuration #
###########################
COPY ./php.ini /usr/local/etc/php/conf.d/php.ini
COPY ./php-fpm.conf /usr/local/etc/php-fpm.conf
COPY ./supervisord.conf /etc/supervisor/supervisord.conf

####################
# Install Composer #
####################
# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
ENV COMPOSER_ALLOW_SUPERUSER=1
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

####################################################################
# Supervisor runs php-fpm & cron & the symfony messagebus consumer #
####################################################################
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
