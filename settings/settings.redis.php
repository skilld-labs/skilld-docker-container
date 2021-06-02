
/**
 * Settings for Redis.
 * @todo Use `global $install_state` to test install time.
 */
if (!defined('MAINTENANCE_MODE') || MAINTENANCE_MODE !== 'install') {
  $settings['redis.connection']['host'] = getenv('REDIS_HOST');
  $settings['redis.connection']['port'] = getenv('REDIS_PORT');
  $settings['redis.connection']['password'] = getenv('REDIS_PASSWD');
  $settings['redis.connection']['base'] = 0;
  $settings['redis.connection']['interface'] = 'PhpRedis';
  $settings['cache']['default'] = 'cache.backend.redis';
  $settings['cache']['bins']['bootstrap'] = 'cache.backend.chainedfast';
  $settings['cache']['bins']['discovery'] = 'cache.backend.chainedfast';
  $settings['cache']['bins']['config'] = 'cache.backend.chainedfast';
  // @todo Refactor after https://www.drupal.org/node/1530756 solved.
  $settings['container_yamls'][] = $app_root . '/modules/contrib/redis/example.services.yml';
}

