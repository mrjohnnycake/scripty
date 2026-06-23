# MAIN — CachyOS/Hyprland Post-Install Bootstrap TUI

A lightweight, pure-bash interactive TUI for setting up your system
step-by-step, with state tracking across reboots.

---

## Quick Start (Fresh Machine)

On a brand new install with nothing set up and no clipboard access,
run this single command:

```bash
bash <(curl -sL https://YOUR_SHORT_URL_OR_GITHUB_RAW_LINK)
```

This runs `bootstrap.sh`, which:
1. Installs `git` if it's missing
2. Clones this repo to `~/.local/share/post-install`
3. Launches `main.sh`

If you run the bootstrap command again later, it detects the
existing clone and offers to `git pull` instead of re-cloning.

**Before running it, plug in your USB drive** with a `Docs` folder
containing your WireGuard config, `.ssh` keys, dotfiles, and other
setup files — the bootstrap script will remind you, and the first
pre-check inside MAIN depends on it.

---

## Project Layout

```
main/
├── bootstrap.sh                  ← Fresh-machine entry point (clone + launch)
├── main.sh                       ← Entry point once cloned. Run this directly after setup.
├── lib/
│   ├── ui.sh                     ← Visual rendering (colors, menus, banner)
│   ├── state.sh                  ← Step status persistence (~/.cache/main/state.json)
│   ├── deps.sh                   ← Dependency checker + pre-checks (USB files, End-4, sysupdate)
│   └── installers.sh             ← Reusable install::pacman / install::aur / install::run_cmd
├── steps/
│   ├── step1_initial.sh          ← First-boot setup (packages, AUR, dotfiles, manual installs)
│   ├── step2_setups.sh           ← App & dotfile setup
│   └── step3_root_changes.sh     ← Root & system tweaks
└── files/                        ← Populated from USB on first run (wg0.conf, .ssh, Dotfiles, etc.)
```

---

## Setup

**If starting from scratch on a new machine**, use the Quick Start
bootstrap command above instead of these manual steps.

**If you already have the repo cloned:**

```bash
# 1. Make scripts executable
chmod +x main.sh steps/*.sh

# 2. Run MAIN
./main.sh
```

---

## Workflow

