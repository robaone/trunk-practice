# Trunk CI/CD Workflow - Gherkin Specifications

This document describes the expected behavior of the Trunk CI/CD workflow using Gherkin syntax.

---

## Feature: Workflow Triggers

```gherkin
Feature: Trunk CI/CD Workflow Triggers
  The workflow should respond to specific GitHub events to enable 
  continuous integration and deployment

  Scenario: Workflow triggers on push to main branch
    Given a developer pushes code to the main branch
    When the push event is received
    Then the workflow should be triggered
    And the initialization job should run

  Scenario: Workflow triggers on pull request opened to main
    Given a developer opens a pull request targeting the main branch
    When the pull request event with type "opened" is received
    Then the workflow should be triggered

  Scenario: Workflow triggers on pull request synchronized
    Given an existing pull request targeting the main branch
    When new commits are pushed to the pull request
    Then the workflow should be triggered with event type "synchronize"

  Scenario: Workflow triggers on pull request reopened
    Given a previously closed pull request targeting the main branch
    When the pull request is reopened
    Then the workflow should be triggered with event type "reopened"

  Scenario: Workflow triggers on pull request labeled
    Given an existing pull request targeting the main branch
    When a label is added to the pull request
    Then the workflow should be triggered with event type "labeled"

  Scenario: Workflow triggers on pull request marked ready for review
    Given a draft pull request targeting the main branch
    When the pull request is marked ready for review
    Then the workflow should be triggered with event type "ready_for_review"

  Scenario: Workflow triggers on release published
    Given a new release is created
    When the release is published with a tag
    Then the workflow should be triggered
    And the deploy-to-production job should run
```

---

## Feature: Initialization Job

```gherkin
Feature: Initialization Job
  The initialization job prepares the workflow by detecting changes 
  and building the project matrix

  Background:
    Given the workflow has been triggered
    And the event is not a draft pull request

  Scenario: Initialize job runs for non-draft pull requests
    Given a pull request is not in draft mode
    When the workflow is triggered
    Then the initialize job should run

  Scenario: Initialize job runs when draft PR has test label
    Given a pull request is in draft mode
    And the pull request has the label "test"
    And the event action is "labeled"
    When the workflow is triggered
    Then the initialize job should run

  Scenario: Initialize job skips draft pull requests without test label
    Given a pull request is in draft mode
    And the pull request does not have the label "test"
    When the workflow is triggered
    Then the initialize job should be skipped

  Scenario: Cancel previous workflow runs on non-main branches
    Given the workflow is triggered on a feature branch
    When the initialize job runs
    Then previous workflow runs for this branch should be cancelled

  Scenario: Do not cancel previous runs on main branch
    Given the workflow is triggered on the main branch
    When the initialize job runs
    Then previous workflow runs should not be cancelled

  Scenario: Detect changed files
    Given files have been modified in the repository
    When the initialize job runs
    Then the changed files should be detected
    And the list of changed files should be available for matrix generation

  Scenario: Get latest release version
    Given previous releases exist in the repository
    When the initialize job runs
    Then the latest release version should be retrieved
    And the version should be available as an output

  Scenario: Build project matrix from changed files
    Given the changed files list is available
    When the matrix generation script runs
    Then a matrix object should be generated
    And the matrix should include projects with changed files
    And the matrix should be available as a job output
```

---

## Feature: Unit Tests Job

