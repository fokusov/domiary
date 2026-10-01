# Domiary Architecture

**Status:** Draft  
**Version:** 0.1  
**Product:** Domiary  
**Platform:** 1C:Enterprise 8.5 Mobile Platform  
**Architecture style:** modular monolith, offline-first, local-first  
**Primary client:** mobile  
**Future clients:** desktop, optional synchronized clients

---

## 1. Purpose

This document describes the initial technical architecture of **Domiary**.

The architecture is derived from the product requirements in [PRD.md](PRD.md) and is intentionally optimized for the first public offline-first release.

The main goals are:

- keep the product simple for users;
- keep the internal model explicit and maintainable;
- use native strengths of the 1C platform;
- avoid premature distributed architecture;
- make critical business logic testable;
- preserve a clean path toward future AI features, desktop support and optional synchronization.

The main architectural guardrail is the same as the product guardrail:

> **Do not build a household ERP.**

Domiary may internally use catalogs, documents and registers, but those implementation details must not leak into the user experience.

---

## 2. Architectural Principles

### 2.1. Modular monolith first

The initial application is a single deployable 1C application with clearly separated functional modules.

No microservices are required for v1.

### 2.2. Offline-first

The application must remain fully useful without network access.

Core operations must use only local data:

- asset management;
- maintenance;
- tasks;
- reminders;
- meter readings;
- household obligations;
- savings and debts;
- search;
- timeline;
- backup and restore.

### 2.3. Local-first data ownership

The user owns the local data.

No mandatory account, cloud or remote API is required for v1.

### 2.4. Thin UI, explicit application logic

Forms should orchestrate user interaction but should not contain complex domain logic.

Business rules must be placed in common modules or domain services that can be tested independently.

### 2.5. Events over hidden side effects

Important changes should produce explicit domain events or history entries.

Examples:

- asset purchased;
- maintenance completed;
- meter reading recorded;
- obligation paid;
- savings contribution added.

### 2.6. Append history, derive state where practical

Domiary is a long-lived personal system.

Historical events should be preserved rather than overwritten where the history is useful to the user.

### 2.7. Confirmation for destructive or AI-driven operations

Operations that can lose data or alter user state significantly must require explicit confirmation.

Future AI features must follow the same rule.

---

## 3. High-Level Architecture

```text
┌─────────────────────────────────────────────┐
│                 Mobile UI                   │
│  Dashboard / Assets / Tasks / Finance / ... │
└──────────────────────┬──────────────────────┘
                       │
┌──────────────────────▼──────────────────────┐
│            Application Services             │
│                                             │
│ AssetService        MaintenanceService      │
│ TaskService         MeterService            │
│ ObligationService   FinanceService          │
│ TimelineService     SearchService           │
│ BackupService       NotificationService     │
└──────────────────────┬──────────────────────┘
                       │
┌──────────────────────▼──────────────────────┐
│               Domain Model                  │
│                                             │
│ Properties / Locations / Assets / Events    │
│ Tasks / Maintenance / Meters / Documents    │
│ Accounts / Savings / Debts / Obligations    │
└──────────────────────┬──────────────────────┘
                       │
┌──────────────────────▼──────────────────────┐
│          1C Metadata / Local Storage        │
│                                             │
│ Catalogs / Documents / Registers / Files    │
└─────────────────────────────────────────────┘
```

Future optional components:

```text
                  ┌────────────────┐
                  │ AI Gateway     │
                  │ / Tool API     │
                  └──────┬─────────┘
                         │
                 controlled calls
                         │
┌────────────────────────▼─────────────────────┐
│               Domiary Core                  │
└──────────────────────────────────────────────┘
```

AI is not part of the v1 runtime dependency graph.

---

## 4. Functional Modules

The internal solution should be divided into the following functional subsystems.

### 4.1. Core

Responsibilities:

- application settings;
- identifiers;
- common value objects;
- common enums;
- date/time helpers;
- validation;
- migration support;
- import/export infrastructure.

### 4.2. Home

Responsibilities:

- properties;
- rooms;
- storage locations;
- location hierarchy.

