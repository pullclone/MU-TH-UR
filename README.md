# MU/TH/UR

MU/TH/UR is an evolving shell environment system that integrates AI profile management via _aichat_swap.  
This repository currently represents a work-in-progress.  

## Purpose
- Provide a structured location for Bash configuration, AI profile swapper, and future scripts.
- Enable future cross-machine sync of AI configurations.
- Keep shell environment modular and maintainable.

## Current Structure
- `bashrc` → Core Bash configuration (includes _aichat_swap v1.2.0)
- `aichat/` → Profiles and alias management. YAMLs are created dynamically when profiles are used.
- `scripts/` → Additional utilities and bootstrap scripts.
- `.gitignore` → Logs, temporary files, and runtime state.

> Note: The structure is tentative. Additional modules, scripts, and sync functionality will be added in subsequent patches.