```gherkin
Feature: Unit Tests Job
  Unit tests should run for each affected project in the matrix

  Background:
    Given the initialize job has completed successfully
    And the project matrix contains at least one project

  Scenario: Skip unit tests when no projects changed
    Given the project matrix is empty
    When the workflow evaluates the unit-tests job
    Then the unit-tests job should be skipped

  Scenario: Run project-specific unit tests
    Given the project matrix includes "sample-calculator"
    When the unit-tests job runs for "sample-calculator"
    Then the project-specific unit-test action should execute
    And the action at "./project/sample-calculator/.github/actions/unit-test" should be used

  Scenario: Run root unit tests when root files changed
    Given the project matrix includes "."
    And a package.json exists at the repository root
    And the package.json contains a "test" script
    When the unit-tests job runs for "."
    Then npm install should be executed
    And npm run test should be executed

  Scenario: Skip root unit tests when no test script exists
    Given the project matrix includes "."
    And a package.json exists at the repository root
    But the package.json does not contain a "test" script
    When the unit-tests job runs for "."
    Then the test step should be skipped with a message

  Scenario: Skip root unit tests when no package.json exists
    Given the project matrix includes "."
    But no package.json exists at the repository root
    When the unit-tests job runs for "."
    Then the test step should be skipped with a message

  Scenario: Unit tests have a timeout
    Given the unit-tests job is running
    When the job execution exceeds 15 minutes
    Then the job should be cancelled due to timeout
```

---

## Feature: Feature Tests Job

```gherkin
Feature: Feature Tests Job
  Feature tests should run for each affected project in the matrix

  Background:
    Given the initialize job has completed successfully
    And the project matrix contains at least one project

  Scenario: Skip feature tests when no projects changed
    Given the project matrix is empty
    When the workflow evaluates the feature-tests job
    Then the feature-tests job should be skipped

  Scenario: Run project-specific feature tests
    Given the project matrix includes "sample-calculator"
    When the feature-tests job runs for "sample-calculator"
    Then the project-specific feature-test action should execute
    And the action at "./project/sample-calculator/.github/actions/feature-test" should be used

  Scenario: Run root feature tests when root files changed
    Given the project matrix includes "."
    And a package.json exists at the repository root
    And the package.json contains a "test:e2e" script
    When the feature-tests job runs for "."
    Then npm install should be executed
    And npm run test:e2e should be executed

  Scenario: Skip root feature tests when no e2e script exists
    Given the project matrix includes "."
    And a package.json exists at the repository root
    But the package.json does not contain a "test:e2e" script
    When the feature-tests job runs for "."
    Then the feature test step should be skipped with a message

  Scenario: Skip root feature tests when no package.json exists
    Given the project matrix includes "."
    But no package.json exists at the repository root
    When the feature-tests job runs for "."
    Then the feature test step should be skipped with a message

  Scenario: Feature tests have a timeout
    Given the feature-tests job is running
    When the job execution exceeds 15 minutes
    Then the job should be cancelled due to timeout
```

---

## Feature: Update PR Description Job

```gherkin
Feature: Update PR Description Job
  The PR description should be automatically updated with AI-generated 
  content when specific labels are present

  Scenario: Update PR description with auto-pr-description label
    Given a pull request is targeting the main branch
    And the pull request is not in draft mode
    And the pull request has the label "auto-pr-description"
    When the workflow runs
    Then the update-pr-description job should run
    And the Gemini API should be used to generate the description
    And the PR description should be updated

  Scenario: Update PR description when test label is added
    Given a pull request is targeting the main branch
    And the event action is "labeled"
    And the label added is "test"
    When the workflow runs
    Then the update-pr-description job should run

  Scenario: Skip PR description update for draft PRs without labels
    Given a pull request is targeting the main branch
    And the pull request is in draft mode
    And the event action is not "labeled"
    When the workflow runs
    Then the update-pr-description job should be skipped

  Scenario: Skip PR description update without required labels
    Given a pull request is targeting the main branch
    And the pull request is not in draft mode
    But the pull request does not have the "auto-pr-description" label
    And the event action is not "labeled" with "test"
    When the workflow runs
    Then the update-pr-description job should be skipped

  Scenario: Skip PR description update for non-main base branch
    Given a pull request is not targeting the main branch
    When the workflow runs
    Then the update-pr-description job should be skipped
```

---

## Feature: Deploy to Testing Job