### 4.3. Assets

Responsibilities:

- assets;
- categories;
- manufacturers;
- purchase information;
- status;
- ownership;
- asset location;
- asset history.

### 4.4. Documents

Responsibilities:

- attachments;
- warranty documents;
- manuals;
- contracts;
- photos;
- metadata;
- file lifecycle.

### 4.5. Maintenance

Responsibilities:

- maintenance rules;
- recurring maintenance;
- service history;
- next-service calculation;
- consumables in later versions.

### 4.6. Tasks

Responsibilities:

- one-time tasks;
- recurring tasks;
- task state;
- due dates;
- reminders;
- completion.

### 4.7. Meters

Responsibilities:

- utility meters;
- tariffs if enabled;
- meter readings;
- consumption calculation;
- reminder schedule.

### 4.8. Obligations

Responsibilities:

- recurring household payments;
- due dates;
- payment state;
- reminder generation.

### 4.9. Simple Finance

Responsibilities:

- manual accounts;
- savings goals;
- savings contributions;
- debts;
- debt repayments;
- planned purchases.

This module must remain intentionally limited.

### 4.10. Timeline

Responsibilities:

- unified user-visible history;
- filtering by object, date and event type;
- aggregation of domain events.

### 4.11. Search

Responsibilities:

- global search;
- searchable representations;
- lightweight local indexing if required.

### 4.12. Notifications

Responsibilities:

- local notifications;
- notification scheduling;
- rescheduling after task/date changes;
- notification cleanup.

### 4.13. Backup & Migration

Responsibilities:

- backup creation;
- restore;
- backup format versioning;
- schema/data migrations;
- validation before restore.

### 4.14. AI Integration

Future module only.

Responsibilities:

- application tools;
- explicit user confirmation;
- provider abstraction;
- request logging if enabled;
- privacy boundary;
- RAG integration.

---

## 5. Metadata Design Rules

The following rules should guide 1C metadata selection.

### 5.1. Catalog

Use a catalog for relatively stable entities with identity.

Examples:

- properties;
- locations;
- assets;
- categories;
- manufacturers;
- contacts;
- accounts;
- savings goals.

### 5.2. Document

Use a document for a meaningful business/user event that:

- occurs at a point in time;
- changes state;
- should remain in history;
- may produce register movements.

Examples:

- purchase;
- maintenance completion;
- meter reading;
- payment;
- savings contribution;
- debt repayment.

### 5.3. Information register

Use an information register for state or relationships that are not themselves user-level events.

Examples:

- current asset location;
- asset status history;
- maintenance schedule;
- current warranty data;
- user settings;
- migration version.

### 5.4. Accumulation register

Use only where aggregation materially simplifies the model.

Potential uses:

- account balances;
- savings balances;
- debt balances;
- expenses by asset/project.

Do not create accumulation registers simply because the platform supports them.

### 5.5. Enumeration

Use enumerations for small stable sets.

Examples:

- asset status;
- task status;
- obligation status;
- document type;
- debt direction.

### 5.6. Constant

Use constants sparingly for truly global single values.

Prefer settings records where future extensibility is likely.

---

## 6. Proposed Metadata Model

Names below are conceptual and may be adapted to repository naming conventions.

---

### 6.1. Catalog: Properties

Represents top-level managed locations.

Examples:

- House;
- Apartment;
- Cottage;
- Garage;
- Workshop.

Suggested fields:

- Name;
- Type;
- AddressText;
- Notes;
- Archived.

---

### 6.2. Catalog: Locations

Hierarchical catalog.

Examples:

- Kitchen;
- Boiler room;
- Shelf;
- Box.

Suggested fields:

- Parent;
- Property;
- Name;
- LocationType;
- Notes;
- Archived.

Rule:

A location always belongs to one property.

---

### 6.3. Catalog: AssetCategories

Hierarchical catalog.

Examples:

- Home appliances;
- Tools;
- Electronics;
- Furniture;
- Equipment.

Fields:

- Parent;
- Name;
- DefaultMaintenanceTemplate optional later.

---

### 6.4. Catalog: Assets

