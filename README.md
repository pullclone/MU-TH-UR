# MU/TH/UR

MU/TH/UR is an evolving shell environment system that integrates AI profile management via `aiswap`.

It serves as the execution environment and orchestration layer for AI configuration workflows, while providing a hardened, WSL-optimized baseline for development.

---

## Purpose

- Provide a cohesive Bash environment with integrated AI profile control
- Serve as the runtime layer for `aiswap`
- Guarantee secure, persistent SSH and Git operations (WSL-optimized)
- Enable future cross-machine sync
- Maintain modular, auditable shell infrastructure

---

## Current Structure

- `bashrc`  
  Core shell runtime (currently encapsulates all logic)  
  → integrates `aiswap v1.2.3` and persistent SSH socket management

- `aichat/` (Tentative)  
  Placeholder for profile + alias data layer  
  → YAML files are currently created dynamically in `~/.config/aichat`

- `scripts/` (Tentative)  
  Placeholder for future bootstrap and scaffolding

- `.gitignore`  
  Excludes runtime state

---

## Architecture

| Layer        | Role                          |
|--------------|-------------------------------|
| MU/TH/UR     | Shell + orchestration runtime |
| aiswap       | Profile switching engine      |
| aichat       | Config/state system           |

---

## Status

⚠️ Phase 3 (Active Development)

- Structure is evolving
- Interfaces may shift between patches
- Stability focus:
  - local atomic profile switching
  - WSL SSH-agent persistence
  - shell integration parity

---

## Roadmap

- Cross-machine sync
- Remote state reconciliation
- Modular plugin system
- Config validation
- Provider abstraction

---

## Notes

- YAML configs are intentionally not stored
- aiswap evolves independently but is integrated here
- Repo structure is provisional

---

## Philosophy

MU/TH/UR prioritizes:

- Transparency over abstraction
- Atomic operations over mutation
- Composability over monolithic design
