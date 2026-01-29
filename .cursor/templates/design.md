# Design: [Feature Name]

## Architecture
[How this feature fits into the system.]

```mermaid
flowchart TD
    subgraph Existing["Existing System"]
        A[Component A]
        B[Component B]
    end
    subgraph New["New Feature"]
        C[New Component]
    end
    A --> C
    C --> B
```

## Data Model / APIs
[New or changed tables, DTOs, API contracts. Rationale for key decisions.]

## Data Flow (if applicable)
```mermaid
flowchart LR
    Input["User Input"] --> Validate --> Process --> Store --> Response
```

## Risks and Mitigations
| Risk | Likelihood | Mitigation |
|------|------------|------------|
| [Risk 1] | High/Med/Low | [How we'll handle it] |