Central domain entity.

Suggested fields:

- Name;
- Category;
- Manufacturer;
- Model;
- SerialNumber;
- Property;
- CurrentLocation;
- PurchaseDate;
- PurchasePrice;
- Currency;
- Status;
- Notes;
- MainPhotoReference.

Optional fields:

- ProductionDate;
- Seller;
- EstimatedCurrentValue;
- ManufacturerURL.

Important rule:

The asset card should not attempt to contain all history directly. Historical facts belong to events/documents/registers.

Source of truth for fields that also have history:

| Asset field | Source of truth | Asset field role |
|---|---|---|
| CurrentLocation, Property | `AssetLocationHistory` register (written by `AssetMovement`) | denormalized cache of the latest record |
| Status | `AssetStatusHistory` register | denormalized cache of the latest record |
| PurchaseDate, PurchasePrice, Currency | `AssetPurchase` document | denormalized cache filled on posting |

Cache fields are written only by the `DomiaryAssets` service, in the same transaction as the source record. Forms never edit them directly.

---

### 6.5. Catalog: Manufacturers

Optional normalization layer.

Fields:

- Name;
- Website;
- Notes.

For v1 this catalog may be omitted and manufacturer can be stored as plain text if that reduces UI friction.

Decision should prefer UX simplicity over normalization.

---

### 6.6. Catalog: Accounts

Represents manually maintained financial resources.

Examples:

- Cash;
- Main card;
- Reserve.

Fields:

- Name;
- Currency;
- CurrentBalance;
- Notes;
- Archived.

No bank integration is assumed.

In v1 `CurrentBalance` is edited manually by the user, as the PRD requires. Payments and contributions may reference an account for information, but they do not change its balance. Event-derived balances are a post-v1 option (see §8.5).

---

### 6.7. Catalog: SavingsGoals

Fields:

- Name;
- TargetAmount;
- Currency;
- TargetDate;
- PlannedContribution;
- Notes;
- Status.

Actual balance should be derived from contribution events/registers.

---

### 6.8. Catalog: Contacts

Post-v1 candidate.

Represents:

- contractor;
- specialist;
- service center.

Fields:

- Name;
- Phone;
- Messenger;
- Specialization;
- Notes.

In v1 contractor information is stored as free text on maintenance rules and events (`ContractorText`). When this catalog is introduced, a migration can link existing text values to contacts.

---

### 6.9. Catalog: MaintenanceRules

Recurring maintenance definition for an asset.

Fields:

- Asset;
- MaintenanceType;
- RecurrenceRule (see §10);
- ContractorText;
- ConsumableText;
- EstimatedCost;
- Notes;
- Active.

Current schedule state (last and next date) lives in the `MaintenanceSchedule` register (§8.4).

`ConsumableText` is free text in v1. A link to a consumables catalog is post-v1.

---

### 6.10. Catalog: Meters

Fields:

- Name;
- Property;
- Unit;
- TariffCount;
- ReadingRecurrenceRule (see §10);
- Notes;
- Archived.

---

### 6.11. Catalog: Obligations

Recurring household payment definition.

Fields:

- Name;
- Category;
- Amount;
- Currency;
- RecurrenceRule (see §10);
- Property optional;
- Notes;
- Archived.

---

### 6.12. Catalog: Debts

Fields:

- Counterparty (text);
- Direction (owed to me / I owe);
- InitialAmount;
- Currency;
- Date;
- DueDate;
- Notes;
- Status.

Remaining amount is derived from `DebtOperation` documents (§7.7, §8.7).

---

### 6.13. Catalog: PlannedPurchases

Fields:

- Name;
- EstimatedCost;
- Currency;
- Priority;
- TargetDate;
- SavingsGoal optional;
- Notes;
- Status.

---

### 6.14. Catalog: Attachments

Metadata for files linked to domain objects. See §12 for storage strategy.

Fields:

- Title;
- DocumentType;
- RelatedObject;
- CreatedAt;
- ValidUntil optional;
- ReminderAt optional;
- Notes;
- FileReference;
- Checksum optional.

