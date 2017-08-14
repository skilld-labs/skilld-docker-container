<?php

/**
 * @file
 * Enables modules and site configuration for a multilingual installation.
 *
 * Copied from https://www.drupal.org/project/multilingual_demo project.
 */

use Symfony\Component\Yaml\Parser;

/**
 * Implements hook_install_tasks().
 */
function sdd_install_tasks(&$install_state) {
  return [
    'sdd_install_import_language_config' => [],
  ];
}

/**
 * Implements hook_install_tasks_alter().
 */
function sdd_install_tasks_alter(&$tasks, $install_state) {
  // Moves the language config import task to the end of the install tasks so
  // that it is run after the final import of languages.
  $task = $tasks['sdd_install_import_language_config'];
  unset($tasks['sdd_install_import_language_config']);
  $tasks = array_merge($tasks, ['sdd_install_import_language_config' => $task]);
}

/**
 * Imports language configuration overrides.
 */
function sdd_install_import_language_config() {
  $language_manager = \Drupal::languageManager();
  $yaml_parser = new Parser();
  // The language code of the default locale.
  $site_default_langcode = $language_manager->getDefaultLanguage()->getId();
  // The directory where the language config files reside.
  $language_config_directory = __DIR__ . '/config/install/language';
  if (!is_dir($language_config_directory)) {
    return;
  }
  // Sub-directory names (language codes).
  // The language code of the default language is excluded. If the user
  // chooses to install in Hungarian, French, or Spanish, the language config is
  // imported by core and the user has the chance to override it during the
  // installation process.
  $langcodes = array_diff(scandir($language_config_directory), [
    '..',
    '.',
    $site_default_langcode,
  ]);

  foreach ($langcodes as $langcode) {
    // All .yml files in the language's config subdirectory.
    $config_files = glob("$language_config_directory/$langcode/*.yml");

    foreach ($config_files as $file_name) {
      // Information from the .yml file as an array.
      $yaml = $yaml_parser->parse(file_get_contents($file_name));
      // Uses the base name of the .yml file to get the config name.
      $config_name = basename($file_name, '.yml');
      // The language configuration object.
      $config = $language_manager->getLanguageConfigOverride($langcode, $config_name);

      foreach ($yaml as $config_key => $config_value) {
        // Updates the configuration object.
        $config->set($config_key, $config_value);
      }

      // Saves the configuration.
      $config->save();
    }
  }
}
