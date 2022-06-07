FROM php:7.4.11-fpm AS production

# Setup FPM
RUN sed -i 's/;error_log = log\/php-fpm.log/error_log = \/dev\/stderr/' /usr/local/etc/php-fpm.conf
COPY php-fpm.d/* /usr/local/etc/php-fpm.d/



# Nginx
ARG NGINX_VERSION=1.21.6-1~buster
RUN CODENAME=$(cat /etc/*-release|grep -oP  'CODENAME=\K\w+$'|head -1) ; \
    apt-get update \
    && apt-get install -y --no-install-recommends \
        wget apt-utils gnupg2 \
    && wget https://nginx.org/keys/nginx_signing.key \
    && apt-key add nginx_signing.key \
    && rm -r nginx_signing.key \
    && echo "deb https://nginx.org/packages/mainline/debian/ ${CODENAME} nginx \n\
deb-src https://nginx.org/packages/mainline/debian/ ${CODENAME} nginx" >> /etc/apt/sources.list \
    && cat /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends nginx=${NGINX_VERSION} \
    && rm -rf /var/lib/apt/lists/*

# Copy over fixed config, to prevent future updates having unexpected consequences
COPY nginx/* /etc/nginx/
COPY nginx/conf.d/* /etc/nginx/conf.d/
COPY nginx/snippets /etc/nginx/snippets/
COPY bin/* /usr/bin/
EXPOSE 80

RUN nginx -t

# Setup supervisord
RUN apt-get update && apt-get install -y --no-install-recommends \
        supervisor \
    && rm -rf /var/lib/apt/lists/*
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