The user-facing term is "document". The catalog name differs to avoid confusion with 1C document metadata objects.

---

## 7. Proposed Documents

### 7.1. AssetPurchase

Purpose:

Capture a meaningful acquisition event.

Fields:

- Date;
- Asset;
- Amount;
- Currency;
- Seller;
- Notes.

The initial implementation may allow asset creation and purchase data entry in one UX flow while still keeping history explicit internally.

---

### 7.2. AssetMovement

Purpose:

Move an asset between locations.

Fields:

- Date;
- Asset;
- FromLocation;
- ToLocation;
- Notes.

For simple v1 UX this may be generated automatically when the user changes location.

---

### 7.3. MaintenanceEvent

Purpose:

Record completed service or repair.

Fields:

- Date;
- Asset;
- MaintenanceType;
- MaintenanceRule;
- Cost;
- ContractorText (free text in v1, see §6.8);
- Notes.

Optional attachments:

- photo;
- act;
- receipt.

Posting behavior:

- append history;
- update last maintenance date;
- calculate next maintenance date;
- optionally record expense.

---

### 7.4. MeterReading

Fields:

- Date;
- Meter;
- one or more readings;
- Notes.

Posting behavior:

- store reading;
- calculate consumption;
- update latest reading.

---

### 7.5. ObligationPayment

Fields:

- Date;
- Obligation;
- Amount;
- Account optional;
- Notes.

Posting behavior:

- mark current period as paid;
- append timeline event.

The optional `Account` is informational in v1 and does not change the account balance (see §6.6).

---

### 7.6. SavingsContribution

Fields:

- Date;
- SavingsGoal;
- Amount;
- Account optional;
- Notes.

---

### 7.7. DebtOperation

Represents:

- debt creation;
- partial repayment;
- full repayment;
- correction.

Fields:

- Date;
- Debt;
- OperationType;
- Amount;
- Notes.

---

## 8. Proposed Registers

### 8.1. AssetLocationHistory

Type: information register, periodic.

Dimensions:

- Asset.

Resources:

- Property;
- Location.

Purpose:

Keep current and historical location.

---

### 8.2. AssetStatusHistory

Type: information register, periodic.

Dimensions:

- Asset.

Resource:

- Status.

---

### 8.3. WarrantyState

Type: information register.

Dimensions:

- Asset.

Resources:

- StartDate;
- EndDate;
- Seller;
- ServiceCenter;
- DocumentReference.

A simpler v1 alternative is to store warranty fields directly on Asset.

Use a register if warranty history or multiple warranties become necessary.

---

### 8.4. MaintenanceSchedule

Type: information register.

Dimensions:

- Asset;
- MaintenanceRule.

Resources:

- LastPerformedAt;
- NextDueAt;
- Period;
- ReminderLeadTime;
- Active.

---

### 8.5. AccountBalances

Potential accumulation register.

Dimensions:

- Account;
- Currency.

Resource:

- Amount.

Only needed if the finance module starts recording actual operations.

v1 uses manually edited balances (§6.6), so this register is postponed until after v1.

---

### 8.6. SavingsBalances

Potential accumulation register.

Dimension:

- SavingsGoal.

Resource:

- Amount.

Generated from SavingsContribution documents.

---

### 8.7. DebtBalances

Potential accumulation register.

Dimension:

- Debt.

Resource:

- Amount.

Generated from DebtOperation documents.

---

### 8.8. ApplicationState

Information register.

Purpose:

- schema/data version;
- migration markers;
- installation ID;
- optional feature flags.

No sensitive device identity should be stored unless required.

---

## 9. Tasks Model

Tasks should be modeled as a first-class domain object.

Recommended approach:

Catalog or dedicated object for task definition + history/event for completion.

Conceptual fields:

- Title;
- RelatedObject;
- DueDate;
- Priority;
- RecurrenceRule;
- Status;
- ReminderAt;
- Notes.

RelatedObject should support controlled references to:

- asset;
- property;
- location;
- obligation;
- savings goal;
- future project.

Avoid unrestricted AnyRef unless required.

