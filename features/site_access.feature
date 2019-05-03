Feature: Homepage access

  Is website accessible and navigable ?

  Scenario: Homepage is accessible
    Given I am an anonymous user
    When I am on the homepage
    # Then I should see the text "No front page content has been created yet."
    Then I should get a "200" HTTP response

  Scenario: User login page is accessible
    Given I am an anonymous user
    When I visit "/user"
    Then I should get a "200" HTTP response
