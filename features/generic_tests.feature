@api

Feature: Generic tests


  Scenario: Homepage is accessible
    Given I am an anonymous user
    When I am on the homepage
    # Then I should see the text "No front page content has been created yet."
    Then I should get a "200" HTTP response


  Scenario: User login page is accessible
    Given I am an anonymous user
    When I visit "/user"
    Then I should get a "200" HTTP response


  Scenario: Submit valid credentials as admin user login
    Given I am an anonymous user
    When I visit "/user"
    And I fill in "edit-name" with "admin"
    And I fill in "edit-pass" with "admin"
    And I press the "edit-submit" button
    Then I am on "/admin/people"
    And the response status code should be 200


  Scenario: Submit invalid credentials as admin user login
    Given I am an anonymous user
    When I visit "/user"
    And I fill in "edit-name" with "XXXXX"
    And I fill in "edit-pass" with "YYYYY"
    And I press the "edit-submit" button
    Then I am on "/admin/people"
    And the response status code should be 403


  Scenario: Run cron
    Given I am logged in as a user with the "administrator" role
    When I run cron
    And am on "admin/reports/dblog"
    Then I should see the link "Cron run completed"


  Scenario: Create users
    Given users:
    | name     | mail            | status |
    | John Doe | johndoe@example.com | 1 |
    And I am logged in as a user with the "administrator" role
    When I visit "admin/people"
    Then I should see the link "John Doe"

