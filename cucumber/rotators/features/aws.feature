Feature: AWS Secret Access Key Rotation

  Background: Configure an AWS rotator
    Given I reset my root policy
    And I have the root policy:
    """
    - !policy
      id: aws
      body:
        - !variable region
        - !variable access_key_id
        - !variable secret_key_proxy
        - !variable
          id: secret_access_key
          annotations:
            rotation/rotator: aws/secret_key
            rotation/ttl: PT1S
    """
    And I add the value "us-east-1" to variable "aws/region"
    And I add ENV[AWS_ACCESS_KEY_ID] to variable "aws/access_key_id"
    And I add ENV[AWS_SECRET_ACCESS_KEY] to variable "aws/secret_key"

  Scenario: Values are rotated according to the policy
    # TODO make this change to the postgres one too
    # get the policy id in
    Given I moniter AWS variables in policy "aws" for 3 values in 20 seconds
    Then the last two sets of credentials both work
    And all previous ones no longer work
