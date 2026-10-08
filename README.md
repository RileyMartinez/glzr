# GlazeWM Multi-Profile System Documentation

This repository / directory contains the configuration and tooling for managing **GlazeWM** (v3.9.1) and **Zebar** on a single-monitor Windows 11 setup. It includes a profile management engine that enables hot-switching between dedicated workflows (Gaming and Development), automated application routing, and synchronized keyboard ergonomics.

---

## 1. Directory Structure

```
C:\Users\riley\.glzr\
├── README.md                      <-- System documentation (this file)
├── zebar\                         <-- Zebar status bar configuration
└── glazewm\
    ├── config.yaml                <-- Active configuration loaded by GlazeWM
    ├── config.yaml.backup         <-- Original backup of pre-migration configuration
    ├── active_profile.txt         <-- Plaintext name of currently active profile
    ├── errors.log                 <-- GlazeWM error logs
    ├── profiles\                  <-- Workflow configuration profiles
    │   ├── gaming.yaml            <-- Default profile: Gaming-optimized
    │   └── dev.yaml               <-- Development profile: Code/IDE-optimized
    └── scripts\                   <-- Automation utilities
        ├── switch-glaze.ps1       <-- Core CLI profile switcher engine
        └── toggle-kbm.ps1         <-- PowerToys Keyboard Manager controller
```

---

## 2. Profiles Overview

### 🎮 Gaming Profile (`gaming.yaml` — Default)
- **Primary Focus**: Minimizing keyboard conflicts with video games while maintaining home-row ergonomics and Borderless Fullscreen compatibility.
- **Keybinding Modifier**: **`Alt + Caps Lock`** (`alt+caps_lock`)
  - Leaves bare `Alt`, `Alt + 1..9`, and `WASD` keys completely free for in-game bindings.
  - Pinky rests naturally on `Caps Lock`, thumb on `Alt` (no wrist strain, no home-row departure).
- **PowerToys Keyboard Manager**: Automatically **disabled** when switching to this profile, preserving native `Caps Lock` functionality.
- **Game Optimization**:
  - `wm-toggle-pause` bound to `Alt + Caps Lock + Shift + P` (or physical `Pause` key) to completely suspend GlazeWM window management and keystroke interception during intense gameplay.
  - Window ignore rules active for common game launchers, overlays (Steam, NVIDIA, Riot, EA, Epic, Battle.net), and borderless fullscreen titles.

### 💻 Development Profile (`dev.yaml`)
- **Primary Focus**: Maximum productivity, fast window tiling, and Vim navigation in editors.
- **Keybinding Modifier**: Standard **`Alt`** (`alt+1..9`, `alt+h/j/k/l`)
- **PowerToys Keyboard Manager**: Automatically **enabled** when switching to this profile, remapping physical **`Caps Lock` $\rightarrow$ `Left Ctrl`**.
- **Ergonomics**: Leaves `Ctrl` 100% free for Vim navigation across editors (VS Code, Antigravity, Windows Terminal) while GlazeWM handles window layout via `Alt`.

---

## 3. Workspaces & Application Matrix

Both profiles utilize a unified single-monitor 9-workspace structure:

| Workspace | Gaming Profile (Default) | Development Profile |
| :---: | :--- | :--- |
| **1** | Google Chrome | Google Chrome |
| **2** | Steam | Antigravity |
| **3** | *(Unassigned / Free)* | Antigravity IDE |
| **4** | *(Unassigned / Free)* | Docker Desktop |
| **5** | 1Password | 1Password |
| **6** | *(Unassigned / Free)* | *(Unassigned / Free)* |
| **7** | Obsidian | Obsidian |
| **8** | Windows Terminal | Windows Terminal |
| **9** | Discord | Discord |
| **Bar** | Zebar (persistent) | Zebar (persistent) |

*All applications listed above auto-launch on startup when their respective profile is active, and their windows are automatically directed to their designated workspace via `window_rules`.*

---

## 4. Terminal Commands Reference

The following commands are registered in `$PROFILE` (`C:\Users\riley\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`):

### Profile Switching (`glz` / `switch-glaze`)
```powershell
# List available profiles and view the active profile
glz

# Switch to Gaming profile (disables Keyboard Manager & hot-reloads GlazeWM)
glz gaming

# Switch to Development profile (enables Keyboard Manager & hot-reloads GlazeWM)
glz dev

# Switch profile and launch any required applications that aren't running yet
glz dev -LaunchApps
glz gaming -LaunchApps

# Switch profile without altering PowerToys Keyboard Manager state
glz dev -NoKbmSync
```

