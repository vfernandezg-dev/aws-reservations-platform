resource "aws_apigatewayv2_api" "this" {
  name          = var.name
  description   = "Public API for ${var.name}, fronted by CloudFront"
  protocol_type = "HTTP"

  tags = {
    Name = var.name
  }
}

resource "aws_apigatewayv2_vpc_link" "this" {
  name               = var.name
  subnet_ids         = var.vpc_link_subnet_ids
  security_group_ids = [var.vpc_link_security_group_id]

  tags = {
    Name = var.name
  }
}

###############################################################################
# Integrations (private: VPC Link -> internal ALB listener)
###############################################################################

# Open routes: strip identity headers so clients cannot spoof them.
resource "aws_apigatewayv2_integration" "public" {
  api_id                 = aws_apigatewayv2_api.this.id
  description            = "Internal ALB (anonymous routes)"
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = var.alb_listener_arn
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.this.id
  payload_format_version = "1.0"
  timeout_milliseconds   = 29000

  request_parameters = {
    "remove:header.x-user-sub"   = "''"
    "remove:header.x-user-email" = "''"
  }
}

# Protected routes: forward the verified JWT claims as trusted headers.
resource "aws_apigatewayv2_integration" "authenticated" {
  count = var.enable_auth ? 1 : 0

  api_id                 = aws_apigatewayv2_api.this.id
  description            = "Internal ALB (JWT-authenticated routes)"
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = var.alb_listener_arn
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.this.id
  payload_format_version = "1.0"
  timeout_milliseconds   = 29000

  request_parameters = {
    "overwrite:header.x-user-sub"   = "$context.authorizer.claims.sub"
    "overwrite:header.x-user-email" = "$context.authorizer.claims.email"
  }
}

###############################################################################
# Cognito JWT authorizer
###############################################################################

resource "aws_apigatewayv2_authorizer" "cognito" {
  count = var.enable_auth ? 1 : 0

  api_id           = aws_apigatewayv2_api.this.id
  name             = "cognito"
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]

  # API Gateway checks `aud` (ID tokens) or `client_id` (access tokens)
  # against the audience list, so both token types are accepted.
  jwt_configuration {
    issuer   = var.jwt_issuer
    audience = var.jwt_audience
  }
}

###############################################################################
# Routes. CloudFront forwards only /api/*, so every route lives under /api.
###############################################################################

resource "aws_apigatewayv2_route" "health" {
  #checkov:skip=CKV_AWS_309:Health endpoint is intentionally anonymous (returns no data).
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "GET /api/health"
  target             = "integrations/${aws_apigatewayv2_integration.public.id}"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_route" "public" {
  #checkov:skip=CKV_AWS_309:/api/public/* is the anonymous part of the API by design; protected routes use the JWT authorizer.
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "ANY /api/public/{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.public.id}"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_route" "protected" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "ANY /api/{proxy+}"
  target             = "integrations/${var.enable_auth ? aws_apigatewayv2_integration.authenticated[0].id : aws_apigatewayv2_integration.public.id}"
  authorization_type = var.enable_auth ? "JWT" : "NONE"
  authorizer_id      = var.enable_auth ? aws_apigatewayv2_authorizer.cognito[0].id : null
}

###############################################################################
# Stage + access logs
###############################################################################

resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigateway/${var.name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  # Both limits MUST be set: an omitted limit defaults to 0 (= throttle all).
  default_route_settings {
    throttling_rate_limit    = var.throttling_rate_limit
    throttling_burst_limit   = var.throttling_burst_limit
    detailed_metrics_enabled = true
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    format = jsonencode({
      requestId          = "$context.requestId"
      ip                 = "$context.identity.sourceIp"
      requestTime        = "$context.requestTime"
      httpMethod         = "$context.httpMethod"
      routeKey           = "$context.routeKey"
      path               = "$context.path"
      status             = "$context.status"
      protocol           = "$context.protocol"
      responseLength     = "$context.responseLength"
      responseLatency    = "$context.responseLatency"
      integrationLatency = "$context.integrationLatency"
      integrationStatus  = "$context.integrationStatus"
      integrationError   = "$context.integrationErrorMessage"
      authorizerError    = "$context.authorizer.error"
      userAgent          = "$context.identity.userAgent"
    })
  }

  tags = {
    Name = var.name
  }
}