Prefer explicit typed references where practical to reduce accidental coupling.

---

## 10. Recurrence Model

Recurring maintenance and tasks should use a small explicit recurrence model.

v1 should support:

- every N days;
- every N weeks;
- every N months;
- every N years.

Avoid cron-like complexity in user-facing settings.

Future extensions may add:

- seasonal rules;
- fixed month/day;
- usage-based intervals.

Recurrence calculation must be placed in a shared testable domain module.

---

## 11. Notifications

Local notifications should be treated as a projection of application state.

The database is the source of truth.

If notifications are lost or OS permissions change, the application must be able to rebuild the notification schedule.

Recommended flow:

Notification sources:

- tasks;
- maintenance schedule;
- obligations;
- meter reading schedule;
- warranty end dates;
- document validity dates and document reminders.

```text
Source object changed
               ↓
NotificationService
               ↓
Recalculate required local notification
               ↓
Schedule / cancel OS notification
```

Rules:

- use stable internal identifiers;
- never rely on notification existence as business state;
- rebuild notifications after restore;
- rebuild after migration if needed.

---

## 12. Documents and File Storage

File storage requires special care on mobile.

The architecture should distinguish:

### 12.1. Metadata

Stored in 1C data:

- type;
- title;
- related object;
- creation date;
- expiration date;
- notes;
- checksum if used.

### 12.2. Binary payload

Possible strategies:

1. store binary data directly in local database;
2. store files in application filesystem and metadata in DB;
3. hybrid approach based on file size/type.

The final choice must be validated against:

- mobile platform capabilities;
- backup behavior;
- expected database size;
- restore reliability;
- export requirements.

For v1, simplicity and reliable backup/restore are more important than optimizing for very large attachment collections.

---

## 13. Timeline Architecture

Timeline should be a derived read model, not a separate manually maintained source of truth.

Possible sources:

- purchase documents;
- asset movements;
- maintenance events;
- task completions;
- meter readings;
- payments;
- savings contributions;
- debt operations.

Two implementation strategies:

### Option A — Query-time aggregation

Advantages:

- simple;
- no duplicated timeline state.

Disadvantages:

- may become expensive or complex.

### Option B — Timeline register

Each important operation writes a normalized timeline entry.

Advantages:

- fast global timeline;
- simple filtering;
- stable UX model.

Disadvantages:

- requires consistency rules.

**Recommended direction for Domiary:** a normalized timeline register populated by application services.

Timeline entry:

- DateTime;
- EventType;
- RelatedObject;
- Title;
- Summary;
- SourceReference;
- Amount optional;
- Currency optional.

All writes should happen through shared service code, not ad hoc form logic.

---

## 14. Dashboard Architecture

Dashboard is another read model.

It should not own business data.

Dashboard data is calculated from:

- overdue tasks;
- upcoming maintenance;
- expiring warranties;
- expiring documents;
- upcoming meter readings;
- unpaid obligations;
- savings progress;
- debt state.

The dashboard service should return a presentation-friendly structure.

Avoid embedding complex queries directly in the dashboard form.

---

## 15. Search Architecture

v1 search requirements are moderate.

Expected data volume:

- hundreds or low thousands of assets;
- limited tasks/documents;
- household-scale history.

Initial approach:

- normalized searchable text fields;
- indexed standard attributes where possible;
- direct query over catalogs/registers/documents.

If performance becomes insufficient, add a local SearchIndex information register.

Potential index fields:

- EntityType;
- EntityReference;
- DisplayName;
- SearchText;
- UpdatedAt.

Do not introduce external search infrastructure for v1.

---

## 16. Finance Architecture Boundary

The finance module is deliberately not a personal accounting system.

Allowed:

- manual account balances;
- savings goals;
- savings contributions;
- debts;
- debt repayments;
- planned purchases;
- optional costs attached to maintenance/events.

Not allowed in core:

- bank imports;
- transaction categorization;
- double-entry accounting;
- investment positions;
- tax accounting;
- budgeting engine;
- financial advice.

Architectural rule:

Finance entities may enrich household events, but must not become the center of the domain model.

