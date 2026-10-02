# Domiary Roadmap

This roadmap describes the current development direction. It is intentionally product-oriented and may change as the first real users provide feedback.

This file is the single source of truth for phase order. [PRD.md](PRD.md) §43 and [ARCHITECTURE.md](ARCHITECTURE.md) §38 follow the same phases.

## Phase 0 — Product foundation

**Goal:** turn the PRD into an implementable product architecture.

- [x] Product concept
- [x] Product name and visual identity
- [x] Initial PRD
- [x] Open-source repository
- [x] Architecture document (initial draft)
- [ ] 1C metadata/domain model
- [ ] Navigation and UX map
- [x] Target platform version: 1C:Enterprise 8.5 mobile platform
- [x] Target OS decision: Android-first (iOS after v1)
- [ ] MVP execution plan and roles — see [MVP_PLAN.md](MVP_PLAN.md)
- [ ] Test strategy
- [ ] Build/release strategy

## Phase 1 — Home & assets

**Goal:** make Domiary useful as a local home inventory and history.

- [ ] Properties
- [ ] Rooms and storage locations
- [ ] Assets
- [ ] Categories
- [ ] Photos
- [ ] Purchase information
- [ ] Warranties
- [ ] Documents
- [ ] Asset timeline
- [ ] Basic search

**Exit criterion:** a user can create a home, add assets, attach basic information and retrieve it quickly.

## Phase 2 — Maintenance & reminders

**Goal:** move from passive inventory to active household management.

- [ ] One-time tasks
- [ ] Recurring tasks
- [ ] Maintenance rules
- [ ] Service events
- [ ] Automatic next-service calculation
- [ ] Local notifications
- [ ] Warranty expiration reminders
- [ ] Attention dashboard

**Exit criterion:** Domiary reliably tells the user what needs attention and records completed work.

## Phase 3 — Home operations

**Goal:** cover recurring household responsibilities.

- [ ] Utility meters
- [ ] Meter readings history
- [ ] Recurring household obligations
- [ ] Payment reminders
- [ ] Global timeline
- [ ] Dashboard refinements

## Phase 4 — Simple personal assets

**Goal:** add lightweight financial context without becoming a finance/accounting product.

- [ ] Manual accounts
- [ ] Savings goals
- [ ] Debts
- [ ] Planned major purchases
- [ ] Links between obligations, maintenance costs and simple finances (project links come with post-v1 projects)

### Explicit exclusions

- bank synchronization;
- statement import;
- automatic financial categorization;
- investment features;
- accounting-grade bookkeeping.

## Phase 5 — Data safety & public v1

**Goal:** make the application safe enough for real long-term use.

- [ ] Backup
- [ ] Restore
- [ ] Versioned backup format
- [ ] Export
- [ ] Data migrations
- [ ] Search performance hardening
- [ ] Regression tests for critical flows
- [ ] Upgrade tests
- [ ] Release packaging
- [ ] User documentation

**Milestone:** **Domiary v1.0**

## Post-v1 candidates

These features are deliberately postponed until real usage validates the product core.

- consumables;
- contractors and service contacts;
- home projects / renovations;
- QR codes for assets and storage locations;
- maintenance templates;
- richer reports;
- multiple-property UX improvements (multiple properties themselves are supported in v1);
- desktop client;
- optional family sharing;
- optional synchronization.

## AI track

AI development starts only after the core application is stable.

### AI 1 — Natural-language actions

Convert user intent into structured proposed changes with explicit confirmation.

### AI 2 — Ask My Home

Questions over structured Domiary data using controlled application tools.

### AI 3 — Document Q&A

RAG over manuals and documents attached to assets, with source-aware answers.

### AI 4 — Suggestions

Context-aware maintenance and household suggestions. AI may recommend actions but must never silently alter user data.

## Engineering track

Throughout development:

- keep business logic testable;
- maintain explicit module/domain boundaries;
- prefer simple architecture over speculative abstractions;
- version data migrations;
- automate critical regression checks;
- document architectural decisions;
- keep the application functional without cloud or AI dependencies.

## Product guardrail

Every proposed core feature should answer at least one question:

1. What do I own?
2. What happened?
3. What do I need to do?
4. What obligations or resources do I have?

If it does not, it requires separate justification before entering the core product.
