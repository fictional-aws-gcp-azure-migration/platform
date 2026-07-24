# ADR 0003 — Cost decisions (FinOps as an equal concern)

**Status:** accepted

## Context

Cost is a first-class design input here, not an afterthought. The decisions
below are the ones that move the bill, recorded so the tradeoffs are explicit.

## Decisions

- **No NAT Gateway anywhere; no VPC at all for inventory.** A NAT is ~$32/month
  plus data processing — the largest single line item this workload would
  otherwise carry. Orders runs Fargate in public subnets with tight security
  groups and `assign_public_ip`; inventory is serverless and needs no network.
  (See inventory ADR 0002.)
- **DynamoDB on-demand billing.** No capacity planning for a spiky demo
  workload; you pay per request with zero idle cost.
- **API Gateway HTTP API, not REST API.** ~$1.00 per million requests versus
  ~$3.50, with the features this workload actually uses.
- **RDS `db.t4g.micro`, gp3, single-AZ, 7-day backups.** Smallest sensible
  Graviton instance; single-AZ is correct for a non-production sample and
  explicitly *not* a recommendation for production.
- **Structural tagging via `default_tags`.** `Team` and `CostCenter` come from
  each repo's `root.hcl` and are applied to every resource by the provider, so
  cost allocation and showback work with no per-resource discipline and no
  policy linter.

## The one-account demo shortcut

In a real landing zone each team gets its own AWS account. For this sample both
repos' `root.hcl` point at the **same** account; the only differences in the
real world are the account ID and the assumed OIDC role ARN. State is still
isolated per team via distinct S3 key prefixes, so the isolation mechanics are
real even though the account boundary is simulated. This is stated plainly
rather than hidden, and it avoids spending a day on AWS Organizations for a
demo.

The full account/org baseline this shortcut stands in for — topology, guardrails,
centralized logging, tagging, account vending — is written up in
[landing-zone-standards.md](../landing-zone-standards.md); the decision to specify
it rather than deploy it is [ADR 0004](0004-landing-zone-standards.md).

## Consequences

- The whole thing tears down with a documented `terragrunt run --all -- destroy`,
  and a budget alarm is created before any resource.
- Every cost lever above is named in the AWS-coupling table or a README, so a
  reviewer can see the reasoning without reading the Terraform.
