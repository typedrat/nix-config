# Samsung Tank Pool + Bulk Relocation + Backups — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **This plan is largely imperative sysadmin work on a live host (destructive ZFS ops, reboots).** It is executed **interactively with the user** (they hold the pool passphrase and drive reboots), not by autonomous subagents. "Tests" are **verification commands with expected output**; config/code tasks still end in a commit.

**Goal:** Repurpose the (now-idle) Samsung 990 EVO Plus as an encrypted `tank` pool, relocate ~1.38 TiB of re-downloadable bulk (`~/AI`, `~/.cache/huggingface`, `~/.local/share/Steam`, `~/Games`, and the three anime-game-launcher dirs) off the backed-up root onto it, and stand up sanoid/syncoid backups of the slim (~360 G) irreplaceable data to iserlohn.

**Architecture:** Two phases. **Phase 1** wipes the Samsung, builds `tank` as a **single dataset** (encrypted, key on `/persist`, auto-unlocked in stage-2) mounted at `/tank`, moves the bulk via a second home-manager impermanence root at `/tank`, and reconciles the stale disko `disk.main` to the live Corsair. **Phase 2** adds a net-new sanoid/syncoid module pushing `zpool/safe/*` to iserlohn's `zfspv-pool`. The ~240 G irreplaceable core is single-copy (new, healthy Corsair only) from the Samsung wipe until Phase 2's first sync lands.

**Tech Stack:** NixOS (flake-parts, `rat.*` options), ZFS (native encryption), disko, home-manager impermanence, sanoid/syncoid, SOPS.

## Global Constraints

- Host: **ulysses**. Deploy locally with `nix run .#boot` (boot-time, safer than switch for mount changes) then reboot; deploy iserlohn with `nix run .#switch iserlohn`.
- **Every destructive/device operation uses `/dev/disk/by-id/…` or `/dev/disk/by-partlabel/…`, never `/dev/nvmeXnY`** — device names invert across reboots.
- Corsair (root, keep): `nvme-Corsair_MP700_PRO_XT_AD27B6108002KO` — partlabels `disk-main-ESP` (4G) / `disk-main-swap` (8G) / `disk-main-root` (rest).
- Samsung (wipe): `nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NU0YA00669D` — currently exported (`zpool-old` not imported).
- Root pool `zpool`: single encryption root at `zpool`, `keyformat=passphrase`, unlocked by prompt in initrd. `/persist` = `zpool/safe/persist`, `neededForBoot=true` (available early).
- Tank pool `tank` (one dataset = pool root, mounted at `/tank`): `aes-256-gcm`, `keyformat=passphrase`, `keylocation=file:///persist/.tank.key`, `ashift=12`, `recordsize=1M`, `compression=lz4`, `atime=off`, `normalization=formD`.
- The seven relocated dirs, and the tank dataset they live in:

  | Home dir (relative to `~`) | Under `/tank/home/awilliams/` |
  | --- | --- |
  | `AI` | `AI` |
  | `.cache/huggingface` | `.cache/huggingface` |
  | `.local/share/Steam` | `.local/share/Steam` |
  | `Games` | `Games` |
  | `.local/share/anime-game-launcher` | `.local/share/anime-game-launcher` |
  | `.local/share/honkers-railway-launcher` | `.local/share/honkers-railway-launcher` |
  | `.local/share/sleepy-launcher` | `.local/share/sleepy-launcher` |

- Never re-run `disko` destructively against the Samsung once Windows occupies its free space.
- Verify every `rsync` before deleting any source data.
- `nix fmt` before each commit; leave the unrelated `M modules/nixos/boot/default.nix` change alone (do not stage it).

---

# Phase 1 — Tank pool, relocation, disko reconcile

### Task 1: Reclaim benchmark datasets

Leftover fio benchmark datasets (`zpool/local/bench1m` 160G, `zpool/local/bench4k` 66G) are pure garbage — no snapshots, not mounted. Destroying them frees ~226 G on the Corsair.

**Files:** none (imperative).

- [ ] **Step 1: Confirm they are garbage (no snapshots, not mounted)**

Run:
```bash
zfs list -t snapshot -r zpool/local/bench1m zpool/local/bench4k
zfs get -H -o name,property,value mounted zpool/local/bench1m zpool/local/bench4k
```
Expected: no snapshots listed; `mounted` = `no` for both.

