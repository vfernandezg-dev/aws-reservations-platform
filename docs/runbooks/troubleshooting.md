# Runbook — Troubleshooting

| Symptom | Likely cause | Check / fix |
|---|---|---|
| `403` on `/api/*` through CloudFront | WAF block, or origin secret mismatch after a partial apply | WAF sampled requests / `aws-waf-logs-*` log group; re-apply so CloudFront and the ALB share the same `random_password.origin_verify` |
| `403` when calling the `execute-api` URL directly | Expected: requests that bypass CloudFront are rejected by the ALB | Use the `cloudfront_url` output |
| `401` on `/api/{proxy+}` | Missing/expired JWT, wrong app client (audience) | Decode the token; `aud`/`client_id` must equal `cognito_client_id` |
| `503` from `/api/public/db-health` | Database failover/maintenance in progress, or the DB is unreachable | Check the RDS events, the `/ecs/<name>` logs and the `db` security group |
| `503` from the ALB | No healthy targets | ECS service events, `/ecs/<name>` logs, `UnHealthyHostCount` alarm |
| Deployment rolled back | New tasks failed health checks | ECS service events; container logs of the stopped tasks |
| Task stuck in `PENDING` / `CannotPullContainerError` | Missing image tag or no route to ECR | `aws ecr describe-images`; NAT gateway or interface endpoints + S3 gateway endpoint |
| `ResourceInitializationError: unable to pull secrets` | Execution role cannot read/decrypt the DB secret | `read-db-secret` inline policy and KMS key policy |
| `Error acquiring the state lock` | Another run holds the lock, or a run crashed | Wait; if stale: `terraform force-unlock <id>` after confirming no run is active |
| `init` asks to migrate state between environments | Backend switched without `-reconfigure` | Always use `make init ENV=<env>` |
| Plan wants to replace the CloudFront distribution | Changed origin IDs or managed policy names | Review carefully; keep IDs stable |

Useful commands:

```bash
terraform -chdir=infrastructure output                 # endpoints, IDs, dashboard URL
aws ecs describe-services --cluster <cluster> --services <service> --query 'services[0].events[:5]'
aws logs tail /ecs/<name> --follow
aws rds describe-db-instances --db-instance-identifier <name> --query 'DBInstances[0].DBInstanceStatus'
```
