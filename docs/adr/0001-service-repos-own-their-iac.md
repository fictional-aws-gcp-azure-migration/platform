# ADR 0001 — Service repos own their IaC; the platform repo is small

**Status:** accepted

## Context

The organization runs teams in isolation and asynchronously. Two structural
questions follow: where does each team's infrastructure code live, and what does
the platform team centralize?

## Decision

**Each service repo holds both its application and the Terraform/Terragrunt that
deploys it.** There is no central `infrastructure-live` repo.

**The `platform` repo contains only what has two real consumers** — currently
the reusable CI workflows and the integrated demo. Nothing else.

## Rationale

### Why colocated IaC

- An app change and its infra change ship in **one atomic PR**. Adding an env
  var, a queue, or an IAM permission touches code and Terraform together; across
  two repos that is a coordinated multi-PR dance async teams cannot afford.
- A central live repo funnels every team through one repo, one merge queue, one
  review bottleneck — centralized ops wearing the costume of team autonomy.

### What autonomy costs, and how it's paid back

The real cost is **org-wide visibility**: you can no longer read one repo to see
the whole estate, and teams drift. Three structural guarantees pay it back —
deliberately three small things, not a governance apparatus:

1. **Versioned shared CI** — teams consume the reusable workflows pinned by tag,
   so every pipeline runs the same scans and the same OIDC pattern. Consistency
   enforced by the pipeline, not by review.
2. **`default_tags`** in the generated provider — cost attribution is structural;
   an untagged resource cannot exist, so no tag-policy linter is needed.
3. **Contracts over state** for cross-team coupling (ADR 0002).

### What we did NOT centralize

- **No shared Terraform module.** `inventory-service` needs no VPC, so the one
  candidate (`network`) has exactly one consumer and stays local to orders. A
  module with one consumer is indirection plus a release process, not reuse. The
  extraction trigger is explicit: *the moment a second consumer appears, it moves
  to `platform` and gets tagged.*
- **No OPA/Conftest policy pack.** The rule it would enforce — required tags — is
  already guaranteed by `default_tags`, and checkov covers the security baseline
  off the shelf. Knowing when not to add a governance layer is the same skill as
  knowing when to.

## Consequences

- Versioning discipline is demonstrated by pinning the two teams to different
  workflow versions — one adopts a platform change while the other does not,
  with no coordination.
- If the estate grew to many teams, a read-only inventory (e.g. a state-scraping
  dashboard) would become worth adding. At two teams it is not.