### PowerToys Keyboard Manager Control (`toggle-kbm` / `set-kbm`)
```powershell
# Toggle Keyboard Manager between ON (Caps Lock -> Ctrl) and OFF (Normal)
toggle-kbm

# Explicitly enable or disable Keyboard Manager
set-kbm on
set-kbm off
```
*Note: Toggling produces an audible cue (high pitch for ON, low pitch for OFF) and a Windows tray balloon notification.*

---

## 5. Keyboard Shortcuts Cheat Sheet

| Action | Gaming Profile (`gaming.yaml`) | Development Profile (`dev.yaml`) |
| :--- | :--- | :--- |
| **Focus Workspace 1–9** | `Alt + Caps Lock + [1..9]` | `Alt + [1..9]` |
| **Move Window to Space 1–9** | `Alt + Caps Lock + Shift + [1..9]` | `Alt + Shift + [1..9]` |
| **Directional Focus** | `Alt + Caps Lock + [H/J/K/L]` (or arrows) | `Alt + [H/J/K/L]` (or arrows) |
| **Directional Move** | `Alt + Caps Lock + Shift + [H/J/K/L]` | `Alt + Shift + [H/J/K/L]` |
| **Resize Focused Window** | `Alt + Caps Lock + [U/Y/O/I]` | `Alt + [U/P/O/I]` |
| **Enter Resize Mode** | `Alt + Caps Lock + R` (exit: `Esc`/`Enter`) | `Alt + R` (exit: `Esc`/`Enter`) |
| **Toggle Floating** | `Alt + Caps Lock + Shift + Space` | `Alt + Shift + Space` |
| **Toggle Tiling** | `Alt + Caps Lock + T` | `Alt + T` |
| **Toggle Fullscreen** | `Alt + Caps Lock + F` | `Alt + F` |
| **Toggle Minimized** | `Alt + Caps Lock + M` | `Alt + M` |
| **Close Window** | `Alt + Caps Lock + Shift + Q` | `Alt + Shift + Q` |
| **Launch Windows Terminal** | `Alt + Caps Lock + Enter` | `Alt + Enter` |
| **Toggle Keyboard Manager** | `Alt + Caps Lock + K` (works whether KBM is ON/OFF) | `Alt + Shift + K` or `Alt + Caps Lock + K` |
| **Toggle GlazeWM Pause** | `Alt + Caps Lock + P` | `Alt + Shift + P` |
| **Reload GlazeWM Config** | `Alt + Caps Lock + Shift + R` | `Alt + Shift + R` |
| **Exit GlazeWM** | `Alt + Caps Lock + Shift + E` | `Alt + Shift + E` |

---

## 6. Windows Sign-in Autostart

GlazeWM is configured to launch automatically when you sign in to Windows via a standard shortcut:
- **Location**: `C:\Users\riley\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\GlazeWM.lnk`
- **Target**: `C:\Program Files\glzr.io\GlazeWM\glazewm.exe` (GUI subsystem, silent launch without command prompt).
- **Working Directory**: `C:\Users\riley\.glzr\glazewm`

Upon login, GlazeWM loads `C:\Users\riley\.glzr\glazewm\config.yaml` (which defaults to the Gaming profile) and triggers the configured application startup sequence.

---

## 7. Extending / Creating New Profiles

To create a new workflow profile (e.g. `reading.yaml` or `music.yaml`):

1. **Create the profile file**:
   Save your new profile in `C:\Users\riley\.glzr\glazewm\profiles\<name>.yaml`.
   You can duplicate `gaming.yaml` or `dev.yaml` as a baseline.
2. **(Optional) Add application launch targets**:
   In `C:\Users\riley\.glzr\glazewm\scripts\switch-glaze.ps1`, add your profile's application entries under `$appMap`:
   ```powershell
   '<name>' = @(
       @{ Name = 'Spotify'; Target = 'spotify.exe'; Workspace = 6 },
       ...
   )
   ```
3. **Switch to your new profile**:
   Open a terminal and run:
   ```powershell
   glz <name>
   ```
   The switcher will automatically discover the `.yaml` file, activate it, update `active_profile.txt`, and hot-reload GlazeWM.
