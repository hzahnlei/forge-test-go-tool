# System Context

<!--
This document describes the technical environment of this system.
For the AI coding assistant: use the diagrams below to understand which
dependencies and integrations exist. Never introduce dependencies that
are not listed here without explicit discussion.
-->

## C4 Context Diagram

Shows the system and its users / external systems at the highest level.

```plantuml
@startuml
!include <C4/Context>

LAYOUT_WITH_LEGEND()

title System Context: <System Name>

Person(primaryUser, "TODO: Primary User", "TODO: Role and goal")
' Person(secondaryUser, "TODO: Secondary User", "TODO: Role and goal")

System(thisSystem, "TODO: System Name", "TODO: One sentence what it does")

System_Ext(extSystem1, "TODO: External System", "TODO: What it does and why we need it")
' System_Ext(extSystem2, "TODO: External System", "TODO: What it does")

Rel(primaryUser, thisSystem, "TODO: What the user does", "TODO: Protocol, e.g. HTTPS")
Rel(thisSystem, extSystem1, "TODO: Why", "TODO: Protocol, e.g. REST/Kafka")
@enduml
```

## C4 Container Diagram

Shows the internal building blocks (processes, databases, queues) of this system.

```plantuml
@startuml
!include <C4/Container>

LAYOUT_WITH_LEGEND()

title Container Diagram: <System Name>

Person(user, "TODO: User")

System_Boundary(system, "TODO: System Name") {
    Container(api, "TODO: API Layer", "TODO: Technology, e.g. Spring Boot", "TODO: Responsibility")
    Container(domain, "TODO: Domain Layer", "TODO: Technology", "TODO: Responsibility")
    ContainerDb(db, "TODO: Database", "TODO: Technology, e.g. PostgreSQL 16", "TODO: What is stored")
    ' ContainerQueue(queue, "TODO: Queue", "TODO: Technology, e.g. Kafka", "TODO: Topics")
}

System_Ext(extSystem, "TODO: External System", "TODO: Description")

Rel(user, api, "TODO: Action", "HTTPS/REST")
Rel(api, domain, "TODO: Delegates to")
Rel(domain, db, "TODO: Reads/Writes", "JDBC")
' Rel(domain, queue, "TODO: Publishes", "Kafka Producer")
Rel(domain, extSystem, "TODO: Calls", "TODO: Protocol")
@enduml
```

## Provided APIs

See [`docs/design/APIs/provided/`](APIs/provided/README.md) for machine-readable specifications.

| Spec File                | Protocol | Description              |
| ------------------------ | -------- | ------------------------ |
| `api/provided/TODO.yaml` | REST     | TODO: What this API does |

## Consumed APIs

See [`docs/design/APIs/consumed/`](APIs/consumed/README.md) for machine-readable specifications.

| External System | Protocol | Spec Location            | Notes |
| --------------- | -------- | ------------------------ | ----- |
| TODO            | REST     | `api/consumed/TODO.yaml` | TODO  |

## Infrastructure

| Concern           | Decision                                       |
| ----------------- | ---------------------------------------------- |
| Deployment target | TODO: e.g., Kubernetes, bare metal, AWS Lambda |
| Container runtime | TODO: e.g., Docker                             |
| CI/CD             | TODO: e.g., GitHub Actions, GitLab CI          |