- [ ] **Step 2: Destroy both datasets and confirm**

```bash
sudo zfs destroy zpool/local/bench1m
sudo zfs destroy zpool/local/bench4k
zpool list -o name,free zpool; zfs list -r zpool/local
```
Expected: FREE grew by ~226 G; `bench1m`/`bench4k` gone from the list.

---

### Task 2: Reconcile disko `disk.main` to the Corsair

The checked-in `systems/ulysses/disko-config.nix` still declares `disk.main` on the Samsung with a 1G ESP and `ESP→root→swap` order. Update it to the live Corsair reality (4G ESP, `ESP→swap→root`). **Non-destructive** — `nixos-rebuild` only consumes the generated `fileSystems` (all keyed by partlabel, which the migration already relabeled to `disk-main-*`), so the generated mounts are identical before and after.

**Files:**
- Modify: `systems/ulysses/disko-config.nix` (the `disk.main` block)

- [ ] **Step 1: Capture the current generated fileSystems as a baseline**

```bash
nix eval --json .#nixosConfigurations.ulysses.config.fileSystems \
  --apply 'fs: builtins.mapAttrs (_: v: { inherit (v) device fsType; }) fs' 2>/dev/null | \
  python3 -m json.tool > /tmp/fs-before.json
cat /tmp/fs-before.json
```
Expected: JSON with `/boot` → `/dev/disk/by-partlabel/disk-main-ESP`, `/` → `zpool/local/root`, etc.

- [ ] **Step 2: Edit `disk.main`**

Replace the `disk.main` block's `device` and `partitions` so it reads:
```nix
      main = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-Corsair_MP700_PRO_XT_AD27B6108002KO";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "4G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["umask=0077"];
              };
            };
            swap = {
              size = "8G";
              content = {
                type = "swap";
                randomEncryption = true;
              };
            };
            root = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zpool";
              };
            };
          };
        };
      };
```
Leave the entire `zpool` block below it unchanged.

- [ ] **Step 3: Verify the generated fileSystems are unchanged**

```bash
nix eval --json .#nixosConfigurations.ulysses.config.fileSystems \
  --apply 'fs: builtins.mapAttrs (_: v: { inherit (v) device fsType; }) fs' 2>/dev/null | \
  python3 -m json.tool > /tmp/fs-after.json
diff /tmp/fs-before.json /tmp/fs-after.json && echo "IDENTICAL — safe"
```
Expected: `IDENTICAL — safe`. If the diff is non-empty, STOP and investigate before rebuilding.

- [ ] **Step 4: Format and commit**

```bash
nix fmt
git add systems/ulysses/disko-config.nix
git commit -m "ulysses/disko: reconcile disk.main to the Corsair (4G ESP, ESP/swap/root)"
```

---

### Task 3: Build the encrypted `tank` pool on the Samsung

Destructive — wipes the Samsung (the last pre-migration fallback). Guarded. Creates the pool as a single dataset (pool root) mounted at a **temporary** path for relocation, plus the key on `/persist`.

**Files:** none (imperative); creates `/persist/.tank.key`.

- [ ] **Step 1: Guards — confirm target identity and that nothing on the Samsung is imported**

```bash
SAMSUNG=/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NU0YA00669D
readlink -f "$SAMSUNG"                     # note which nvmeXnY it is right now
zpool list zpool-old 2>&1 | tail -1        # expect: cannot open 'zpool-old': no such pool
findmnt -no SOURCE / | grep -q Corsair && echo "root is on Corsair"
lsblk -o NAME,SIZE,PARTLABEL "$SAMSUNG"    # expect old-esp/old-root/old-swap
```
Expected: `zpool-old` absent; the by-id points at the Samsung; partlabels are `old-*`. **If `zpool-old` imports, STOP** — do not wipe a live fallback.

- [ ] **Step 2: Wipe the GPT and create the tank + reserved partitions**

End `-512G` reserves 512 GiB at the end of the disk for a later Windows install; tank takes the rest (~3.14 TiB).
```bash
SAMSUNG=/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NU0YA00669D
sudo sgdisk --zap-all "$SAMSUNG"
sudo sgdisk -n 1:0:-512G -t 1:BF01 -c 1:tank "$SAMSUNG"
sudo partprobe "$SAMSUNG"; sleep 2
ls -l /dev/disk/by-partlabel/tank
```
Expected: `tank` partlabel resolves to the Samsung's `p1`.