---

## 17. Backup Architecture

Backup must be considered a core product capability, not a late utility.

### Requirements

- user-triggered backup;
- versioned format;
- integrity validation;
- restore preview/confirmation;
- restore migration if source version is older;
- post-restore notification rebuild.

Recommended backup manifest:

```text
backup/
 ├─ manifest.json
 ├─ database
 ├─ files/
 └─ metadata/
```

Exact implementation depends on 1C mobile platform constraints.

Manifest should contain:

- backup format version;
- application version;
- schema/data version;
- created timestamp;
- attachment count;
- checksum information if practical.

---

## 18. Migration Architecture

Every public release that changes persisted structure must define a migration path.

Migration principles:

- migrations are explicit;
- migrations are versioned;
- migrations are idempotent where practical;
- backup before destructive migration;
- migration failure must not silently destroy data.

Suggested state:

```text
CurrentDataVersion = 3
TargetDataVersion  = 5

Run migration 3 -> 4
Run migration 4 -> 5
Persist version = 5
```

Migration logic must not be hidden in UI forms.

---

## 19. Import / Export

Export is part of user data ownership.

v1 candidate formats:

- CSV for tabular exports;
- JSON for structured full export.

The export model should use stable semantic field names independent of UI captions where possible.

Future import should validate:

- format version;
- required fields;
- reference consistency;
- duplicate policy.

---

## 20. Security and Privacy

v1 threat model is primarily local-device privacy and accidental data loss.

Principles:

- no mandatory telemetry;
- no hidden external requests;
- no remote processing without explicit action;
- clear privacy boundary for future AI;
- user-controlled backup/export.

Potential future options:

- application PIN;
- local encryption;
- encrypted backups.

These are not assumed for v1 unless platform constraints and user feedback justify them.

---

## 21. AI Architecture

AI must be added as an external optional capability.

AI never becomes the source of truth.

### 21.1. Tool boundary

The model interacts with Domiary only through explicit application tools.

Examples:

- GetUpcomingTasks;
- FindAssets;
- GetAssetHistory;
- GetWarrantyStatus;
- GetUpcomingObligations;
- GetSavingsSummary;
- ProposeTask;
- ProposeMaintenanceRule.

Write operations should initially be proposal-only.

### 21.2. Confirmation flow

```text
User request
    ↓
LLM interprets intent
    ↓
Tool proposal
    ↓
Domiary validates
    ↓
User sees structured preview
    ↓
Explicit confirmation
    ↓
Domain service executes
```

### 21.3. No direct database access

LLM must not receive:

- unrestricted query access;
- arbitrary code execution;
- arbitrary write access.

### 21.4. Provider abstraction

Future AI integration should separate:

- model provider;
- prompts/instructions;
- tool contract;
- application domain.

The application should remain usable if AI is unavailable.

---

## 22. RAG Architecture

Future document Q&A should be asset-scoped where possible.

Example:

```text
Asset
 ↓
Attached manual
 ↓
Text extraction / indexing
 ↓
Relevant chunks
 ↓
LLM
 ↓
Answer + source
```

Requirements:

- source attribution;
- clear distinction between document-derived answer and general model knowledge;
- no silent upload of user files;
- opt-in external processing.

---

## 23. UI Architecture

The mobile UI should be organized around user goals, not metadata types.

Recommended top-level navigation:

- Home;
- Things;
- Tasks;
- Finance;
- More.

Alternative compact navigation may be tested later.

Mapping to the user-facing terms from the README and PRD §44:

| Tab | User-facing sections |
|---|---|
| Home | What Needs Attention, History |
| Things | My Things |
| Tasks | What To Do |
| Finance | Payments, Savings |
| More | meters, documents, settings, backup/export |

### Home

- requires attention;
- upcoming;
- home status;
- recent history.

### Things

- properties;
- rooms;
- assets;
- search.

### Tasks

- today;
- upcoming;
- maintenance;
- completed.

### Finance

- obligations;
- savings;
- debts;
- planned purchases.

### More

- meters;
- documents;
- settings;
- backup/export.

