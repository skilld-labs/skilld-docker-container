<?php

use Drupal\DrupalExtension\Context\RawDrupalContext;

/**
 * Defines application features from the specific context.
 */
class FeatureContext extends RawDrupalContext {

  /**
   * Params for testing.
   *
   * @var array
   */
  protected $params;

  /**
   * Initializes context.
   *
   * Every scenario gets its own context instance.
   * You can also pass arbitrary arguments to the
   * context constructor through behat.yml.
   *
   * @param $params
   *   Params for testing.
   */
  public function __construct($params) {
    $this->params = $params;
  }

  /**
   * Run before every scenario.
   *
   * @BeforeScenario
   */
  public function beforeScenario() {
    if ($basic_auth = $this->params['basic_auth']) {
      // Assign basic auth credentials.
      $this->getSession()
        ->setBasicAuth($basic_auth['user'], $basic_auth['pass']);
    }
  }

}
