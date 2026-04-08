# MU/TH/UR

MU/TH/UR is an evolving shell environment system that integrates AI profile management via `aiswap`.

It serves as the execution environment and orchestration layer for AI configuration workflows.

---

## Purpose

- Provide a cohesive Bash environment with integrated AI profile control
- Serve as the runtime layer for `aiswap`
- Enable future cross-machine sync
- Maintain modular, auditable shell infrastructure

---

## Current Structure

- `bashrc`  
  Core shell runtime  
  → integrates `aiswap v1.2.2`

- `aichat/`  
  Profile + alias data layer  
  → YAML files created dynamically by aichat

- `scripts/`  
  Bootstrap and scaffolding

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

⚠️ Work in progress

- Structure is evolving
- Interfaces may shift between patches
- Stability focus:
  - local profile switching
  - shell integration

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