```gherkin
Feature: Deploy to Testing Job
  Projects should be deployed to the testing environment after 
  successful tests on main branch pushes

  Background:
    Given the workflow was triggered by a push to the main branch
    And the initialize job has completed successfully
    And the unit-tests job has completed successfully
    And the feature-tests job has completed successfully
    And the project matrix contains at least one project

  Scenario: Deploy project to testing environment
    Given the project matrix includes "sample-calculator"
    And the project has a deploy action at ".github/actions/deploy/action.yml"
    When the deploy-to-testing job runs for "sample-calculator"
    Then the project-specific deploy action should execute
    And the deployment should target the "testing" environment

  Scenario: Skip deploy when deploy action does not exist
    Given the project matrix includes "sample-calculator"
    But the project does not have a deploy action at ".github/actions/deploy/action.yml"
    When the deploy-to-testing job runs for "sample-calculator"
    Then the project-specific deploy step should be skipped

  Scenario: Deploy root project to testing
    Given the project matrix includes "."
    And a package.json exists at the repository root
    And the package.json contains a "deploy:testing" script
    When the deploy-to-testing job runs for "."
    Then npm install should be executed
    And npm run deploy:testing should be executed

  Scenario: Skip root deploy when no deploy script exists
    Given the project matrix includes "."
    And a package.json exists at the repository root
    But the package.json does not contain a "deploy:testing" script
    When the deploy-to-testing job runs for "."
    Then the deploy step should be skipped with a message

  Scenario: Skip deploy to testing for pull requests
    Given the workflow was triggered by a pull request event
    When the workflow evaluates the deploy-to-testing job
    Then the deploy-to-testing job should be skipped

  Scenario: Skip deploy to testing for releases
    Given the workflow was triggered by a release event
    When the workflow evaluates the deploy-to-testing job
    Then the deploy-to-testing job should be skipped

  Scenario: Skip deploy to testing when matrix is empty
    Given the project matrix is empty
    When the workflow evaluates the deploy-to-testing job
    Then the deploy-to-testing job should be skipped

  Scenario: Deploy to testing has a timeout
    Given the deploy-to-testing job is running
    When the job execution exceeds 15 minutes
    Then the job should be cancelled due to timeout

Feature: Perform a test deploy to Testing
  As a software developer
  In order to test a feature in the testing environment
  I want to trigger a deployment to testing from a pull request
  
  Scenario: Deploy to testing from draft pull request
    Given a draft pull request with changes in one or more projects
    When the deploy label is added to the pull request
    Then unit-tests should run
    And feature-tests should run
    And deploy-to-testing should run after unit-tests and feature-tests pass

  Scenario: Deploy to testing from ready-for-review pull request
    Given a ready-for-review pull request with changes in one or more projects
    When the deploy label is added to the pull request
    Then unit-tests should run
    And feature-tests should run
    And deploy-to-testing should run after unit-tests and feature-tests pass
    
```

---

## Feature: Deploy to Production Job

```gherkin
Feature: Deploy to Production Job
  Projects should be deployed to the production environment 
  when a release is published

  Background:
    Given the workflow was triggered by a release event
    And the release was published with a tag
    And the initialize job has completed successfully
    And the project matrix contains at least one project

  Scenario: Deploy project to production environment
    Given the project matrix includes "sample-calculator"
    And the project has a deploy action at ".github/actions/deploy/action.yml"
    When the deploy-to-production job runs for "sample-calculator"
    Then the project-specific deploy action should execute
    And the deployment should target the "production" environment
    And the RELEASE_TAG_NAME environment variable should be set

  Scenario: Skip deploy when deploy action does not exist
    Given the project matrix includes "sample-calculator"
    But the project does not have a deploy action at ".github/actions/deploy/action.yml"
    When the deploy-to-production job runs for "sample-calculator"
    Then the project-specific deploy step should be skipped

  Scenario: Deploy root project to production
    Given the project matrix includes "."
    And a package.json exists at the repository root
    And the package.json contains a "deploy:production" script
    When the deploy-to-production job runs for "."
    Then npm install should be executed
    And npm run deploy:production should be executed

  Scenario: Skip root deploy when no deploy script exists
    Given the project matrix includes "."
    And a package.json exists at the repository root
    But the package.json does not contain a "deploy:production" script
    When the deploy-to-production job runs for "."
    Then the deploy step should be skipped with a message

  Scenario: Skip deploy to production for push events
    Given the workflow was triggered by a push to main
    When the workflow evaluates the deploy-to-production job
    Then the deploy-to-production job should be skipped

  Scenario: Skip deploy to production for pull requests
    Given the workflow was triggered by a pull request event
    When the workflow evaluates the deploy-to-production job
    Then the deploy-to-production job should be skipped

  Scenario: Skip deploy to production when no tag present
    Given the workflow was triggered by a release event
    But the reference does not start with "refs/tags/"
    When the workflow evaluates the deploy-to-production job
    Then the deploy-to-production job should be skipped

  Scenario: Skip deploy to production when matrix is empty
    Given the project matrix is empty
    When the workflow evaluates the deploy-to-production job
    Then the deploy-to-production job should be skipped

  Scenario: Deploy to production has a timeout
    Given the deploy-to-production job is running
    When the job execution exceeds 15 minutes
    Then the job should be cancelled due to timeout
```

