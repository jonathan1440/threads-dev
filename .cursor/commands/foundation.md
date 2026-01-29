# Foundation Mode: Extended Planning

Foundation artifacts are produced and approved in conversation, then persisted under `.cursor/foundation/` so they travel with the repo. Create `.cursor/foundation/` if it does not exist.

## 1. Vision Document

Before any technical planning, create `.cursor/foundation/vision.md`:
````markdown
# Project Vision: [Name]

## Mission
[One sentence: what does this system do and for whom?]

## Success Metrics
[How will we measure if this project succeeded?]

## Constraints
- Timeline: [deadline if any]
- Team: [who's working on this]
- Technical: [must use X, can't use Y]
- Budget: [if relevant]

## Non-Goals
[What are we explicitly NOT trying to do?]
````

Get approval, then save to `.cursor/foundation/vision.md`.

## 2. Technology Decisions

Document major choices with rationale. Save to `.cursor/foundation/decisions.md`:
````
DECISION RECORD

┌─────────────┬─────────────────┬──────────────────────────────┐
│ Category    │ Decision        │ Rationale                    │
├─────────────┼─────────────────┼──────────────────────────────┤
│ Language    │ [choice]        │ [why]                        │
│ Framework   │ [choice]        │ [why]                        │
│ Database    │ [choice]        │ [why]                        │
│ Hosting     │ [choice]        │ [why]                        │
│ Auth        │ [choice]        │ [why]                        │
└─────────────┴─────────────────┴──────────────────────────────┘
````

## 3. System Architecture (and Data Model, API, Vertical Slice)

Create or append to `.cursor/foundation/architecture.md`. Start with the high-level system diagram:
````mermaid
flowchart TB
    subgraph Client["Client Layer"]
        Web["Web App"]
        Mobile["Mobile App"]
    end
    
    subgraph API["API Layer"]
        Gateway["API Gateway"]
        Auth["Auth Service"]
        Core["Core Service"]
    end
    
    subgraph Data["Data Layer"]
        DB[(Database)]
        Cache[(Cache)]
        Queue["Message Queue"]
    end
    
    Web --> Gateway
    Mobile --> Gateway
    Gateway --> Auth
    Gateway --> Core
    Core --> DB
    Core --> Cache
    Core --> Queue
````

Add the following to `.cursor/foundation/architecture.md`:

## 4. Data Model

Entity relationship diagram:
````mermaid
erDiagram
    USER ||--o{ ORDER : places
    USER {
        uuid id PK
        string email
        string name
        timestamp created_at
    }
    ORDER ||--|{ LINE_ITEM : contains
    ORDER {
        uuid id PK
        uuid user_id FK
        decimal total
        string status
    }
    LINE_ITEM {
        uuid id PK
        uuid order_id FK
        uuid product_id FK
        int quantity
    }
````

## 5. API Design

For each major endpoint group:
````
ENDPOINT GROUP: [Name]

┌──────────┬─────────────────────┬─────────────────────────────┐
│ Method   │ Path                │ Purpose                     │
├──────────┼─────────────────────┼─────────────────────────────┤
│ GET      │ /api/v1/resources   │ List resources              │
│ POST     │ /api/v1/resources   │ Create resource             │
│ GET      │ /api/v1/resources/:id│ Get single resource        │
│ PUT      │ /api/v1/resources/:id│ Update resource            │
│ DELETE   │ /api/v1/resources/:id│ Delete resource            │
└──────────┴─────────────────────┴─────────────────────────────┘
````

## 6. Vertical Slice Selection

Before broad implementation, identify one end-to-end slice:
````mermaid
flowchart LR
    subgraph Slice["Vertical Slice: [Name]"]
        UI["UI Component"]
        API["API Endpoint"]
        Service["Service Logic"]
        Data["Data Model"]
    end
    
    UI --> API
    API --> Service
    Service --> Data
    
    style Slice fill:#e8f5e9
````

Why this slice:
- [Exercises the core architecture]
- [Touches all layers]
- [Representative of future features]

## 7. Initial CLAUDE.md

Create project-specific rules before any implementation:
````markdown
# [Project Name]

## What This Is
[One paragraph description]

## Tech Stack
- Language: [X]
- Framework: [X]
- Database: [X]

## Patterns We Use
- [Pattern 1 with brief explanation]
- [Pattern 2 with brief explanation]

## Hard Rules
- [Non-negotiable 1]
- [Non-negotiable 2]

## Mistakes Not To Repeat
(Empty - will populate as we learn)

## Current Phase
Foundation: Building vertical slice
````

After each subsection (System Architecture, Data Model, API Design, Vertical Slice), add the content to `.cursor/foundation/architecture.md` and get approval before moving on. Optionally reference `.cursor/foundation/` from CLAUDE.md (e.g. "See .cursor/foundation/ for vision, decisions, and architecture").

Only after all of the above is approved, proceed to normal Feature mode planning for the vertical slice (use `/plan` with the vertical slice as the first feature).