- [ ] **Step 3: Write the pool key onto the encrypted /persist**

```bash
sudo install -m 600 -o root -g root /dev/null /persist/.tank.key
head -c 32 /dev/urandom | base64 -w0 | sudo tee /persist/.tank.key >/dev/null
sudo chmod 600 /persist/.tank.key
sudo stat -c '%a %U:%G %s' /persist/.tank.key   # expect: 600 root:root <nonzero>
```

- [ ] **Step 4: Create the pool (single dataset = pool root), temp mountpoint**

```bash
sudo zpool create -f \
  -o ashift=12 -o autotrim=on -o cachefile=none \
  -O encryption=aes-256-gcm -O keyformat=passphrase \
  -O keylocation=file:///persist/.tank.key \
  -O acltype=posixacl -O xattr=sa -O dnodesize=auto -O normalization=formD \
  -O compression=lz4 -O atime=off -O recordsize=1M \
  -O canmount=on -O mountpoint=/mnt/tank \
  tank /dev/disk/by-partlabel/tank
```

- [ ] **Step 5: Verify pool, encryption, and props**

```bash
zpool status tank
zfs get -H -o name,property,value keystatus,encryption,recordsize,compression,atime tank
findmnt /mnt/tank
```
Expected: pool `ONLINE`; `keystatus=available`, `encryption=aes-256-gcm`, `recordsize=1M`, `compression=lz4`, `atime=off`; `/mnt/tank` mounted.

---

### Task 4: Relocate the bulk onto tank

Copy the seven dirs, verify, reclaim their space from `safe/persist`, then set the dataset's final mountpoint. **Steam and the anime-game launchers must be closed first.** All seven dirs are driven from one mapping array (DRY).

**Files:** none (imperative).

- [ ] **Step 1: Quiesce, and define the shared mapping array**

Run (paste once; the `MAP` array is reused in later steps of this task):
```bash
pkill -x steam 2>/dev/null; sleep 2
DIRS=(
  "AI"
  ".cache/huggingface"
  ".local/share/Steam"
  "Games"
  ".local/share/anime-game-launcher"
  ".local/share/honkers-railway-launcher"
  ".local/share/sleepy-launcher"
)
SRC=/persist/home/awilliams
DST=/mnt/tank/home/awilliams
for d in "${DIRS[@]}"; do fuser -m "$SRC/$d" 2>/dev/null && echo "IN USE: $d"; done
echo "quiesce check done"
```
Expected: no `IN USE` lines. Close any app still holding a path.

- [ ] **Step 2: Record source sizes**

```bash
for d in "${DIRS[@]}"; do printf '%-45s %s\n' "$d" "$(sudo du -sh "$SRC/$d" 2>/dev/null | cut -f1)"; done
```
Expected: `AI`≈692G, `.cache/huggingface`≈44G, `.local/share/Steam`≈314G, `Games`≈266G, `honkers-railway-launcher`≈99G, the other two ~0. Note them.

- [ ] **Step 3: Copy each dir (contents → matching path under tank), preserving attrs**

```bash
for d in "${DIRS[@]}"; do
  echo "== rsync $d =="
  sudo mkdir -p "$DST/$d"
  sudo rsync -aHAX --info=progress2 "$SRC/$d/" "$DST/$d/"
  # rsync SRC/ DST/ copies contents but not DST's own attrs; match the dir itself:
  sudo chown --reference="$SRC/$d" "$DST/$d"
  sudo chmod --reference="$SRC/$d" "$DST/$d"
done
```

- [ ] **Step 4: Verify every copy before deleting anything**

```bash
for d in "${DIRS[@]}"; do
  sc=$(sudo find "$SRC/$d" | wc -l); dc=$(sudo find "$DST/$d" | wc -l)
  ss=$(sudo du -sh "$SRC/$d" | cut -f1); ds=$(sudo du -sh "$DST/$d" | cut -f1)
  printf '%-45s files %6s/%-6s  du %6s/%-6s\n' "$d" "$sc" "$dc" "$ss" "$ds"
done
```
Expected: file counts equal per dir, `du` sizes match (±small from recordsize/compression). **If any mismatch, STOP** — re-run that rsync; do not delete.

- [ ] **Step 5: Reclaim the source space (delete contents; dirs are bind sources, keep the dir)**

