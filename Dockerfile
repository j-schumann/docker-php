FROM php:7.4-fpm
LABEL company="Vrok"
LABEL version="1.0.1"

###########################################
# Install dependencies for extensions etc #
###########################################
# cron: application specific tasks
# gnupg: for nodejs install
# libfreetype6-dev: for ext-gd
# libicu-dev: for ext-intl
# libjpeg-dev: for ext-gd
# libpng-dev: for ext-gd
# libssl-dev: for ext-mongodb auth support
# libzip-dev: for ext-zip
# locales: for setting locale to de_DE.UTF8
# lsb-release: for nodejs install
# python-pip: for supervisor
# pip & setuptools: for supervisor-stdout
# supervisor: entrypoint, keeps FPM + Cron running
# supervisor-stdout: to show process output in container logs
# wget: for composer install script
RUN apt-get update && \
    apt-get install -yq --no-install-recommends \
      cron \
      gnupg \
      libfreetype6-dev \
      libicu-dev \
      libjpeg-dev \
      libpng-dev \
      libssl-dev \
      libzip-dev \
      locales \
      lsb-release \
      python3 \
      supervisor \
      wget \
    && rm -rf /var/lib/apt/lists* \
    && curl --silent --show-error --retry 3 https://bootstrap.pypa.io/get-pip.py | python \
    && pip install setuptools \
    && pip install supervisor-stdout

################################
# Install extensions from PECL #
################################
# further possible extensions:
## gnupg: [requires gnupg libgpgme-dev]

# apcu: very fast user cache, e.g. for api platform
# redis: session storage & cache
RUN pecl install apcu mongodb redis && \
    pecl clear-cache && \
    docker-php-ext-enable apcu mongodb redis

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
# opcache: local opcode cache, replaces APC
# pdo_mysql: MySQL/MariaDB driver for PDO - PDO is already in the default image
# zip: (de)compression
RUN docker-php-ext-install gd intl opcache pdo_mysql zip

#############################
# Install Node + NPM + Yarn #
#############################
RUN curl -sL https://deb.nodesource.com/setup_13.x | bash && \
    apt-get install -yq --no-install-recommends \
      nodejs \
    && npm install -g npm \
    && npm install -g yarn

##################################################################################
# Localize by generating locales for PHP to translate / number-format for German #
# and setting the timezone                                                       #
##################################################################################
ENV TZ=Europe/Berlin
RUN echo "de_DE.UTF8 UTF-8" > /etc/locale.gen && locale-gen && \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

##############################
# Create folders for logging #
# for FPM & Supervisor       #
##############################
RUN mkdir -p /var/www/log/supervisor && chown -R www-data:www-data /var/www/log 

###########################
# Customize configuration #
###########################
COPY ./php.ini /usr/local/etc/php/conf.d/php.ini
COPY ./php-fpm.conf /usr/local/etc/php-fpm.conf
COPY ./supervisord.conf /etc/supervisor/supervisord.conf

####################
# Install Composer #
####################
COPY ./install-composer.sh /tmp/
RUN /tmp/install-composer.sh

####################################################################
# Supervisor runs php-fpm & cron & the symfony messagebus consumer #
####################################################################
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
