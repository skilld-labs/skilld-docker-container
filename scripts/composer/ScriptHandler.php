<?php

/**
 * @file
 * Contains \SkilldDrupal\composer\ScriptHandler.
 */

namespace SkilldDrupal\composer;

use Composer\Script\Event;
use Composer\Semver\Comparator;
use Drupal\Core\Site\Settings;
use Drupal\Core\Site\SettingsEditor;
use DrupalFinder\DrupalFinder;
use Symfony\Component\Filesystem\Filesystem;
use Symfony\Component\Filesystem\Path;

/**
 * Class ScriptHandler
 *
 * @package SkilldDrupal\composer
 */
class ScriptHandler {

  /**
   * @param \Composer\Script\Event $event
   */
  public static function listScaffoldFiles(Event $event) {
    $files = [
      '.csslintrc',
      '.editorconfig',
      '.eslintignore',
      '.eslintrc.json',
      '.gitattributes',
      '.ht.router.php',
      '.htaccess',
      'index.php',
      'robots.txt',
      'sites/default/default.settings.php',
      'sites/default/default.services.yml',
      'sites/development.services.yml',
      'sites/example.settings.local.php',
      'sites/example.sites.php',
      'update.php',
      'web.config',
    ];
    $event->getIO()->write("\r\n".implode(' ',$files));
  }


  /**
   * @param \Composer\Script\Event $event
   *
   * @throws \Exception
   */
  public static function createRequiredFiles(Event $event) {
    $fs = new Filesystem();
    $drupalFinder = new DrupalFinder();
    $drupalFinder->locateRoot(getcwd());
    $drupalRoot = $drupalFinder->getDrupalRoot();

    $dirs = [
      'modules',
      'profiles',
      'themes',
    ];

    // Required for unit testing
    foreach ($dirs as $dir) {
      if (!$fs->exists($drupalRoot . '/' . $dir)) {
        $fs->mkdir($drupalRoot . '/' . $dir);
        $fs->touch($drupalRoot . '/' . $dir . '/.gitkeep');
      }
    }

    // Prepare the settings file for installation
    if (!$fs->exists($drupalRoot . '/sites/default/settings.php') and $fs->exists($drupalRoot . '/sites/default/default.settings.php')) {
      $fs->copy($drupalRoot . '/sites/default/default.settings.php', $drupalRoot . '/sites/default/settings.php');
      require_once $drupalRoot . '/core/includes/bootstrap.inc';
      require_once $drupalRoot . '/core/includes/install.inc';
      $settings['settings']['config_sync_directory'] = (object) [
        'value' => Path::makeRelative($drupalFinder->getComposerRoot() . '/config/sync', $drupalRoot),
        'required' => TRUE,
      ];
      new Settings([]);
      if (version_compare(\Drupal::VERSION, '10.1', '>=')) {
        SettingsEditor::rewrite($drupalRoot . '/sites/default/settings.php', $settings);
      }
      else {
        drupal_rewrite_settings($settings, $drupalRoot . '/sites/default/settings.php');
      }
      $fs->chmod($drupalRoot . '/sites/default/settings.php', 0666);
      $event->getIO()
        ->write("Create a sites/default/settings.php file with chmod 0666");
    }

    // Create the files directory with chmod 0777
    if (!$fs->exists($drupalRoot . '/sites/default/files')) {
      $oldmask = umask(0);
      $fs->mkdir($drupalRoot . '/sites/default/files', 0775);
      umask($oldmask);
      $event->getIO()
        ->write("Create a sites/default/files directory with chmod 0775");
    }
    else {
      $fs->chmod($drupalRoot . '/sites/default/files', 0775);
    }
  }

  /**
   * Checks if the installed version of Composer is compatible.
   *
   * Composer 1.0.0 and higher consider a `composer install` without having a
   * lock file present as equal to `composer update`. We do not ship with a lock
   * file to avoid merge conflicts downstream, meaning that if a project is
   * installed with an older version of Composer the scaffolding of Drupal will
   * not be triggered. We check this here instead of in drupal-scaffold to be
   * able to give immediate feedback to the end user, rather than failing the
   * installation after going through the lengthy process of compiling and
   * downloading the Composer dependencies.
   *
   * @see https://github.com/composer/composer/pull/5035
   */
  public static function checkComposerVersion(Event $event) {
    $composer = $event->getComposer();
    $io = $event->getIO();

    $version = $composer::VERSION;

    // The dev-channel of composer uses the git revision as version number,
    // try to the branch alias instead.
    if (preg_match('/^[0-9a-f]{40}$/i', $version)) {
      $version = $composer::BRANCH_ALIAS_VERSION;
    }

    // If Composer is installed through git we have no easy way to determine if
    // it is new enough, just display a warning.
    if ($version === '@package_version@' || $version === '@package_branch_alias_version@') {
      $io->writeError('<warning>You are running a development version of Composer. If you experience problems, please update Composer to the latest stable version.</warning>');
    }
    elseif (Comparator::lessThan($version, '1.0.0')) {
      $io->writeError('<error>Drupal-project requires Composer version 1.0.0 or higher. Please update your Composer before continuing</error>.');
      exit(1);
    }
  }

}
