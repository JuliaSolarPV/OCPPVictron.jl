# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OCPPVictron.jl is a Julia package for OCPP (Open Charge Point Protocol) integration with Victron energy systems. Part of the JuliaSolarPV organization. Currently in early development (v0.1.0). Scaffolded from JuliaBesties/BestieTemplate.jl.

## Common Commands

### Testing

```bash
# Run all tests
julia --project=. -e 'using Pkg; Pkg.test()'

# Run tests from the Pkg REPL
# julia --project=., then ] test

# Run a single test file or tagged tests using TestItemRunner in VS Code/editor
# Tests use @testitem with tags: :unit, :fast, :integration, :slow, :validation
```

### Formatting

```bash
# Run all pre-commit hooks (formatting, linting)
pre-commit run -a

# Format Julia code only (requires JuliaFormatter installed globally)
julia -e 'using JuliaFormatter; format(".")'
```

### Documentation

```bash
# Build and serve docs locally
julia --project=docs -e 'using LiveServer; servedocs()'

# First time: run `julia --project=docs`, then ] dev .
```

## Code Style

- JuliaFormatter: 4-space indent, 92-character margin, unix line endings (see `.JuliaFormatter.toml`)
- Pre-commit hooks enforce formatting — install with `pre-commit install`

## Architecture

- **`src/OCPPVictron.jl`** — Main module entry point
- **`test/`** — Uses TestItems.jl + TestItemRunner.jl (not standard `@testset`). Test files are named `test-*.jl` and auto-discovered by `@run_package_tests`. Tests use `@testitem`, `@testsnippet` (shared data), and `@testmodule` (shared helpers).
- **`docs/`** — Documenter.jl with LiveServer for local preview
- **`ocpp-files/`** — OCPP protocol reference docs and design documents (not package code)

## Testing Conventions

Tests use the TestItems.jl pattern, not traditional `runtests.jl` with nested `@testset`. Each `@testitem` is independent and isolated. Tag tests appropriately (`:unit`, `:integration`, etc.) for selective running.

## Git Conventions

- Branch naming: `{issue-number}-{dash-separated-description}` (e.g., `42-add-answer-universe`)
- Commit messages: imperative/present tense (e.g., "Add feature", "Fix bug")
- Linear history preferred — rebase before PR