```bash
for d in "${DIRS[@]}"; do sudo find "$SRC/$d" -mindepth 1 -delete; done
zfs list -o name,used,referenced zpool/safe/persist
```
Expected: `safe/persist` referenced drops toward ~240 G.

- [ ] **Step 6: Set the final mountpoint (unmounts the temp mount)**

```bash
sudo zfs set canmount=noauto tank
sudo zfs set mountpoint=/tank tank
zfs get -H -o name,value mountpoint,canmount tank
findmnt /mnt/tank 2>/dev/null || echo "temp mount gone — data at rest on tank"
```
Expected: `mountpoint=/tank`, `canmount=noauto`, temp mount gone. The config in Task 5 mounts it at boot.

---

### Task 5a: Add the tank persistence options to the impermanence module

**Files:**
- Modify: `modules/nixos/impermanence.nix`

**Interfaces:**
- Produces: `config.rat.impermanence.tank.enable : bool`, `config.rat.impermanence.tankDir : str` (default `/tank`), read by the home-manager modules in Task 5b and set true by Task 5c.

- [ ] **Step 1: Add the options**

In the `options.rat.impermanence` block (after `home.enable`), add:
```nix
    tank.enable = mkEnableOption "a separate bulk persistence root on its own pool";

    tankDir = mkOption {
      type = types.str;
      default = "/tank";
      description = "Mount root for the bulk (tank) persistence pool.";
    };
```

- [ ] **Step 2: Verify eval**

Run: `nix eval .#nixosConfigurations.ulysses.config.rat.impermanence.tankDir`
Expected: `"/tank"`.

- [ ] **Step 3: Format and commit**

```bash
nix fmt
git add modules/nixos/impermanence.nix
git commit -m "impermanence: add tank (bulk) persistence root option"
```

---

### Task 5b: Point the bulk dirs at the tank root

Move the seven dirs to a tank-resolved persistence root, falling back to `persistDir` when `tank.enable` is false so hyperion/iserlohn are unaffected. Each of the three modules gains the same `tankRoot` binding.

**Files:**
- Modify: `modules/home-manager/cli/ai.nix`
- Modify: `modules/home-manager/desktop/gaming/default.nix`
- Modify: `modules/home-manager/desktop/gaming/anime-game-launchers.nix`

**Interfaces:**
- Consumes: `osConfig.rat.impermanence.tank.enable`, `.tankDir`, `.persistDir` (Task 5a).

The `tankRoot` binding, added to each file's `let … in` block (they all already bind `impermanenceCfg` and `persistDir`):
```nix
  tankRoot =
    if impermanenceCfg.tank.enable
    then impermanenceCfg.tankDir
    else persistDir;
```

- [ ] **Step 1: `cli/ai.nix`**

Add the `tankRoot` binding (after `inherit (impermanenceCfg) persistDir;`, line 15). Delete `"AI"` and `".cache/huggingface"` from the `home.persistence.${persistDir}` `directories` list, and add a sibling block after that assignment closes:
```nix
    home.persistence.${tankRoot} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        "AI"
        ".cache/huggingface"
      ];
    };
```

- [ ] **Step 2: `desktop/gaming/default.nix`**

Add the `tankRoot` binding (after line 14). Delete `".local/share/Steam"` and `"Games"` from the `home.persistence.${persistDir}` `directories` list (leave `.steam`, `.local/share/bottles`, etc.), and add after that assignment closes:
```nix
    home.persistence.${tankRoot} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        ".local/share/Steam"
        "Games"
      ];
    };
```

- [ ] **Step 3: `desktop/gaming/anime-game-launchers.nix`**

All three dirs move, so just add the `tankRoot` binding (after `inherit (impermanenceCfg) persistDir;`, line 9) and change the persistence root from `persistDir` to `tankRoot` — the `directories` list is unchanged:
```nix
    home.persistence.${tankRoot} = modules.mkIf impermanenceCfg.home.enable {
      directories = [
        ".local/share/anime-game-launcher"
        ".local/share/honkers-railway-launcher"
        ".local/share/sleepy-launcher"
      ];
    };
```

- [ ] **Step 4: Verify the tank root owns exactly the seven dirs**

```bash
nix eval --json .#nixosConfigurations.ulysses.config.home-manager.users.awilliams.home.persistence.\"/tank\".directories \
  --apply 'ds: map (d: d.directory or d) ds' 2>/dev/null
```
Expected: a list of the seven dirs (`AI`, `.cache/huggingface`, `.local/share/Steam`, `Games`, and the three launchers; order may vary).

