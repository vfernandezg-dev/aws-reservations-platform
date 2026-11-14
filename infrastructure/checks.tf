# Continuous validation: evaluated on every plan/apply once the stack exists.
# Failures surface as warnings and never block a run.

check "api_health_through_cloudfront" {
  data "http" "api_health" {
    url = "${module.cdn.url}/api/health"

    retry {
      attempts     = 3
      min_delay_ms = 2000
    }
  }

  assert {
    condition     = data.http.api_health.status_code == 200
    error_message = "GET ${module.cdn.url}/api/health returned ${data.http.api_health.status_code}; expected 200."
  }
}

check "static_site_through_cloudfront" {
  data "http" "home" {
    url = module.cdn.url
  }

  assert {
    condition     = data.http.home.status_code == 200
    error_message = "GET ${module.cdn.url}/ returned ${data.http.home.status_code}; expected 200."
  }
}