Metadata names like “catalog”, “document” and “register” must never appear in end-user UI.

---

## 24. Application Service Layer

Recommended common modules/services:

- DomiaryAssets;
- DomiaryLocations;
- DomiaryMaintenance;
- DomiaryTasks;
- DomiaryMeters;
- DomiaryObligations;
- DomiaryFinance;
- DomiaryTimeline;
- DomiarySearch;
- DomiaryNotifications;
- DomiaryBackup;
- DomiaryMigrations.

Each module should expose task-oriented operations.

Good:

```text
CompleteMaintenance(...)
MoveAsset(...)
RecordMeterReading(...)
CreateSavingsContribution(...)
GetDashboard(...)
```

Avoid exposing low-level metadata manipulation as the primary application API.

---

## 25. Transactions and Consistency

Operations that affect multiple pieces of state must be atomic where supported.

Example: completing maintenance may:

1. create maintenance event;
2. update schedule;
3. add timeline entry;
4. optionally add expense;
5. reschedule notification.

The first four should be treated as one logical transaction.

Notification scheduling occurs after successful data commit and can be rebuilt later if it fails.

---

## 26. Error Handling

User-facing errors should be:

- actionable;
- non-technical;
- preserve user input where possible.

Internal failures should include structured diagnostic information.

Categories:

- validation error;
- storage error;
- migration error;
- file error;
- notification error;
- external AI error future.

No external error should make the local core unusable.

---

## 27. Testing Strategy

### 27.1. Unit tests

Critical pure/domain logic:

- recurrence;
- next maintenance date;
- warranty status;
- consumption calculation;
- debt balance;
- savings progress;
- migration transformations.

### 27.2. Integration tests

Critical workflows:

- create asset;
- move asset;
- complete maintenance;
- record meter reading;
- pay obligation;
- backup/restore;
- migration.

### 27.3. Regression tests

Required for every fixed production bug when practical.

### 27.4. Mobile smoke tests

Minimum scenarios:

- first launch;
- create home;
- create asset;
- add photo;
- create task;
- complete maintenance;
- receive/rebuild reminder;
- backup;
- restore.

---

## 28. Logging

Logging should be lightweight and local by default.

Recommended categories:

- application startup;
- migration;
- backup/restore;
- notification scheduling;
- unrecoverable domain errors.

Do not log sensitive document contents or user notes by default.

Future telemetry must be opt-in.

---

## 29. Performance Assumptions

Target household-scale data:

- up to several properties;
- hundreds or thousands of assets;
- tens of thousands of history events over years;
- hundreds of attachments.

Architecture should optimize for:

- fast startup;
- fast dashboard;
- fast local search;
- bounded memory use.

Premature optimization beyond household scale is not required.

---

## 30. Desktop Strategy

Desktop is not a separate backend.

If a desktop version is introduced, the preferred direction is to reuse:

- domain model;
- application services;
- business logic;
- migrations;
- export/import.

Desktop-specific UX may focus on:

- bulk editing;
- document management;
- QR printing;
- analytics;
- import/export.

Synchronization design is a separate future architecture decision.

---

## 31. Synchronization — Future Boundary

v1 contains no synchronization.

Future synchronization must not be added as ad hoc exchange rules scattered across modules.

Before implementation, define:

- identity model;
- conflict model;
- ownership model;
- deletion semantics;
- file synchronization;
- offline conflict behavior;
- encryption/privacy model.

Until those decisions exist, local data remains authoritative.

---

## 32. Repository Structure

Target structure may evolve toward:

```text
.
├── README.md
├── CONTRIBUTING.md
├── LICENSE
├── icon.png
├── docs/
│   ├── PRD.md
│   ├── ARCHITECTURE.md
│   ├── ROADMAP.md
│   └── adr/
├── src/
├── tests/
└── tools/
```

Potential ADR topics:

- ADR-001 metadata naming;
- ADR-002 attachment storage;
- ADR-003 timeline implementation;
- ADR-004 backup format;
- ADR-005 notification scheduling;
- ADR-006 AI tool boundary.

---

## 33. Naming Conventions

