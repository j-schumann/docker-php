# Dockerfile for image vrokdd/php
FROM php:8.5-fpm
LABEL company="Vrok"
LABEL version="1.3.0"

###########################################
# Install dependencies for extensions etc #
###########################################
# libfreetype6-dev: for ext-gd
# libicu-dev: for ext-intl
# libjpeg-dev: for ext-gd
# libpng-dev: for ext-gd
# libzip-dev: for ext-zip
# locales: for setting locale to de_DE.UTF8
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      libfreetype6-dev \
      libicu-dev \
      libjpeg-dev \
      libpng-dev \
      libzip-dev \
      locales \
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
# PIE selects the newest release compatible with the PHP version #
# and enables the extension. It needs ext-zip, installed above.  #
##################################################################
# further possible extensions:
## apcu/apcu
## gnupg: [requires gnupg libgpgme-dev]
COPY --from=ghcr.io/php/pie:1.5.5-bin /pie /usr/bin/pie

# PIE downloads the sources via the GitHub API. Without a token the runner's
# shared IP quickly hits the rate limit, so CI passes its GITHUB_TOKEN as a
# build secret (it is not stored in the image). Local builds work without it.
# redis: session storage & cache
RUN --mount=type=secret,id=github_token,env=GITHUB_TOKEN \
    { [ -z "$GITHUB_TOKEN" ] || export COMPOSER_AUTH="{\"github-oauth\":{\"github.com\":\"$GITHUB_TOKEN\"}}"; } \
    && pie install phpredis/phpredis

##################################################################################
# Localize by generating locales for PHP to translate / number-format for German #
# and setting the timezone                                                       #
##################################################################################
ENV TZ=Europe/Berlin
RUN echo "de_DE.UTF8 UTF-8" > /etc/locale.gen && locale-gen && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN mkdir /var/www/log && chown www-data:www-data /var/www/log

###########################
# Customize configuration #
###########################
COPY ./php.ini /usr/local/etc/php/conf.d/php.ini
COPY ./php-fpm.conf /usr/local/etc/php-fpm.conf