- [ ] **Step 5: Format and commit**

```bash
nix fmt
git add modules/home-manager/cli/ai.nix modules/home-manager/desktop/gaming/default.nix modules/home-manager/desktop/gaming/anime-game-launchers.nix
git commit -m "home: relocate AI/HF/Steam/Games/launchers persistence to the tank root"
```

---

### Task 5c: Add the tank mount + stage-2 key-load module

**Discovered during execution:** impermanence's NixOS module collects every
`home.persistence` root (not just `environment.persistence`) and hard-asserts
each backing filesystem is `neededForBoot = true` — no per-path opt-out. So
`/tank` must mount in the **initrd**. Since its key lives on `/persist` (itself
`neededForBoot`, mounted at `/sysroot/persist` in the initrd), we import the
pool and load its key in the initrd before the `/tank` mount, mirroring the root
pool. `nofail` bounds the risk: worst case the system boots without `/tank`
rather than hanging.

**Files:**
- Create: `systems/ulysses/tank.nix`
- Modify: `systems/ulysses/default.nix` (add `./tank.nix` to `imports`, lines 6–11)

- [ ] **Step 1: Write `systems/ulysses/tank.nix`**

```nix
{
  config,
  ...
}: {
  # The tank pool is managed manually (created once, out of band) rather than by
  # disko: nixos-rebuild only ever mounts it, never recreates it, so the reserved
  # free space on the same disk (for a later Windows install) stays safe.
  #
  # /tank backs an impermanence persistence root, and impermanence requires every
  # persistence filesystem to be neededForBoot — i.e. mounted in the initrd. The
  # pool's key lives on the (already initrd-mounted) /persist, so we import the
  # pool and load its key in the initrd, before the /tank mount, mirroring how the
  # root pool is unlocked. `nofail` keeps a tank problem from blocking boot: worst
  # case the system comes up without /tank rather than hanging.
  fileSystems."/tank" = {
    device = "tank";
    fsType = "zfs";
    neededForBoot = true;
    options = ["zfsutil" "nofail"];
  };

  boot.initrd.systemd.services.zfs-load-key-tank = {
    description = "Load the tank pool key from /persist (initrd)";
    requiredBy = ["sysroot-tank.mount"];
    before = ["sysroot-tank.mount"];
    after = ["zfs-import-tank.service" "sysroot-persist.mount"];
    unitConfig.DefaultDependencies = "no";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [config.rat.zfs.package];
    script = ''
      zfs load-key -L file:///sysroot/persist/.tank.key tank
    '';
  };

  rat.impermanence.tank.enable = true;
}
```

- [ ] **Step 2: Wire it into ulysses**

In `systems/ulysses/default.nix`, add `./tank.nix` to the `imports` list (lines 6–11), next to `./disko-config.nix`.

- [ ] **Step 3: Build (eval + realise the toplevel, do not activate)**

Run: `nix build .#nixosConfigurations.ulysses.config.system.build.toplevel --no-link 2>&1 | tail -20`
Expected: builds with no errors.

- [ ] **Step 4: Format and commit**

```bash
nix fmt
git add systems/ulysses/tank.nix systems/ulysses/default.nix
git commit -m "ulysses: mount + auto-unlock the tank pool in stage 2"
```

---

### Task 5d: Deploy, reboot, and verify the relocation

**Files:** none (imperative).

- [ ] **Step 1: Deploy at boot-time**

Run: `nix run .#boot`
Expected: builds and sets the boot generation without activating mounts now.

- [ ] **Step 2: Reboot**

The user reboots. At the prompt they enter the **root pool passphrase only** — tank must NOT prompt (it auto-unlocks from `/persist`).

- [ ] **Step 3: Verify auto-unlock, the /tank mount, and the binds**

```bash
zfs get -H -o value keystatus tank                    # expect: available
findmnt /tank                                          # mounted, device tank
systemctl is-active zfs-load-key-tank.service           # active (exited)
for d in AI .cache/huggingface .local/share/Steam Games \
         .local/share/anime-game-launcher .local/share/honkers-railway-launcher \
         .local/share/sleepy-launcher; do
  findmnt "/home/awilliams/$d" >/dev/null && echo "OK bind: $d" || echo "MISSING bind: $d"
done
ls -la ~/AI | head; ls ~/Games | head                  # populated, user-owned
```
Expected: `available`; `/tank` mounted; all seven binds `OK`; `~/AI` and `~/Games` populated and owned by `awilliams`.

