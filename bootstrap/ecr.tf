###############################################################################
# Shared container registry: images are built once and the same immutable tag
# is promoted dev -> staging -> prod.
###############################################################################

# trivy:ignore:AWS-0033 Images contain no secrets; the AWS managed KMS key is sufficient.
resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-app"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }

  tags = {
    Name = "${var.project_name}-app"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  # Only a count-based rule: multi-arch images and their SBOM/provenance
  # attestations are pushed as an image index whose child manifests are
  # untagged, so an "expire untagged" rule could break a deployed image.
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep the 30 most recent images (indexes, manifests and attestations count separately)"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = { type = "expire" }
      },
    ]
  })
}
