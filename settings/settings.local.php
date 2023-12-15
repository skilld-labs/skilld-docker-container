<?php

/**
 * @file
 * Local development override configuration feature.
 */

//// Drupal Application overrides ////

// Global
$settings['file_private_path'] = '../private-files';

// Sendmail command for symfony_mailer.
$settings['mailer_sendmail_commands'][] = ini_get('sendmail_path');
$config['symfony_mailer.mailer_transport.sendmail']['configuration']['query']['command'] = ini_get('sendmail_path') ;
