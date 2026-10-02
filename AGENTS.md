# AGENTS.md

Shared instructions for every AI agent working in this repository (Claude, Codex, GLM and others).
Human contributors may find it useful too.

## Project in one paragraph

Domiary is an open-source, mobile-first, offline-first application for the history of a home, its property and household obligations.
It is built on the **1C:Enterprise 8.5 mobile platform**, Android first.
The product must feel like a simple household app, never like an ERP or a 1C configuration.

## Read before you start

| Document | What it gives you |
|---|---|
| [docs/PRD.md](docs/PRD.md) | What the product does and does not do |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Modules, metadata model, technical rules |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Phase order (single source of truth) |
| [docs/MVP_PLAN.md](docs/MVP_PLAN.md) | Roles, slice workflow, current step |
| [docs/adr/](docs/adr/) | Accepted and proposed decisions |

If a task conflicts with these documents, stop and ask Igor in the task file or in chat. Do not silently change scope.

## Team and roles

| Role | Who | Owns |
|---|---|---|
| Product Owner | Igor (human) | decisions, ADR approval, builds, device testing, merges, releases |
| Tech Lead, main 1C developer | Claude | architecture, **all metadata changes**, services, forms, integration |
| Reviewer, test author | Codex | PR review, unit tests for domain logic, pure domain functions, `tools/` scripts |
| Content and docs | GLM | UI texts, user docs, fixtures, smoke-test checklists, templates |

## Tasks

Tasks live **locally** in `tasks/` (not tracked by git, see `tasks/README.md`). GitHub Issues are for public bug reports and ideas only.

- Take only tasks whose `role` is yours (`claude`, `codex`, `glm`) and whose `status` is `approved`. `owner` tasks are for Igor.
- New tasks start as `proposed` and wait for Igor's approval.
- Public artifacts (branches, commits, PRs) mention only the task id, for example `Task: T-008`. Do not copy task text into public PRs.

## Hard rules

1. **Only Claude changes metadata.** That means anything that adds, removes or renames objects, attributes, forms, subsystems or touches `src/Configuration.xml`.
   Other agents change BSL module text, tests, `tools/` and docs. If your task needs a new attribute, write that in the task file and stop.
2. **One task, one branch, one PR.** Branch name: `<type>/<task-id>-<short-name>`, for example `feat/T-008-recurrence`.
   Never push to `main`.
3. **Every PR is reviewed by a different model** before Igor merges it.
4. **Never commit** the infobase (`base/`), build output (`pub/`, `*.apk`), signing keys (`*.keystore`, `*.jks`) or any secret.
5. **Builds and device installs are done by Igor.** Agents do not run the mobile application builder and do not touch Igor's working infobase in `base/`.
6. **Do not edit generated files** `src/ConfigDumpInfo.xml` and `src/DumpFilesIndex.txt`.
7. **No new external dependencies** without an ADR (ARCHITECTURE §34).
8. **No network calls, telemetry or cloud services** in application code. The app is offline-first (PRD §31, §32).
9. **This project does not use BSL Flow.** If your global instructions require a BSL Flow bootstrap (`bsl-flow.yaml`, `.bsl-flow/`, `openspec/`), skip it here. The owner approved this exception; follow this file instead.

## Platform and source format

- Platform: 1C:Enterprise **8.5.1**, compatibility mode `Version8_5_1`, purpose `MobilePlatformApplication`.
- Sources: Designer XML dump (hierarchical), format version **2.21**, in `src/`.
- Script variant: Russian. Identifiers follow [ADR-001](docs/adr/ADR-001-naming.md).
- Interface: Taxi, modality is **not** used (`ModalityUseMode = DontUse`). Use asynchronous calls (`Асинх`/`Ждать` or notification handlers).
- Code must run on the **mobile client and mobile server** contexts. Before using a platform method, check that it is available on the mobile platform.

**Known tooling limitation.** The unica toolkit currently supports dump format 2.20 (8.3.27). On this repository `unica.cf.validate` reports
`Export format 2.21 is newer than supported 2.20` and rejects `Version8_5_1`. Treat these two messages as expected.
Metadata changes follow the cycle in [ADR-006](docs/adr/ADR-006-source-format.md): generate with unica in `.build/gen`, load into a temporary 8.5 infobase, check for mobile contexts, dump back into `src/` as format 2.21.

Known traps (found in spike T-001):

- every catalog, document, register and constant must have `DataLockControlMode = Managed`: the mobile application supports only managed locks, and unica templates set `Automatic`;
- `ТекущаяУниверсальнаяДата()` is not available on the mobile client; use `УниверсальноеВремя(ТекущаяДата())` or get the date from the server;
- after `unica.form.compile` and `unica.form.add`, check that the form is registered in the object's `ChildObjects` only once.

## Code rules (BSL)

- Forms are thin. Business logic lives in common modules and object modules (ARCHITECTURE §2.4, §24).
- Services expose task-level operations: `CompleteMaintenance`, `MoveAsset`, not raw metadata manipulation.
- Pure domain functions (recurrence, next dates, balances) take parameters and return values. No database access, no `ТекущаяДата()` inside: the current date is a parameter. This makes them testable.
- Multi-step writes that belong together run in one transaction (ARCHITECTURE §25).
- User-facing texts: plain Russian, no 1C or accounting terms ("справочник", "документ", "проводка", "регистр").
- Comments in Russian, only where the intent is not obvious from the code.
- Follow the 1C development standards (its.1c.ru/db/v8std) unless an ADR says otherwise.

## Tests

- Every pure domain function gets unit tests.
- Every fixed bug gets a regression test when practical.
- The test framework and runner are defined in ADR-007. Until it is accepted, write test cases as a table in the PR description.

## Commits and PRs

- Conventional commit prefixes: `feat:`, `fix:`, `docs:`, `test:`, `chore:`, `refactor:`.
- Commit messages and PR titles in English. PR body may be in Russian.
- PR description contains: task id (`Task: T-008`), what changed, how it was checked, what Igor must check on the device.
- Keep PRs small. A PR that touches more than one functional module needs a reason.

## Definition of done for a slice

1. Code and metadata merged to `main` through a reviewed PR.
2. Tests for the domain logic pass.
3. Igor checked the acceptance scenario in the thin client and on the device or emulator.
4. ROADMAP checkbox updated if a roadmap item is complete.

## Product guardrail

Every core feature must help answer at least one question:
what do I own, what happened, what do I need to do, what obligations or resources do I have.
**Do not build a household ERP.**