1. **Run** `./main.sh` (or the bootstrap one-liner on a fresh machine)
2. **Pre-checks run automatically, in order:**
   - **USB file check** — looks for a `Docs` folder on an attached USB
     and copies your WireGuard config (renamed to `wg0.conf`), `.ssh`
     folder, `70-wifi-wired-exclusive.sh`, an installer helper `.md`
     file (you pick which one if there are several, renamed to
     `installer-helper.md`), and the `Dotfiles` folder into `files/`.
     If these are already present from a previous run, this check is
     skipped automatically.
   - **End-4 Dotfiles Installer check** — if you haven't run it yet
     (no `~/.config/illogical-impulse/installed_true` sentinel file),
     you're prompted to launch it. The script **exits** either way
     here — either because the installer just launched (re-run MAIN
     when it's done) or because you declined and the script can't
     continue without it.
   - **System update offer** — prompts to run `sudo pacman -Syu`
     before continuing.
3. `installer-helper.md` opens automatically in a separate `kitty`
   window (`--hold`, so it stays open until you close it) so you have
   your notes visible while working through the menu.
4. **Main menu appears** → select **Step 1**
5. Step 1 runs → if marked to reboot, you're asked **"Reboot now?"**
   — nothing reboots without confirmation
6. Log back in → run `./main.sh` again → select **Step 2**
7. Repeat until all steps are done

State is saved to `~/.cache/main/state.json` and survives reboots,
so MAIN always knows which steps you've completed.

---

## Adding Your Commands

Each step script is plain bash. Use the installer functions in
`lib/installers.sh` for anything that installs packages or runs a
setup command — they handle prompting, per-package failure handling,
and dry-run support for you.

### Installer functions (`lib/installers.sh`)

```bash
source "$SCRIPT_DIR/../lib/installers.sh"

# One prompt, installs a whole group of pacman packages.
# Each package installs individually — if one fails, the rest still
# continue, and failures are listed in a summary at the end.
PKGS=(firefox neovim tmux)
install::pacman "Install core packages?" "${PKGS[@]}"

# Same idea, but via paru for AUR packages. Skips automatically with
# a warning if paru isn't installed.
AUR_PKGS=(some-aur-pkg-bin)
install::aur "Install AUR packages?" "${AUR_PKGS[@]}"

# For anything else — git clones, curl installs, multi-line setup.
# Use ; or a newline to chain multiple commands in sequence (no need
# for && unless one command depends on the previous succeeding).
install::run_cmd \
  "Clone wg-tray from GitHub?" \
  "wg-tray" \
  'git clone https://github.com/example/wg-tray.git ~/.config/wg-tray'
```

**To disable any `install::run_cmd` / `install::pacman` / `install::aur`
block without deleting it**, comment out every line of that call
(each `\`-continued line needs its own `#`):

```bash
# install::run_cmd \
#   "Run script 3?" \
#   "Script 3" \
#   'echo "disabled for now"'
```

**Dry-run mode** — walk through every prompt without installing or
running anything for real:

```bash
DRY_RUN=true bash main.sh
```

Commands print as `[DRY RUN] Would run: ...` instead of executing.

### Helper functions available in step scripts (`lib/ui.sh`)

```bash
source "$SCRIPT_DIR/../lib/ui.sh"

ui::section "My section heading"   # prints a section header
ui::info    "informational note"   # blue  ℹ line
ui::success "it worked"            # green ✔ line
ui::warn    "heads up"             # yellow ⚠ line
ui::error   "something broke"      # red  ✖ line (stderr)
```

### Checking for step dependencies

```bash
source "$SCRIPT_DIR/../lib/deps.sh"

# Abort the step with a clear message if a tool is missing:
deps::require_in_step "paru" "paru AUR helper" "Complete Step 1 first"
```

---

## State File

`~/.cache/main/state.json` — auto-created on first run.

Uses `jq` if installed (recommended), otherwise falls back to a plain
key=value text file. Install jq with: `sudo pacman -S jq`

Example state (jq format):
```json
{
  "steps": {
    "step1": { "status": "done",    "started": "2025-01-01 12:00:00", "completed": "2025-01-01 12:05:00" },
    "step2": { "status": "pending" },
    "step3": { "status": "pending" }
  }
}
```

To manually reset a step's status, run MAIN and choose **Reset a Step**,
or edit/delete `~/.cache/main/state.json` directly.

---

## Log File

All step output is also appended to `~/.cache/main/main.log`.
View it inside MAIN by pressing **l** from the main menu, or directly:

```bash
less ~/.cache/main/main.log
```

---

## Dependencies

**Required:**
- `bash` 4+
- `tput` (ncurses)
- `less`
- `systemctl` (systemd)
- `git` (only needed for the bootstrap one-liner — installed
  automatically if missing)
- `kitty` (for the `installer-helper.md` popup window)

**Recommended:**
- `jq` — for proper JSON state storage (`sudo pacman -S jq`)
- `paru` — for AUR installs (Step 1 installs this automatically if
  missing)

No `dialog`, `whiptail`, `fzf`, or Python required. Pure bash.

---

## Adding More Steps

1. Create `steps/step4_whatever.sh`
2. Add an entry to the `STEPS` array in `main.sh`:

```bash
declare -a STEPS=(
  ...existing entries...
  "step4_whatever.sh|Step 4 — Whatever|Short description|yes"
  #                                                        ^^^
  #                                        "yes" = reboot after, "no" = no reboot
)
```

That's it — MAIN picks it up automatically. The Exit option in the
main menu renumbers itself automatically based on how many steps
exist.
