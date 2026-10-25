Feature: Greeting

  Scenario: AC 1 greeting a named user
    Given a name "Ada"
    When I run the tool with that name
    Then it prints "Hello, Ada!"