- [ ] **Step 4: Confirm persist slimmed and clean up orphaned source dirs**

```bash
zfs list -o name,used,referenced zpool/safe/persist    # expect ~240G
for d in AI .cache/huggingface .local/share/Steam Games \
         .local/share/anime-game-launcher .local/share/honkers-railway-launcher \
         .local/share/sleepy-launcher; do
  sudo rmdir "/persist/home/awilliams/$d" 2>/dev/null || true
done
```
Expected: `safe/persist` ≈ 240 G; leftover empty source dirs removed (ignore errors if already gone or non-empty).

**Phase 1 checkpoint:** the system boots on the Corsair with the bulk on tank. The ~240 G irreplaceable core is now single-copy — proceed promptly to Phase 2.

---

# Phase 2 — Backups (sanoid/syncoid → iserlohn)

### Task 6: Provision the syncoid SSH identity

syncoid runs as its own system user and pushes over SSH to `root@iserlohn`. Give it a dedicated key, stored via SOPS.

**Files:**
- Modify: `secrets/default.yaml` (SOPS)

- [ ] **Step 1: Generate a dedicated keypair (no passphrase)**

```bash
ssh-keygen -t ed25519 -N "" -C "syncoid@ulysses" -f /tmp/claude-1000/scratchpad/syncoid_ed25519
cat /tmp/claude-1000/scratchpad/syncoid_ed25519.pub   # note for Task 8
```

- [ ] **Step 2: Add the private key to SOPS**

Following the existing `secrets/` pattern (see `modules/nixos/sops.nix`), add the private key under a `syncoid/ssh_key` entry:
```bash
sops secrets/default.yaml   # add: syncoid: { ssh_key: "<contents of syncoid_ed25519>" }
```
(Paste the exact contents of `/tmp/claude-1000/scratchpad/syncoid_ed25519`.)

- [ ] **Step 3: Verify it decrypts, then commit**

```bash
sops -d --extract '["syncoid"]["ssh_key"]' secrets/default.yaml | head -1   # -----BEGIN OPENSSH PRIVATE KEY-----
git add secrets/default.yaml
git commit -m "secrets: add syncoid ssh key for ulysses->iserlohn backups"
```

---

### Task 7: Backup module on ulysses (sanoid snapshots + syncoid push)

**Files:**
- Create: `modules/nixos/services/core/backup.nix`
- Modify: `modules/nixos/services/core/default.nix` (add the import if that dir lists files explicitly)
- Modify: `systems/ulysses/default.nix` (`rat.backup.enable = true;`)

**Interfaces:**
- Produces: `rat.backup.enable`; a `syncoid` system user consuming `config.sops.secrets."syncoid/ssh_key".path`.

- [ ] **Step 1: Confirm how `services/core` imports modules**

Run: `sed -n '1,40p' modules/nixos/services/core/default.nix`
Expected: note whether it lists files explicitly (add `./backup.nix`) or globs the directory (no edit needed).

- [ ] **Step 2: Write `modules/nixos/services/core/backup.nix`**

```nix
{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf;
  cfg = config.rat.backup;
  target = "root@iserlohn";
  targetBase = "zfspv-pool/backups/ulysses";
in {
  options.rat.backup.enable = mkEnableOption "sanoid snapshots + syncoid replication to iserlohn";

  config = mkIf cfg.enable {
    # Snapshot the irreplaceable datasets; tank and local/* are excluded.
    services.sanoid = {
      enable = true;
      templates.irreplaceable = {
        hourly = 24;
        daily = 30;
        monthly = 3;
        autosnap = true;
        autoprune = true;
      };
      datasets."zpool/safe/persist".useTemplate = ["irreplaceable"];
      datasets."zpool/safe/hyperion-home".useTemplate = ["irreplaceable"];
    };

    # Push those snapshots to iserlohn. --no-sync-snap: replicate sanoid's
    # snapshots rather than taking syncoid's own.
    services.syncoid = {
      enable = true;
      interval = "*-*-* *:15:00"; # hourly at :15, after sanoid's hourly snap
      sshKey = config.sops.secrets."syncoid/ssh_key".path;
      commonArgs = ["--no-sync-snap"];
      commands."persist" = {
        source = "zpool/safe/persist";
        target = "${target}:${targetBase}/persist";
      };
      commands."hyperion-home" = {
        source = "zpool/safe/hyperion-home";
        target = "${target}:${targetBase}/hyperion-home";
      };
    };

    # syncoid's SSH key must be readable by the syncoid service user.
    sops.secrets."syncoid/ssh_key".owner = config.services.syncoid.user;
  };
}
```

