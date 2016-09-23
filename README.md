# skilld-docker-container

## Overview

The Drupal bundle consist of the following containers:

| Container | Service name | Image | Public Port | Enabled by default |
| --------- | ------------ | ----- | ----------- | ------------------ |
| [Nginx](#nginx) | nginx | <a href="https://hub.docker.com/r/wodby/drupal-nginx/" target="_blank">wodby/drupal-nginx</a> | 8000 | ✓ |
| [PHP 7 / 5.6](#php) | php | <a href="https://hub.docker.com/r/wodby/drupal-php/" target="_blank">wodby/drupal-php</a> |  | ✓ |
| [MariaDB](#mariadb) | mariadb | <a href="https://hub.docker.com/r/wodby/drupal-mariadb/" target="_blank">wodby/drupal-mariadb</a> | | ✓ |
| [phpMyAdmin](#phpmyadmin) | pma | <a href="https://hub.docker.com/r/phpmyadmin/phpmyadmin" target="_blank">phpmyadmin/phpmyadmin</a> | 8001 | ✓ |
| [Mailhog](#mailhog) | mailhog | <a href="https://hub.docker.com/r/mailhog/mailhog" target="_blank">mailhog/mailhog</a> | 8002 | ✓ |
| [Redis](#redis) | redis | <a href="https://hub.docker.com/_/redis/" target="_blank">redis/redis</a> |||
| [Memcached](#memcached) | memcached | <a href="https://hub.docker.com/_/memcached/" target="_blank">_/memcached</a> |||
| [Solr](#solr) | solr | <a href="https://hub.docker.com/_/solr" target="_blank">_/solr</a> | 8003 ||
| [Varnish](#varnish) | varnish | <a href="https://hub.docker.com/r/wodby/drupal-varnish" target="_blank">wodby/drupal-varnish</a> | 8004 ||