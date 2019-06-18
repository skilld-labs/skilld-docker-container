<?php

use Drupal\DrupalExtension\Context\RawDrupalContext;
use Drupal\Core\Url;
use Drupal\node\Entity\Node;
use Behat\Behat\Context\SnippetAcceptingContext;
use Behat\Behat\Tester\Exception\PendingException;
use Behat\Gherkin\Node\PyStringNode;
use Behat\Gherkin\Node\TableNode;
use Behat\Mink\Driver\Selenium2Driver;


/**
 * Defines application features from the specific context.
 */
class FeatureContext extends RawDrupalContext implements SnippetAcceptingContext {

  /**
   * Initializes context.
   *
   * Every scenario gets its own context instance.
   * You can also pass arbitrary arguments to the
   * context constructor through behat.yml.
   */
  public function __construct() {
  }


  /**
   * @Then /^I want to see the URL$/
   *
   * @throws \Exception
   */
  public function iWantToSeeTheURL() {
    try {
      $url = $this->getSession()->getCurrentUrl();
      var_dump($url);
    } catch (Exception $e) {
      throw new Exception($e);
    }
  }

  /**
   * @Then /^I want to see the page content$/
   *
   * @throws \Exception
   */
  public function iWantToSeeThePageContent() {
    try {
      $html = $this->getSession()->getPage()->getHtml();
      print($html);
    } catch (Exception $e) {
      throw new Exception($e);
    }
  }

  /**
   * @Given /^I wait (\d+) seconds$/
   */
  public function iWaitSeconds($seconds) {
    sleep($seconds);
  }

  /**
   * @Then a PDF is displayed
   */
  public function assertPdfDisplay()
  {
    $headers = $this->getSession()->getResponseHeaders();

    if (!isset($headers['Content-Type'][0]) || strcmp($headers['Content-Type'][0], 'application/pdf') != 0 ) {
      throw new Exception('No PDF displayed.');
    }

    //assertArraySubset(['Content-Type' => [0 => 'application/pdf']], $headers);
  }

  /**
   * @Then I click the back button of the navigator
   */
  public function iClickTheBackButtonInNavigator() {
    $this->getSession()->getDriver()->back();
  }

  /**
   * @Given I click the :arg1 element
   */
  public function iClickTheElement($selector) {
    $page = $this->getSession()->getPage();
    $element = $page->find('css', $selector);

    if (empty($element)) {
      throw new Exception("No html element found for the selector ('$selector')");
    }

    $element->click();
  }

  /**
   * @Given I select the first element in :arg1 list
   */
  public function iSelectTheFirstElement($selector) {
    $page = $this->getSession()->getPage();

    $options = $page->findAll('css', "#$selector option");

    /** @var \Behat\Mink\Element\NodeElement $option */
    foreach ($options as $option) {
      if (strcmp($option->getValue(), "_none") != 0) {
        $page->selectFieldOption($selector, $option->getValue());
        return;
      }
    }

    throw new Exception("Unable to find a non empty value.");
  }

  /**
   * Click some text
   *
   * @When /^I click on the text "([^"]*)"$/
   */
  public function iClickOnTheText($text)
  {
    $session = $this->getSession();
    $element = $session->getPage()->find(
      'xpath',
      $session->getSelectorsHandler()->selectorToXpath('xpath', '*//*[text()="'. $text .'"]')
    );
    if (null === $element) {
      throw new \InvalidArgumentException(sprintf('Cannot find text: "%s"', $text));
    }

    $element->click();
  }


  /**
   * @Then /^the selectbox "([^"]*)" should have a list containing:$/
   */
  public function shouldHaveAListContaining($element, \Behat\Gherkin\Node\PyStringNode $list)
  {
    $page = $this->getSession()->getPage();
    $validStrings = $list->getStrings();

    $elements = $page->findAll('css', "#$element option");

    $option_none = 0;

    /** @var \Behat\Mink\Element\NodeElement $element */
    foreach ($elements as $element) {
      $value = $element->getValue();
      if (strcmp($value, '_none') == 0) {
        $option_none = 1;
        continue;
      }

      if (!in_array($element->getValue(), $validStrings)) {
        throw new Exception ("Element $value not found.");
      }
    }

    if ((sizeof($elements) - $option_none) < sizeof($validStrings)) {
      throw new Exception ("Expected options are missing in the select list.");
    }
    elseif ((sizeof($elements) - $option_none) > sizeof($validStrings)) {
      throw new Exception ("There are more options than expected in the select list.");
    }
  }


  /**
   * Wait for AJAX to finish.
   *
   * @see \Drupal\FunctionalJavascriptTests\JSWebAssert::assertWaitOnAjaxRequest()
   *
   * @Given I wait max :arg1 seconds for AJAX to finish
   */
  public function iWaitForAjaxToFinish($seconds) {
    $condition = <<<JS
    (function() {
      function isAjaxing(instance) {
        return instance && instance.ajaxing === true;
      }
      var d7_not_ajaxing = true;
      if (typeof Drupal !== 'undefined' && typeof Drupal.ajax !== 'undefined' && typeof Drupal.ajax.instances === 'undefined') {
        for(var i in Drupal.ajax) { if (isAjaxing(Drupal.ajax[i])) { d7_not_ajaxing = false; } }
      }
      var d8_not_ajaxing = (typeof Drupal === 'undefined' || typeof Drupal.ajax === 'undefined' || typeof Drupal.ajax.instances === 'undefined' || !Drupal.ajax.instances.some(isAjaxing))
      return (
        // Assert no AJAX request is running (via jQuery or Drupal) and no
        // animation is running.
        (typeof jQuery === 'undefined' || (jQuery.active === 0 && jQuery(':animated').length === 0)) &&
        d7_not_ajaxing && d8_not_ajaxing
      );
    }());
JS;
    $result = $this->getSession()->wait($seconds * 1000, $condition);
    if (!$result) {
      throw new \RuntimeException('Unable to complete AJAX request.');
    }
  }

  /**
   * Switches to specific iframe.
   *
   * @Given I switch to iframe :arg1
   */
  public function iSwitchToIframe(string $name) {
    $this->getSession()->switchToIFrame($name);
  }

  /**
   * Switches to main window.
   *
   * @Given I switch back to main window
   */
  public function iSwitchToMainWindow() {
    $this->getSession()->switchToIFrame(NULL);
  }

}
