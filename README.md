# PHP-FPM + Nginx (using Supervisord) Docker Image

The superfast nginx web server with PHP-FPM in a single image.
Uses supervisord to the two processes, nginx and php-fpm, in the same container.

```bash
docker run -it -p 80:80 -v $(pwd):/var/www/html:ro blackpeardigital/php-nginx
```

Also comes with a "development" variation of the image for debuggin - which basically adds xdebug:

```bash
docker run -it -p 80:80 -v $(pwd):/var/www/html:ro blackpeardigital/php-nginx-dev
```