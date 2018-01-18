FROM merorafael/php-fpm:7.1

RUN apt-get update && apt-get install --no-install-recommends -y \
    mariadb-client \
    ssmtp

RUN php -r "copy('http://files.drush.org/drush.phar', '/usr/bin/drush');" \
    && chmod +x /usr/bin/drush

#RUN pecl install xdebug

COPY php.ini /usr/local/etc/php/conf.d/xx-drupal.ini
COPY drushrc.php /var/www/.drush/drushrc.php
