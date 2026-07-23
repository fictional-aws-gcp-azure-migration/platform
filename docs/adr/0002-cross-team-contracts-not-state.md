# ADR 0002 — Cross-team coupling via contracts, never shared state

**Status:** accepted

## Context

`orders-service` depends on `inventory-service` in two ways: it needs
inventory's API URL, and it needs to know inventory's response shape. The lazy
answers — reach into inventory's Terraform state for the URL, import inventory's
Python models for the shape — both create hidden coupling that breaks team
independence.

## Decision

Couple through **published contracts** that work across accounts and let either
side deploy first.

- **Runtime location → SSM Parameter Store.** Inventory publishes its API URL to
  `/platform/inventory/api-url`. Orders reads it via `resolve_inventory_url()`
  (an SSM lookup in AWS, an env var locally). Orders never reads inventory's
  Terraform state.
- **Response shape → published OpenAPI.** Inventory generates
  `contracts/openapi.json` from its FastAPI type hints; CI fails if it drifts.
  Orders vendors it as `contracts/inventory.json` and fakes its client against
  it in tests.

## Rationale

- A Terragrunt `dependency` block across a team boundary couples deploy ordering
  (orders can't plan until inventory's state exists) and leaks state ownership.
  A published parameter has neither problem: it works across separate accounts,
  and either team can deploy independently once the parameter exists.
- Vendoring the contract rather than importing the code is what makes the
  isolation test real: `orders-service` builds and tests with no access to
  inventory's source.

## Consequences

- The demo deploys inventory first (it publishes the parameter) then orders, but
  after the first deploy either can redeploy freely.
- Contract drift is caught in CI, not in production, because the OpenAPI file is
  regenerated and diffed.
- This is exactly the seam that later lets one service migrate to Kubernetes
  while the other stays on AWS — they share a contract, not a runtime.
