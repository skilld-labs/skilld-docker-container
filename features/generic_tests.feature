@api

Feature: Generic tests

# Availability tests

    Scenario: Homepage is accessible
        Given I am an anonymous user
        When I am on the homepage
        And I take a screenshot
        Then I should get a "200" HTTP response

    Scenario: User login page is accessible
        Given I am an anonymous user
        When I visit "/user"
        And I take a screenshot
        Then I should get a "200" HTTP response

    Scenario: Run cron
        Given I am logged in as a user with the "sysadmin" role
        When I run cron
        And am on "admin/reports/dblog"
        When wait for the page to be loaded
        And I take a screenshot
        Then I should see the link "Cron run completed"

    Scenario: Clear cache
        Given the cache has been cleared
        When I am on the homepage
        When wait for the page to be loaded
        And I take a screenshot
        Then I should get a "200" HTTP response

# Security tests

    Scenario: Submit invalid login credentials
        Given I am an anonymous user
        When I visit "/user"
        And I fill in "edit-name" with "XXXXX"
        And I fill in "edit-pass" with "YYYYY"
        And I press the "edit-submit" button
        Then I am on "/admin/people"
        And I take a screenshot
        And the response status code should be 403 
        # See https://www.drupal.org/project/username_enumeration_prevention

# Global behavior tests

    Scenario: Create users programatically
        Given users:
        | name     | mail            | status |
        | John Doe | johndoe@example.com | 1 |
        And I am logged in as a user with the "contributor" role
        When I visit "/admin/people"
        When wait for the page to be loaded
        Then I should see the link "John Doe"

    Scenario: Create nodes programatically
        Given "basic_page" content:
        | title    |
        | Page one |
        | Page two |
        And I am logged in as a user with the "contributor" role
        When I go to "admin/content"
        Then I should see "Page one"
        And I should see "Page two"

    Scenario: Create a node programatically with listed field(s) and check it displays
        Given I am viewing an "basic_page" content:
        | title | My node with fields! |
        Then I should see the text "My node with fields!"

    Scenario: Target links within table rows
        Given I am logged in as a user with the "sysadmin" role
        When I am at "/admin/structure/menu/"
        And I click "Edit menu" in the "Administration" row
        And I should see text matching "menu Administration"

# User & role tests

    Scenario Outline: Create nodes manualy using different roles
        Given I am logged in as a user with the "<role_machine_name>" role
        When I go to "node/add/basic_page"
        And I fill in "Title" with "Test node created by user with <role_machine_name> role"
        And I press the "edit-submit--2" button
        When I go to "admin/content"
        And I take a screenshot
        Then I should see "Test node created by user with <role_machine_name> role"

        Examples:
        | role_machine_name |
        |    sysadmin       |
        |    contributor    |

