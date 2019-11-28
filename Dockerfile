FROM php:7.4-fpm
LABEL company="Vrok"
LABEL version="1.0.0"

###########################################
# Install dependencies for extensions etc #
###########################################
# libicu-dev: for ext-intl
# libjpeg-dev: for ext-gd
# libpng-dev: for ext-gd
# libzip-dev: for ext-zip
# locales: for setting locale to de_DE.UTF8
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      libicu-dev \
      libjpeg-dev \
      libpng-dev \
      libzip-dev \
      locales \
    && rm -rf /var/lib/apt/lists*

################################
# Install extensions from PECL #
################################
# further possible extensions:
## apcu: 5.1.17
## gnupg: [requires gnupg libgpgme-dev]

# redis: session storage & cache
RUN pecl install redis && \
    pecl clear-cache && \
    docker-php-ext-enable redis

###################################################
# Some extensions must need special configuration #
###################################################
RUN docker-php-ext-configure gd --with-jpeg-dir=/usr

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
# opcache: local opcode cache, replaces APC
# pdo_mysql: MySQL/MariaDB driver for PDO - PDO is already in the default image
# zip: (de)compression
RUN docker-php-ext-install gd intl opcache pdo_mysql zip

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