---

## Feature: Job Dependencies and Flow

```gherkin
Feature: Job Dependencies and Execution Flow
  Jobs should execute in the correct order with proper dependencies

  Scenario: Unit tests and feature tests run in parallel after initialization
    Given the initialize job has completed
    And the project matrix is not empty
    When the workflow continues
    Then the unit-tests job should start
    And the feature-tests job should start
    And both jobs should run in parallel

  Scenario: Deploy to testing waits for all tests to pass
    Given the workflow was triggered by a push to main
    When the initialize job completes
    And the unit-tests job completes successfully
    And the feature-tests job completes successfully
    Then the deploy-to-testing job should start

  Scenario: Deploy to testing blocked by failed unit tests
    Given the workflow was triggered by a push to main
    And the initialize job has completed
    When the unit-tests job fails
    Then the deploy-to-testing job should not run

  Scenario: Deploy to testing blocked by failed feature tests
    Given the workflow was triggered by a push to main
    And the initialize job has completed
    When the feature-tests job fails
    Then the deploy-to-testing job should not run

  Scenario: Deploy to production only depends on initialization
    Given the workflow was triggered by a release event
    When the initialize job completes
    Then the deploy-to-production job should start
    And the deploy-to-production job should not wait for test jobs
```

---

## Feature: Environment Configuration

```gherkin
Feature: Environment Configuration
  The workflow should use consistent environment settings

  Scenario: Use Node.js version 22.x
    Given any job is running
    When Node.js is set up
    Then Node.js version 22.x should be installed

  Scenario: Project root is set to "project" directory
    Given the workflow is running
    Then the PROJECT_ROOT environment variable should be "project"

  Scenario: Testing environment is used for testing deploys
    Given the deploy-to-testing job is running
    Then the job should run in the "testing" environment

  Scenario: Production environment is used for production deploys
    Given the deploy-to-production job is running
    Then the job should run in the "production" environment

  Scenario: Release tag is available during production deployment
    Given the deploy-to-production job is running
    Then the RELEASE_TAG_NAME environment variable should contain the release tag
```

---

## Feature: Matrix Strategy

```gherkin
Feature: Matrix Strategy for Parallel Project Processing
  The workflow should process multiple projects in parallel using 
  a matrix strategy

  Scenario: Generate matrix based on changed files
    Given files have changed in "project/sample-calculator/"
    When the matrix is generated
    Then the matrix should include "sample-calculator" project

  Scenario: Generate matrix for root changes
    Given files have changed in the repository root
    When the matrix is generated
    Then the matrix should include "." as a project

  Scenario: Empty matrix when no relevant changes
    Given only ignored files have changed
    When the matrix is generated
    Then the matrix should be empty
    And dependent jobs should be skipped

  Scenario: Multiple projects in matrix
    Given files have changed in "project/sample-calculator/"
    And files have changed in "project/another-project/"
    When the matrix is generated
    Then the matrix should include both projects
    And jobs should run for each project in parallel
```


