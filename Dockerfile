###############################################################################
#                            Builder / Base Stage                             #
#  - Central ARG for PHP version bump                                         #
###############################################################################
# syntax=docker/dockerfile:1
ARG PHP_VERSION=8.3-fpm

FROM php:${PHP_VERSION} AS base

# -----------------------------------------------------------------------------
# 1. Install system deps and rebuild core PHP extensions for 8.3
# -----------------------------------------------------------------------------
RUN set -eux; \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        libzip-dev \
        libonig-dev \
        libpng-dev \
        libjpeg-dev \
        libfreetype6-dev \
        zip \
        unzip \
    && docker-php-ext-configure zip \
    && docker-php-ext-install \
        pdo_mysql \
        zip \
        mbstring \
        exif \
        pcntl \
        bcmath \
        opcache \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# 2. Configure PHP-FPM to log errors to STDERR
# -----------------------------------------------------------------------------
RUN sed -i \
        's@;error_log = log/php-fpm.log@error_log = /dev/stderr@' \
        /usr/local/etc/php-fpm.conf
COPY php-fpm.d/*.conf /usr/local/etc/php-fpm.d/

###############################################################################
#                             Production Stage                                #
###############################################################################
FROM base AS production

# -----------------------------------------------------------------------------
# 3. Install nginx mainline (Debian 12 “bookworm”)
# -----------------------------------------------------------------------------
ARG NGINX_VERSION=1.29.0-1~bookworm
RUN set -eux; \
    # pull in tools to fetch & verify the key
    apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        gnupg \
        curl \
    && mkdir -p /etc/apt/keyrings \
    # fetch and dearmor nginx.org signing key
    && curl -fsSL https://nginx.org/keys/nginx_signing.key \
       | gpg --dearmor -o /etc/apt/keyrings/nginx.gpg \
    # add signed mainline repo for bookworm
    && echo "deb [signed-by=/etc/apt/keyrings/nginx.gpg] https://nginx.org/packages/mainline/debian/ bookworm nginx" \
       > /etc/apt/sources.list.d/nginx.list \
    && echo "deb-src [signed-by=/etc/apt/keyrings/nginx.gpg] https://nginx.org/packages/mainline/debian/ bookworm nginx" \
       >> /etc/apt/sources.list.d/nginx.list \
    # install the exact pinned package
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        nginx=${NGINX_VERSION} \
    && rm -rf /var/lib/apt/lists/*

# Copy over fixed config, to prevent future updates having unexpected consequences
COPY nginx/* /etc/nginx/
COPY nginx/conf.d/* /etc/nginx/conf.d/
COPY nginx/snippets /etc/nginx/snippets/
COPY bin/* /usr/bin/
EXPOSE 80

RUN nginx -t

# -----------------------------------------------------------------------------
# 4. Supervisor to orchestrate php-fpm + nginx
# -----------------------------------------------------------------------------
RUN set -eux; \
    apt-get update \
    && apt-get install -y --no-install-recommends supervisor \
    && rm -rf /var/lib/apt/lists/*
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

###############################################################################
#                             Development Stage                               #
###############################################################################
FROM production AS development

# -----------------------------------------------------------------------------
# 5. Dev tools: nano + Xdebug
# -----------------------------------------------------------------------------
RUN set -eux; \
    apt-get update \
    && apt-get install -y --no-install-recommends nano \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && rm -rf /var/lib/apt/lists/*

# prepare Xdebug log & profiler dirs
RUN touch /var/log/xdebug.log \
    && chmod 666 /var/log/xdebug.log \
    && mkdir -p /var/log/xdebug-profiler \
    && chmod 777 /var/log/xdebug-profiler

# XDebug Port
EXPOSE 9000

# load any PHP INI overrides for development
COPY dev-ini/*.ini /usr/local/etc/php/conf.d/
