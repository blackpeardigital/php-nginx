FROM php:7.4.11-fpm AS production

# Setup FPM
RUN sed -i 's/;error_log = log\/php-fpm.log/error_log = \/dev\/stderr/' /usr/local/etc/php-fpm.conf
COPY php-fpm.d/* /usr/local/etc/php-fpm.d/



# Nginx
ARG NGINX_VERSION=1.14.2-2+deb10u4
RUN apt-get update && apt-get install -y --no-install-recommends \
        supervisor \
        nginx-full=${NGINX_VERSION}  \
    && rm -rf /var/lib/apt/lists/*
# Copy over fixed config, to prevent future updates having unexpected consequences
COPY nginx/* /etc/nginx/
COPY nginx/sites-available/* /etc/nginx/sites-available/
COPY bin/* /usr/bin/
EXPOSE 80

# Setup supervisord
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]


FROM production AS development 

RUN apt-get update && apt-get install -y --no-install-recommends \
        nano \
    && rm -rf /var/lib/apt/lists/*

# Xdebug
RUN pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && touch /var/log/xdebug.log && chmod 777 /var/log/xdebug.log \
    # TODO: permissions don't work with new volumes
    && mkdir /var/log/xdebug-profiler && chmod 777 /var/log/xdebug-profiler

# XDebug Port
EXPOSE 9000

# Setup php.ini settings
COPY dev-ini/*.ini /usr/local/etc/php/conf.d/
