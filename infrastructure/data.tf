data "aws_availability_zones" "available" {
  #checkov:skip=CKV_AWS_394:AZs are sorted and sliced to var.az_count, then passed explicitly to modules; new AZs never change the layout.
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# The repository is created once by the bootstrap stack and shared by all
# environments ("build once, promote the same image tag").
data "aws_ecr_repository" "app" {
  name = var.ecr_repository_name
}
