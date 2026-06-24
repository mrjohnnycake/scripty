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
     and copies your WireGuard config (you pick which one if there are
     several, renamed to `wg0.conf`), `.ssh` folder,
     `70-wifi-wired-exclusive.sh`, an installer helper `.md` file (you
     pick which one if there are several, renamed to
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
3. `installer-helper.md` opens automatically in a separate `kwrite`
   window so you have your notes visible while working through the
   menu.
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
# IMPORTANT: chain dependent lines with && (not ; or a bare newline).
# install::run_cmd uses eval inside an `if`, which suspends `set -e`
# for the whole block — so a failed `cd` or earlier command will NOT
# stop later lines from running unless you chain with &&. A newline
# only works safely for truly independent commands (e.g. several
# unrelated `rm -rf` cleanup lines) where one failing shouldn't block
# the rest.
install::run_cmd \
  "Clone wg-tray from GitHub?" \
  "wg-tray" \
  'git clone https://github.com/example/wg-tray.git ~/.config/wg-tray'
```

**This bit me for real once, so it's worth spelling out exactly what
goes wrong if you forget an `&&`:**

```bash
# BROKEN — only the cd is chained, everything after it is a bare newline:
'cd ~/Dotfiles/Apps &&
 rm -rf ~/.config/something
 rm -rf ~/.config/something_else
 stow -t ~/ whatever'
```

If `~/Dotfiles/Apps` doesn't exist yet, the `cd` fails — but `rm -rf`
and `stow` still run anyway, just from whatever directory the script
happened to be in (often `$HOME`). `install::run_cmd` will correctly
report the block as failed (the broken chain means the `cd`'s own exit
status is what `eval` ultimately sees), but by then the `rm -rf` calls
have already executed somewhere you didn't intend. Always chain every
line with `&&`, all the way to the last one, whenever a later line
depends on an earlier one succeeding (especially a `cd`):

```bash
# CORRECT:
'cd ~/Dotfiles/Apps &&
 rm -rf ~/.config/something &&
 rm -rf ~/.config/something_else &&
 stow -t ~/ whatever'
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

**Watch out for `chmod` on a glob that might contain a directory.**
`chmod 600 ~/.ssh/*` (as used for the copied USB `.ssh` folder in Step
1) is correct as long as `.ssh` only ever contains plain files. If you
ever add a subdirectory in there — a `sockets/` folder, `config.d/`,
whatever — `chmod 600` strips its execute bit too (`drw-------`),
which makes it unreadable/un-`cd`-able even though the files inside
keep whatever mode they had. If you add a subfolder, `chmod` files and
directories separately instead:

```bash
find ~/.ssh -type f -exec chmod 600 {} +
find ~/.ssh -type d -exec chmod 700 {} +
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
- `kwrite` (for the `installer-helper.md` popup window)

**Recommended:**
- `jq` — for proper JSON state storage (`sudo pacman -S jq`)
- `paru` — for AUR installs (Step 1 installs this automatically if
  missing)

No `dialog`, `whiptail`, `fzf`, or Python required. Pure bash.

---

## Hardcoded Personal Config — Read Before Reusing

This repo was written for one specific person's machine and accounts.
Several lines bake in names, paths, and a server choice that are
**not generic** — if you're adapting this for your own setup (or
someone else is), check these before running Steps 1–2:

| File | Line(s) | What's hardcoded |
|---|---|---|
| `bootstrap.sh` | `REPO_URL`, comments | `mrjohnnycake/scripty` GitHub repo — point this at your own fork/clone |
| `steps/step1_initial.sh` | `~/Dotfiles/Desktop/Dell/Hyprland` | Path assumes a machine named/profiled `Dell` in the Dotfiles repo |
| `steps/step1_initial.sh` | `/mnt/Homer/*` symlinks | Replaces `Documents/Downloads/Music/Pictures/Projects/Videos` with symlinks to a specific NAS/mount named `Homer` — **destructive** (`rm -rf` first) if that mount isn't what you expect |
| `steps/step1_initial.sh` | `chirp-next`, `1password` AUR comments | Personal install-method notes (Baofeng radio software, 1Password quirks) — harmless if irrelevant to you, just noise |
| `steps/step2_setups.sh` | `~/Dotfiles/Desktop/Dell/Scripts` | Same `Dell`-profile path assumption as above |
| `steps/step2_setups.sh` | PIA VPN block: `uk_manchester.ovpn` | Hardcoded to one Private Internet Access server/region — swap to your preferred PIA server filename |
| `steps/step2_setups.sh` | `fprintd-enroll --finger right-index-finger` | Hardcodes which finger gets enrolled for fingerprint auth |
| `variables/vivaldi-urls.txt` | `start.mrjohnnycake.com` | One of the tabs auto-opened by Step 2 is a personal start page |

None of these will break the *script* for someone else — they'll just
run against the wrong path/server/repo, usually failing loudly (a
missing directory, an unknown VPN config file) rather than silently.
The one to be most careful with is the `/mnt/Homer` symlink block,
since it deletes the original folders before linking — make sure that
mount is actually present and correct before confirming that prompt.

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

**Heads up if you ever go past 9 steps:** the main menu matches your
choice with a `case "$choice" in [1-9])` glob in `main.sh`. That's a
single-character pattern, so a 10th step (entered as `"10"`) won't
match it — the input just falls through to the no-op default branch
instead of running anything or showing an error. Fine at 3 steps, but
worth knowing before you scale up. If you get there, swap the pattern
for a numeric check instead, e.g. `[[ "$choice" =~ ^[0-9]+$ ]]`.