Recommended technical prefix:

`Domiary_`

or a compact project-specific prefix agreed before implementation.

Goals:

- avoid collisions;
- make project metadata recognizable;
- keep names readable.

Do not expose technical prefixes in user captions.

Naming conventions should be finalized before significant metadata creation to avoid expensive renaming.

---

## 34. Dependency Policy

Prefer:

1. native 1C platform capabilities;
2. small well-understood dependencies;
3. optional adapters for non-core capabilities.

Every external dependency should answer:

- why is it needed?
- can Domiary function without it?
- how is it licensed?
- how is it updated?
- what happens if it disappears?

Core household data management must not depend on external cloud services.

---

## 35. Architecture Decision Records

Non-trivial architectural decisions should be documented as ADRs.

Template:

```text
# ADR-NNN — Decision title

Status:
Date:

## Context

## Decision

## Alternatives

## Consequences
```

ADR should be used for decisions that would otherwise be repeatedly reopened.

---

## 36. Initial Architecture Decisions

The following are currently accepted:

### ADR candidate: modular monolith

Use one local application with explicit module boundaries.

### ADR candidate: offline-first

Core application has no mandatory network dependency.

### ADR candidate: timeline as explicit read model

Use a normalized timeline register populated by application services (§13, Option B). Final confirmation is ADR-003.

### ADR candidate: AI behind tool boundary

Future LLM integration uses explicit application tools and confirmation.

### ADR candidate: no bank integration

Finance remains intentionally lightweight.

---

## 37. Open Architecture Questions

The following decisions should be resolved before or during Phase 0:

1. ~~Exact target 1C platform version.~~ **Resolved:** 1C:Enterprise 8.5 mobile platform.
2. Android-first vs Android+iOS from first public release.
3. Source format and repository structure for configuration.
4. Metadata naming prefix.
5. Binary attachment storage strategy.
6. Backup packaging format.
7. Notification implementation details.
8. Test framework and CI approach.
9. ~~Timeline: query-time aggregation vs dedicated register.~~ **Direction chosen:** dedicated register (§13); confirm in ADR-003.
10. Task storage: catalog-style object vs dedicated document/event model.
11. Warranty fields on Asset vs separate register.
12. ~~Whether Account balances are manual state or event-derived in v1.~~ **Resolved:** manual state in v1 (§6.6), as the PRD requires.
13. Encryption requirements for local data and backups.
14. Minimal supported mobile OS versions.
15. Packaging/release path for public installation.

---

## 38. Recommended Implementation Order

Phases follow [ROADMAP.md](ROADMAP.md). This section lists the technical work inside each phase.

### Phase 0 — Foundation

Create:

- subsystems;
- common modules;
- navigation shell;
- settings;
- migration versioning;
- timeline register infrastructure.

### Phase 1 — Home & assets

Implement:

- properties;
- locations;
- assets;
- categories;
- asset purchase;
- movement;
- attachments and warranties;
- asset timeline;
- basic search.

### Phase 2 — Maintenance & reminders

Implement:

- tasks;
- recurring rules;
- maintenance completion;
- notifications;
- attention dashboard.

### Phase 3 — Home operations

Implement:

- meters;
- readings;
- obligations;
- global timeline.

### Phase 4 — Simple personal assets

Implement:

- accounts;
- savings;
- debts;
- planned purchases.

### Phase 5 — Data safety

Implement:

- search performance hardening;
- backup;
- restore;
- export;
- migration tests;
- smoke tests.

Only after the core proves useful should the project move toward:

- consumables;
- contractors;
- projects;
- QR;
- desktop;
- AI;
- synchronization.

---

## 39. Definition of Architectural Success

The architecture is successful if:

- the mobile app works fully offline;
- common user actions remain simple;
- business logic is testable outside forms;
- history can grow for years without becoming fragile;
- backup and migration are reliable;
- new modules do not require rewriting the core;
- AI can be added through controlled application APIs;
- the codebase remains understandable by external open-source contributors.

Most importantly:

> The internal system may be sophisticated, but Domiary must continue to feel like a simple household application.
