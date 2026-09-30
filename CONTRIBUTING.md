# Contributing to Domiary

Thank you for your interest in Domiary.

The project is currently in an early product-design stage. Contributions are welcome, but the main priority is to keep the product coherent and avoid expanding it into a generic household ERP.

## Before contributing

Please read:

1. [README.md](README.md)
2. [docs/PRD.md](docs/PRD.md)
3. [docs/ROADMAP.md](docs/ROADMAP.md)

## What is useful right now

The most valuable contributions at this stage are:

- real household use cases;
- UX proposals;
- review of the product model;
- 1C mobile-platform implementation considerations;
- offline-first architecture ideas;
- backup/export design;
- testing strategy;
- accessibility considerations;
- clearly scoped implementation proposals.

## Product guardrail

A proposed feature should help answer at least one of these:

- What do I own?
- What happened to it?
- What do I need to do?
- What obligations or resources do I have?

Features outside this model may still be useful, but they should not enter the core product without a clear rationale.

## Development principles

When implementation begins, contributions should follow these principles:

- KISS over speculative architecture;
- explicit domain boundaries;
- mobile-first UX;
- offline-first core;
- no mandatory cloud dependency;
- user-owned/exportable data;
- automated tests for critical business logic;
- backward-compatible data migrations where practical;
- no AI dependency for core features.

## AI contributions

AI-related features must follow stricter rules:

- AI should reduce user effort;
- proposed writes require explicit confirmation;
- AI must not silently modify user data;
- external processing must be visible to the user;
- the application must remain usable without AI;
- document-based answers should expose their source where possible.

## Issues

Before opening an issue:

- search existing issues;
- describe the user problem, not only the desired implementation;
- include the expected workflow;
- explain why the proposal belongs in the core product.

For bugs, include reproduction steps and platform/version information once builds are available.

## Pull requests

Before large implementation PRs, please open an issue or discussion first so the design can be agreed before significant work is done.

Prefer:

- small, focused changes;
- clear commit messages;
- tests for changed business logic;
- documentation updates when behavior changes.

## License

By contributing, you agree that your contributions will be licensed under the repository's [Apache License 2.0](LICENSE).
