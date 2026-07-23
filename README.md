# Platform — the paved road

This is the entry point for a three-repo sample that models how an organization
with **independent, asynchronous teams** builds AWS workloads so they can later
be migrated off AWS with minimal disruption.

```
orders-service/      team A — an API on ECS Fargate + RDS Postgres
inventory-service/   team B — Lambdas on API Gateway + SQS + DynamoDB
platform/            the paved road: shared CI, the end-to-end demo   (this repo)
```

## The thesis

> **Ephemeral compute is portable; persistent state is not.** Draw the
> architectural seam there, and a cloud migration becomes a data-migration
> problem plus a redeploy — not a rewrite.

Everything here is arranged to make that claim *demonstrable* rather than
asserted, and to surface its honest asymmetry:

- **Postgres is the easy half.** RDS → Cloud SQL / Azure Flexible Server is
  close to a connection-string change, and the schema is already built to
  survive logical-replication migration (every table has a primary key;
  `updated_at` is trigger-maintained).
- **DynamoDB is the hard half.** There is no equivalent managed service on GCP
  or Azure — Firestore and Cosmos DB differ semantically, and neither cloud
  ships first-party near-zero-downtime tooling. The mitigation is structural:
  every DynamoDB call already sits behind a repository interface, so the
  migration is a swappable implementation, not a rewrite.

## Run the whole thing

```bash
# expects the three repos checked out side by side
./demo.sh
```

This builds both teams' services and places orders through the real cross-team
path: a synchronous stock check (orders → inventory's API) and an asynchronous
decrement (orders → SQS → inventory's worker → DynamoDB). Explore the two
generated OpenAPI docs at `localhost:8000/docs` and `localhost:8001/docs`.

## What each repo demonstrates

| Repo | Runtime | Store | The point |
|---|---|---|---|
| `orders-service` | ECS Fargate + ALB | RDS Postgres | The clean migration seam; a network layer |
| `inventory-service` | 2 Lambdas + API Gateway | DynamoDB | The dirty seam; the invoker pattern; **no VPC** |
| `platform` | GitHub Actions + demo | — | Shared CI, version pinning, the integrated demo |

## AWS-coupling inventory — the bridge to Phase 2

Every AWS-specific dependency, and how portable it is. This table is the map for
the migration engagement.

| AWS service | Used by | Target: GCP | Target: Azure | Portability | Where it's isolated |
|---|---|---|---|---|---|
| RDS PostgreSQL | orders | Cloud SQL | Flexible Server | **High** — managed logical-replication migration; connection-string change | `orders-service/app/db.py` |
| ECS Fargate | orders | GKE | AKS | **High** — container already builds and runs locally | Dockerfile + `uvicorn` |
| ALB | orders | GCLB / Ingress | App Gateway / Ingress | **High** — standard HTTP ingress | Terraform only |
| SQS | inventory | Pub/Sub | Service Bus | **Medium** — semantics differ (ack-deadline caps, ordering, DLQ) | `clients.py`, `local_poller.py` |
| Lambda | inventory | Cloud Run / GKE + KEDA | Container Apps / AKS + KEDA | **Medium** — invoker seam already isolates it | `lambda_*.py` (delete to migrate) |
| API Gateway | inventory | API Gateway / Ingress | APIM / Ingress | **High** — Mangum comes off, uvicorn stays | `lambda_api.py` (3 lines) |
| DynamoDB | inventory | Firestore / Bigtable | Cosmos DB | **Low** — no equivalent; data-model + delta-sync work | `dynamo.py` behind `repository.py` |
| SSM Parameter Store | orders→inventory | Secret Manager / runtime config | App Config / Key Vault | **Medium** — a cross-team contract, not state | `clients.py::resolve_inventory_url` |

The **Where it's isolated** column is the actual deliverable: for every coupling,
the AWS-specific code is confined to one named file. That is what turns "migrate
off AWS" from a project into a checklist.

## How the paved road works

The platform team owns shared CI (reusable GitHub Actions workflows, consumed
version-pinned by each team) and this integrated demo — **not** the teams'
repos. Autonomy has a real cost (you can't read one repo to see the whole
estate), paid back by three structural guarantees rather than a governance
apparatus. See [docs/adr](docs/adr) across the repos for the reasoning, and this
repo's ADRs for the platform-level decisions.