- [ ] **Step 3: Enable on ulysses**

In `systems/ulysses/default.nix`, add `rat.backup.enable = true;`.

- [ ] **Step 4: Build**

Run: `nix build .#nixosConfigurations.ulysses.config.system.build.toplevel --no-link 2>&1 | tail -20`
Expected: builds; `services.syncoid.user` resolves (default `syncoid`).

- [ ] **Step 5: Format and commit**

```bash
nix fmt
git add modules/nixos/services/core/backup.nix modules/nixos/services/core/default.nix systems/ulysses/default.nix
git commit -m "backup: sanoid snapshots + syncoid push of safe/* to iserlohn"
```

---

### Task 8: iserlohn receive side — authorized key + target retention

**Files:**
- Create: `systems/iserlohn/backup-target.nix`
- Modify: `systems/iserlohn/default.nix` (add to `imports`)

- [ ] **Step 1: Inspect iserlohn's structure for where SSH keys / modules live**

Run: `ls systems/iserlohn/; grep -rn "authorizedKeys\|openssh.authorizedKeys\|users.users.root" systems/iserlohn modules/nixos | head`
Expected: identify the idiomatic spot for a root authorized key and module imports.

- [ ] **Step 2: Create `systems/iserlohn/backup-target.nix`**

```nix
{...}: {
  # Accept syncoid pushes from ulysses (dedicated key; see secrets syncoid/ssh_key).
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAA... syncoid@ulysses" # <-- paste from Task 6 Step 1
  ];

  # Prune the replicated copies with a longer retention than the source.
  services.sanoid = {
    enable = true;
    templates.received = {
      hourly = 0;
      daily = 30;
      monthly = 6;
      yearly = 1;
      autosnap = false; # snapshots arrive via syncoid; only prune here
      autoprune = true;
    };
    datasets."zfspv-pool/backups/ulysses/persist" = {
      useTemplate = ["received"];
      recursive = true;
    };
    datasets."zfspv-pool/backups/ulysses/hyperion-home".useTemplate = ["received"];
  };
}
```
Paste the actual pubkey from Task 6 Step 1 in place of the placeholder.

- [ ] **Step 3: Import it in `systems/iserlohn/default.nix`**

Add `./backup-target.nix` to iserlohn's `imports`.

- [ ] **Step 4: Build iserlohn, format, commit**

```bash
nix build .#nixosConfigurations.iserlohn.config.system.build.toplevel --no-link 2>&1 | tail -20
nix fmt
git add systems/iserlohn/backup-target.nix systems/iserlohn/default.nix
git commit -m "iserlohn: accept syncoid pushes from ulysses + prune received backups"
```

---

### Task 9: Deploy both hosts, run the first sync, verify

**Files:** none (imperative).

- [ ] **Step 1: Deploy iserlohn (receive side first)**

Run: `nix run .#switch iserlohn`
Expected: succeeds; the syncoid pubkey is now in `root`'s authorized keys.

- [ ] **Step 2: Deploy ulysses**

Run: `nix run .#switch`
Expected: succeeds; `sanoid.timer` and `syncoid-*` units exist.

- [ ] **Step 3: Confirm sanoid took the first snapshots**

```bash
sudo systemctl start sanoid.service
zfs list -t snapshot -r zpool/safe | grep -c autosnap
```
Expected: nonzero snapshot count under `zpool/safe`.

- [ ] **Step 4: Trigger the first replication (~1 h transfer over 1 GbE)**

```bash
sudo systemctl start syncoid-persist.service
sudo systemctl start syncoid-hyperion-home.service
journalctl -u syncoid-persist.service -n 20 --no-pager
```
Expected: syncoid runs without SSH/auth errors; progresses through a full send.

- [ ] **Step 5: Verify the datasets landed on iserlohn**

