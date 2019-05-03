Feature: User login

  Can user login successfuly ?

  Scenario: Submit login form as an admin
    Given I am an anonymous user
    When I visit "/user"
    And I fill in "edit-name" with "admin"
    And I fill in "edit-pass" with "admin"
    And I press the "Log in" button
    Then I am on "/admin/people"
    And the response status code should be 200

  Scenario: Submit invalid credentials as an admin
    Given I am an anonymous user
    When I visit "/user"
    And I fill in "edit-name" with "XXXXX"
    And I fill in "edit-pass" with "YYYYY"
    And I press the "Log in" button
    Then I am on "/admin/people"
    And the response status code should be 403
