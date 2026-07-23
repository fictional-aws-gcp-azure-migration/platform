# Architecture

An AWS-native "before" system, designed so a later migration off AWS is a
data-migration problem plus a redeploy — not a rewrite.

> **Ephemeral compute is portable; persistent state is not.** Draw the seam
> there, and the migration cost concentrates where it actually lives: the
> stateful stores.

## System

```mermaid
flowchart LR
    client([Client])

    subgraph orders["orders-service &mdash; team A &bull; CONTAINERIZED"]
        direction TB
        alb[ALB]
        api["orders-api<br/>ECS Fargate &bull; FastAPI"]
        pg[("RDS PostgreSQL<br/>orders, order_lines")]
        alb --> api
        api -- "writes order" --> pg
    end

    subgraph inventory["inventory-service &mdash; team B &bull; SERVERLESS &bull; no VPC"]
        direction TB
        agw["API Gateway HTTP API<br/>IAM-authorized"]
        invapi["inventory-api<br/>Lambda &bull; Mangum(FastAPI)"]
        q["SQS<br/>order-placed (+DLQ)"]
        worker["inventory-worker<br/>Lambda &bull; SQS source"]
        ddb[("DynamoDB<br/>stock + events, GSI1")]
        agw --> invapi
        invapi -- "read stock" --> ddb
        q --> worker
        worker -- "decrement + event" --> ddb
    end

    ssm[["SSM Parameter Store<br/>/platform/inventory/api-url"]]

    client -->|HTTP| alb
    api -. "SigV4-signed<br/>GET /stock/{sku}" .-> agw
    api ==>|"publish OrderPlaced"| q
    invapi -. "publishes URL" .-> ssm
    api -. "reads URL (contract,<br/>not shared state)" .-> ssm

    classDef sync stroke-dasharray:4 3
```

**Two paths between the teams, one contract seam:**

- **Sync** (dashed): `orders-api` reads stock from inventory's API Gateway before
  accepting an order. The route is IAM-authorized, so the call is SigV4-signed
  with the task role — no API keys, no static secrets.
- **Async** (bold): `orders-api` publishes `OrderPlaced` to SQS; the worker
  decrements stock with a conditional write and logs the movement.
- **Contract, not shared state**: inventory publishes its URL to SSM; orders
  reads it. Neither team touches the other's Terraform state, so either can
  deploy first and they can live in separate accounts unchanged.

## Why the two services look different

The asymmetry is deliberate — a realistic portfolio, not a symmetric diagram.

| | orders-service | inventory-service |
|---|---|---|
| Pattern | **Containerized** | **Serverless** |
| Compute | ECS Fargate + ALB | 2 Lambdas + API Gateway |
| Store | RDS PostgreSQL | DynamoDB |
| Network | VPC (public + private, **no NAT**) | **No VPC** |
| Migration seam | clean (managed logical replication) | hard (no equivalent service) |

## The migration seam (what Phase 2 exploits)

Business logic never knows what invoked it or what stores it. The AWS coupling
is confined to named, deletable files:

```mermaid
flowchart TB
    subgraph logic["Portable core (no boto3, no FastAPI-Lambda coupling)"]
        core["core.handle_order_placed()"]
        repoif["StockRepository (interface)"]
    end
    subgraph aws["AWS-specific edge (the entire migration surface)"]
        mangum["lambda_api.py &mdash; Mangum(app)"]
        lh["lambda_worker.py &mdash; SQS unwrap"]
        dynamo["dynamo.py &mdash; DynamoDB impl"]
    end
    subgraph k8s["Phase 2 edge (swap, don't rewrite)"]
        uvicorn["uvicorn in a container"]
        keda["KEDA-scaled poller"]
        newdb["Firestore / Cosmos impl"]
    end
    mangum -.->|delete| uvicorn
    lh -.->|replace| keda
    dynamo -.->|swap| newdb
    core --- repoif
```

The full per-dependency portability rating is in the
[platform README](../README.md#aws-coupling-inventory--the-bridge-to-phase-2).

## The honest finding

Migration difficulty tracks the store, not the compute:

- **Postgres → Cloud SQL / Azure Flexible Server: easy.** Managed logical
  replication; the schema is already replication-ready (every table has a PK;
  `updated_at` is trigger-maintained).
- **DynamoDB → anything: hard.** No equivalent managed service, and no
  first-party near-zero-downtime tooling on either cloud. The repository
  interface is what turns that from a rewrite into a swappable implementation.

Naming that asymmetry up front — and designing the source so the easy half stays
easy and the hard half is contained — is the actual demonstration of migration
experience.
