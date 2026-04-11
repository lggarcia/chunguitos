# 🐧 LFS Automator (Chunguito Version)

A robust, modular, Distro-Agnostic, and fail-safe automation suite to build the Linux From Scratch Projet (LFS 12.3).

This project transforms the manual and exhaustive LFS compilation process into a fluid, predictable, and highly resilient experience. Built with a focus on maintainability and clean architecture, the system uses a CSV database as a Single Source of Truth alongside advanced Bash scripts that intelligently handle downloads, compilations, logs, and permissions.

## Key Features
* **Data-Driven Architecture (CSV):** Forget dozens of hardcoded arrays scattered throughout the scripts. The `pacotes.csv` file dictates the compilation order, versions, and URLs for all packages and patches. Upgrading the LFS version in the future means updating just this single file (and maybe receitas.sh).
* **Smart & Self-Healing Downloader:** The `downloadPackages.sh` script is idempotent. It detects corrupted files or partial downloads (0 bytes), performs automatic retries, features a fallback mode to bypass problematic SSL certificates, and interactively pauses if a package requires manual intervention.
* **"Black-Box" Compilation and Surgical Logs:** The terminal remains clean and elegant during hours of compilation. The execution engine suppresses thousands of lines of compiler output from the screen and dumps all detailed output into individual log files (`/logs/faseX-package.log`). If an error occurs, it points exactly where to investigate.
* **Automatic Diet LFS:** A safe routine for stripping debug symbols from binaries and static libraries (saving up to 3 GB of disk space and freeing up RAM) without touching critical dynamic libraries (`.so`), completely preventing the dreaded Segmentation Fault.
* **Deep Clean (Leftover Prevention):** The script automatically wipes orphaned source code folders before and after each package is built.
* **100% Distro-Agnostic:** Built exclusively with standard and native POSIX tools (like `awk`, `tar`, `find`, `wget`, `grep`). It does not rely on the host system's package managers to execute its logic.

##Project Architecture

| Component | Description |
| :--- | :--- |
| `arrastao.sh` | **The Pre-Configurator (Stage 0).** Prepares the host system by handling disk partitioning and dynamically injecting necessary data into the subsequent scripts to guarantee a fully automated, unattended execution. |
| `lgg-lfsIZADOR.sh` | **The Master Script.** Executed as root, it prepares the environment, manages permissions, clears the ground from previous runs, and orchestrates the transition between Phase 1 (Cross-Toolchain) and Phase 2 (Chroot/Base System). |
| `construtor.sh` | **The Build Engine.** Reads the CSV line by line, handles tarball extraction, invokes the compilation recipes, and destroys the source folder right after. |
| `receitas.sh` | **The Recipe Book.** Contains the Bash functions with the specific guidelines (`./configure`, `make`, etc.) required by the official LFS book for each package. |
| `downloadPackages.sh` | **The Download Manager.** Ensures 100% integrity of the original packages before allowing the build engine to start. |
| `pacotes.csv` | **The Database.** Contains Phases, Recipe IDs, Names, Versions, Extensions, and Source URLs. |
| `post-lfsIZADOR.sh`| **The Post-Installation Configurator.** Handles the final system configurations and sets up the GRUB bootloader, ensuring the new LFS system is dual-boot ready. |

## Notes
Project and tests are not finished. This is an Aplha version, and probably will remain like this forever.
Use it at your own risk, but please, do risk it!

## Getting Started

### Prerequisites
As script will check and try to install all necessary tools, you must have a linux distro, another disk for the LFS system and root permissions.
In case of failure on checking or installing tools, script will provide information on what's missing. 

### Usage

1. Clone this repository
2. Set execution permissions for arrastao.sh (chmod u+x arrastao.sh).
3. Run as root `arrastao.sh` to set partitions and check files. 
4. Run as root `lgg-lfsIZADOR.sh`.
5. Run as root `post-lfsIZADOR.sh`.
6. Enjoy your new linux!

## Known Bugs

1. After `post-lfsIZADOR.sh` execution, gub entry for ChuntuitOS may not work with a *"KERNEL PANIC!"* message, but the fix is just set the correct partition on the new grub menu. New grub doesn't work with UUID for chunguitOS. (SOLVED - Uses PARTUUID now)
2. After boot, several services, including network doesn't work.

## Tested Platforms

Even though this script is distro-agnostid and should run on any x86-64 platform, it was tested on: 
1. Debian Trixie on a Proxmox VM.


