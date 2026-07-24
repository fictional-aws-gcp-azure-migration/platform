# ADR 0004 — Landing zone: specify the standard, simulate the account boundary

**Status:** accepted

## Context

The organization runs teams in isolation ([ADR 0001](0001-service-repos-own-their-iac.md)),
attributes cost structurally ([ADR 0003](0003-cost-decisions.md)), and couples
teams through contracts rather than shared state
([ADR 0002](0002-cross-team-contracts-not-state.md)). All three assume an
underlying account/org baseline — a *landing zone* — that this sample references
in four places but never defines:

- the "one-account demo shortcut" in [ADR 0003](0003-cost-decisions.md#the-one-account-demo-shortcut),
- the landing-zone note in [TERRAFORM_TERRAGRUNT.md](../../../TERRAFORM_TERRAGRUNT.md),
- and the `DEMO SHORTCUT` comments in both repos' `root.hcl`.

Two questions follow: **what is the landing-zone standard**, and **how much of it
should a two-service sample actually deploy**.

## Decision

**Specify the landing zone as a standard; simulate the account boundary in the
demo.**

1. The reference architecture is written down in
   [landing-zone-standards.md](../landing-zone-standards.md): account-per-team-per-env
   under Organizations OUs, SSO for humans and OIDC for CI, an SCP + AWS Config
   guardrail baseline, a central Log Archive account, an org tag policy extending
   the workloads' `default_tags`, and an account factory for vending — with a
   GCP/Azure mapping for the migration targets.

2. **None of it is provisioned here.** Both repos keep pointing at a single
   account; only `aws_account_id` and the assumed OIDC role ARN would differ per
   team in a real deployment. The isolation *mechanics* — per-team Terraform state
   by S3 key prefix, structural tagging, OIDC-shaped CI — are real; the account
   *boundary* is simulated.

This ADR supersedes and expands the shortcut note previously carried only in
[ADR 0003](0003-cost-decisions.md#the-one-account-demo-shortcut).

## Rationale

- **Why account-per-team over IAM in one account.** Separate accounts are a
  default-deny blast radius and an exact billing boundary, not merely a permission
  model. The sample's per-team state key prefix already draws that seam; promoting
  it from key-prefix to account is a change of `aws_account_id`, nothing more.
- **Why guardrails at the org, not more per-repo policy-as-code.** ADR 0001 ships
  no OPA/Conftest pack because required tags are already structural and checkov
  covers the rest. SCPs are the org-scoped version of that same judgment: a floor
  no team can drop below, holding even for resources a pipeline never scanned —
  worth more than the same rule duplicated across every repo.
- **Why not deploy the org for the demo.** Standing up Organizations, OUs, SCPs,
  Control Tower, and a Log Archive account for a teardown-able two-service sample
  costs a day and demonstrates nothing the written standard doesn't. Knowing when
  *not* to build a layer is the same principal-level skill as knowing when to
  ([ADR 0001](0001-service-repos-own-their-iac.md)). The honest shortcut, stated
  plainly, is the right call for a sample and the wrong call for production — and
  the standard says exactly that.

## Consequences

- The four "shortcut" references now point at a real standard instead of dangling;
  the demo's single-account choice is a documented decision, not an omission.
- Going multi-account is a bounded change: per-team `aws_account_id` + OIDC role
  ARN, plus provisioning the org baseline from the standard. No workload IaC
  changes — the modules and live units are account-agnostic by construction.
- The GCP/Azure mapping in the standard means the migration engagement inherits
  the same guarantees under different primitives — a re-platform, not a
  re-governance.
