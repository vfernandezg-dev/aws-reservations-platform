mock_provider "aws" {}

variables {
  name                       = "test"
  vpc_link_subnet_ids        = ["subnet-a", "subnet-b"]
  vpc_link_security_group_id = "sg-0123456789abcdef0"
  alb_listener_arn           = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/test/0123/4567"
  jwt_issuer                 = "https://cognito-idp.us-east-1.amazonaws.com/us-east-1_example"
  jwt_audience               = ["exampleclientid"]
}

run "protected_routes_require_jwt" {
  command = plan

  module {
    source = "./modules/api"
  }

  assert {
    condition     = aws_apigatewayv2_route.protected.authorization_type == "JWT"
    error_message = "/api/{proxy+} must use the Cognito JWT authorizer."
  }

  assert {
    condition     = aws_apigatewayv2_route.public.authorization_type == "NONE"
    error_message = "/api/public/* must stay anonymous."
  }

  assert {
    condition     = aws_apigatewayv2_integration.public.request_parameters["remove:header.x-user-sub"] == "''"
    error_message = "Anonymous routes must strip identity headers to prevent spoofing."
  }

  assert {
    condition     = aws_apigatewayv2_stage.default.default_route_settings[0].throttling_rate_limit > 0 && aws_apigatewayv2_stage.default.default_route_settings[0].throttling_burst_limit > 0
    error_message = "Both throttling limits must be set (an omitted limit means 0 = throttle everything)."
  }
}

run "auth_can_be_disabled_for_dev" {
  command = plan

  module {
    source = "./modules/api"
  }

  variables {
    enable_auth = false
  }

  assert {
    condition     = aws_apigatewayv2_route.protected.authorization_type == "NONE" && length(aws_apigatewayv2_authorizer.cognito) == 0
    error_message = "Disabling auth must remove the authorizer."
  }
}

run "auth_requires_an_issuer" {
  command = plan

  module {
    source = "./modules/api"
  }

  variables {
    jwt_issuer = null
  }

  expect_failures = [var.jwt_issuer]
}