```bash
ssh iserlohn 'zfs list -r zfspv-pool/backups/ulysses; \
  zfs list -t snapshot -r zfspv-pool/backups/ulysses/persist | tail -3'
```
Expected: `persist` (~240 G) and `hyperion-home` (~112 G) present with replicated snapshots.

- [ ] **Step 6: Confirm the timers will keep them current**

Run: `systemctl list-timers 'syncoid*' 'sanoid*' --no-pager`
Expected: both timers scheduled.

**Phase 2 complete:** the irreplaceable core now has an off-box copy on iserlohn, refreshed hourly. The single-copy risk window is closed. The Samsung's ~0.9 TiB reserved space remains free for a later Windows install (separate effort).

---

## Self-review notes

- **Spec coverage:** §1 Samsung layout → Tasks 3; §2 single-dataset tank → Tasks 3, 5c; §3 impermanence second root (7 dirs, 3 modules) → Tasks 5a/5b; §4 disko reconcile → Task 2; §5 backups → Tasks 6–9; §6 stage-2 key-load → Task 5c; execution order → Phase 1 then Phase 2; success criteria → Tasks 5d, 9.
- **No placeholders** except the intentionally-pasted syncoid pubkey (Task 8) and the SOPS private-key value (Task 6), which are runtime-generated secrets.
- **Type consistency:** `rat.impermanence.tank.enable`/`tankDir` defined in 5a, consumed in 5b/5c; `rat.backup.enable` defined and consumed in Task 7; single `tank` dataset consistent across Tasks 3, 4, 5c; the seven-dir list identical in Global Constraints, Task 4, Task 5b/5d.

---

## As-built deviations & lessons

The committed code is the source of truth; these are where execution diverged
from the tasks above and the gotchas worth remembering.

### Phase 2 was hardened beyond the original plan

Tasks 6–8 as written used a flat `root@iserlohn` push with a plain (decrypting)
send. Both were changed:

- **Raw encrypted send.** `zfspv-pool` is unencrypted, so a plain send would
  store the irreplaceable data as cleartext on iserlohn. syncoid commands set
  `sendOptions = "w"` (raw) + `recvOptions = "u"` (never mount the keyless
  received dataset). The backup is ciphertext at rest; iserlohn can't read it.
- **Delegated unprivileged receiver, not root.** `systems/iserlohn/backup-target.nix`
  creates a dedicated `syncoid` system user (not root) holding the authorized
  key, plus a `syncoid-target-delegate` oneshot that creates the per-host parent
  dataset (`zfs create -p -o mountpoint=none zfspv-pool/backups/ulysses`) and
  runs `zfs allow -u syncoid change-key,compression,create,destroy,hold,mount,mountpoint,receive,release,rollback,bookmark <subtree>`.
  The key is receive-only into that one subtree.
- **Per-host, generic module.** `backup.nix` derives the key path
  (`syncoid/<host>/ssh_key`), target base (`zfspv-pool/backups/<host>`), and
  syncoid commands from `networking.hostName` + a `rat.backup.datasets` option,
  so a new source host just enables `rat.backup` and gets its own key + subtree.
  The SOPS secret lives at `syncoid/ulysses/ssh_key` (not the flat
  `syncoid/ssh_key`).
- **Transport helpers.** `mbuffer` + `lzop` added to `environment.systemPackages`
  on both ends (syncoid resolves them via the booted-system path / the receiver's
  SSH-command PATH). lzop is a near-no-op on raw-encrypted streams; mbuffer
  smooths throughput.

### Lesson: chown tank's intermediate parent dirs during relocation

Task 4 Step 3 created tank parent dirs with `sudo mkdir -p`, leaving the
structural intermediates (`/tank/home/awilliams`, `.cache`, `.local`,
`.local/share`) **root-owned**. impermanence propagates the source parent's
ownership onto the home mountpoint parent, so `~/.cache` and `~/.local` became
root-owned on every activation. Fix: after the rsyncs, chown the intermediate
dirs to the user (not just the leaf data dirs):
`chown awilliams:users /tank/home/awilliams{,/.cache,/.local,/.local/share}` and
`chmod 700 /tank/home/awilliams`.

### Lesson: don't `systemctl restart` syncoid mid-receive

Restarting syncoid while a receive is in flight races the remote `zfs receive`
lock ("… is already target of a zfs receive process"). Instead `stop`, let the
remote recv wind down (a resume token remains on the target), then `start` — it
resumes from the token, no progress lost.
