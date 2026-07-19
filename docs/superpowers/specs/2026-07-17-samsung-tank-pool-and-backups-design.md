# Samsung tank pool + bulk relocation + backups — design

**Host:** ulysses · **Date:** 2026-07-17

## Context

The root pool migration (Samsung 990 EVO Plus → Corsair MP700 PRO XT) is
complete: the live system runs on the Corsair (`zpool` on
`nvme-Corsair_MP700_PRO_XT_AD27B6108002KO`, ESP 4G / swap 8G / root rest). The
Samsung still holds the pre-migration copy as an *exported* fallback (`old-esp`
/ `old-root` / `old-swap`); it is no longer imported and no longer a live
safety net.

Three things follow from that state, and this spec covers all three as one unit
of work:

1. Repurpose the Samsung as an encrypted **tank** pool for re-downloadable
   bulk data, leaving space for a later Windows install.
2. **Relocate** the re-downloadable bulk off the backed-up root onto tank,
   shrinking the irreplaceable working set.
3. Stand up **sanoid/syncoid** backups of the now-slim irreplaceable data to
   iserlohn — the backups that make wiping the Samsung fallback acceptable.

It also folds in the still-pending **disko reconcile**: the checked-in
`systems/ulysses/disko-config.nix` still declares `disk.main` on the Samsung,
which no longer matches reality.

### Current measured state

| Item | Value |
| --- | --- |
| Corsair (root) `disk.main` | `nvme-Corsair_MP700_PRO_XT_AD27B6108002KO` — p1 `disk-main-ESP` 4G vfat `/boot`, p2 `disk-main-swap` 8G, p3 `disk-main-root` rest (zfs `zpool`) |
| Samsung (to wipe) | `nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NU0YA00669D` — `old-esp` 1G / `old-root` 3.6T / `old-swap` 8G, exported |
| `safe/persist` | 1.65T (→ ~240G after relocation) |
| `safe/hyperion-home` | 118G |
| Bench garbage to destroy | `zpool/local/bench1m` 160G · `zpool/local/bench4k` 65.9G (no snapshots) |
| Backup target | iserlohn `zfspv-pool` — 14.2T free |
| Link | ulysses ↔ iserlohn 1 GbE (~110 MB/s) |

### Dirs to relocate (all re-downloadable, ~1.38 TiB total)

| Home dir | Size | Declared in |
| --- | --- | --- |
| `~/AI` | 692G | `modules/home-manager/cli/ai.nix` |
| `~/.cache/huggingface` | 44G | `modules/home-manager/cli/ai.nix` |
| `~/.local/share/Steam` | 314G | `modules/home-manager/desktop/gaming/default.nix` |
| `~/Games` | 266G | `modules/home-manager/desktop/gaming/default.nix` |
| `~/.local/share/honkers-railway-launcher` | 99G | `modules/home-manager/desktop/gaming/anime-game-launchers.nix` |
| `~/.local/share/anime-game-launcher` | ~0 | `…/anime-game-launchers.nix` (empty; moved so a future install lands on tank) |
| `~/.local/share/sleepy-launcher` | ~0 | `…/anime-game-launchers.nix` (empty; same) |

## Scope

**In:** the tank pool, the bulk relocation, the sanoid/syncoid backup module,
and the disko reconcile of `disk.main` to the Corsair.

**Out:** the Windows install itself — we only reserve unpartitioned space for it.
Tank data and ephemeral data (`local/*`) are never backed up.

## Design

### 1. Samsung layout (manual, not disko)

```
GPT on nvme-Samsung_SSD_990_EVO_Plus_4TB_...
  p1  tank            ~3.0 TB (≈2.7 TiB)   ZFS pool "tank"
  p2  [unallocated]   ~0.9 TB              reserved → Windows installs here later
```

The tank pool is **created once, manually** (GPT wipe + `zpool create`), and is
deliberately **not modelled in disko** — its key lives on the encrypted
`/persist` (see §2), which needs stage-2 ordering that disko does not express
cleanly. `nixos-rebuild` only ever *mounts* tank via a hand-written module
(§2/§6), never recreates it, so the reserved free space for a later Windows
install is safe as long as no destructive disko run ever targets the Samsung.

Current ~1.38 TiB of bulk against ~2.7 TiB tank leaves comfortable headroom.

### 2. Tank pool — one dataset

A **single dataset** (the pool root) mounts at `/tank`; every relocated dir
lives under `/tank/home/awilliams/…`. One dataset, not one-per-dir, because the
dirs share identical properties (uniform `recordsize=1M`, no snapshots) and are
re-downloadable, so per-dataset tuning/snapshot/destroy buys nothing — while a
single dataset means one boot mount and, decisively, **adding a future dir needs
only a one-line impermanence edit, no pool or nix-module change.**

- Pool `tank`, encryption root = `tank`, `mountpoint=/tank`, `canmount=noauto`
  (mounted by the module in §6, not auto-mounted).
- `ashift=12`, `autotrim=on`, `atime=off`, `recordsize=1M`,
  `compression=lz4`, `acltype=posixacl`, `xattr=sa`, `normalization=formD`.
- Encryption `aes-256-gcm`, `keyformat=passphrase`,
  `keylocation=file:///persist/.tank.key`. Because the key lives on the
  already-encrypted `/persist`, tank **cannot** import/unlock in initrd like the
  root pool — it loads its key in **stage 2**, ordered after `/persist` is
  mounted (§6).

### 3. Impermanence — a second persistence root

The bulk dirs persist today as home-manager impermanence bind-mounts from
`/persist/home/awilliams/…`. Use impermanence's native multi-root support so
`/tank` is an honest, separate persistence root; the bind `.mount` units resolve
`RequiresMountsFor` to the single `/tank` mount.

New nixos options on `rat.impermanence`:

- `tank.enable` (bool, per-host; only ulysses sets it true)
- `tankDir` (str, default `/tank`)

The three home-manager modules that declare the bulk dirs move them from the
`/persist` root to a `tankRoot` that resolves to `tankDir` when `tank.enable`
else `persistDir` (so hyperion/iserlohn are unaffected):

- `cli/ai.nix` — `"AI"`, `".cache/huggingface"`
- `desktop/gaming/default.nix` — `".local/share/Steam"`, `"Games"` (`.steam`
  and the smaller gaming state dirs stay on `/persist`)
- `desktop/gaming/anime-game-launchers.nix` — its whole list
  (`anime-game-launcher`, `honkers-railway-launcher`, `sleepy-launcher`)

No tmpfiles rule is needed for tank: `/tank/home/awilliams` and its subdirs live
inside the dataset (created during relocation), and impermanence `mkdir -p`s any
not-yet-existing source dir when it sets up a bind. Tank sits cleanly **outside**
`safe/persist`, so the persist backup can never traverse into it.

### 4. disko reconcile of `disk.main`

Update `systems/ulysses/disko-config.nix` `disk.main` to match the live Corsair:

- `device` → `/dev/disk/by-id/nvme-Corsair_MP700_PRO_XT_AD27B6108002KO`
- partition order/sizes → `ESP` 4G → `swap` 8G → `root` 100% (attr-key order
  ESP/swap/root reproduces the live partlabels `disk-main-ESP` /
  `disk-main-swap` / `disk-main-root`)

The `zpool` block is unchanged. Non-destructive: `nixos-rebuild` consumes only
the generated `fileSystems` (all by-partlabel), which are identical before and
after.

### 5. Backups (net-new sanoid/syncoid module)

A new host-generic NixOS module (`modules/nixos/services/core/backup.nix`,
`rat.backup.*`) enabled on ulysses. Everything keys off `networking.hostName` so
more source hosts can be added by just enabling it + generating their key:

- **sanoid** on ulysses snapshots `rat.backup.datasets` (default
  `["zpool/safe/persist"]`; ulysses adds `zpool/safe/hyperion-home`, ~240G +
  118G ≈ **~360G**), 24 hourly / 30 daily / 3 monthly. `local/*` and `tank` are
  excluded.
- **syncoid** (systemd timer, hourly) pushes to
  `zfspv-pool/backups/<host>/<dataset>` on iserlohn.
- First sync ≈ 1 h over 1 GbE; incrementals thereafter are small.

**Encrypted at rest — raw send.** `zfspv-pool` is *unencrypted*, so a plain send
would land the irreplaceable data (SSH keys, the sops age key, …) as cleartext
on iserlohn. syncoid uses `--sendoptions=w` (raw): iserlohn stores the
already-encrypted blocks and cannot read them without the passphrase.
`--recvoptions=u` keeps the keyless received datasets from ever mounting.

**Least-privilege receiver — not root.** Instead of `root@iserlohn`, a dedicated
unprivileged `syncoid` user on iserlohn holds the authorized key, with
`zfs allow` scoped to the `zfspv-pool/backups/<host>` subtree only
(`create,receive,rollback,destroy,hold,…`). A oneshot service creates the
per-host parent dataset (`mountpoint=none`) and applies the delegation. So the
key can only receive ciphertext into one subtree — no root, no wider access.

**Keys.** Per-host: `syncoid/<host>/ssh_key` in SOPS, decrypted for the syncoid
service user on the source. **Transport:** `mbuffer` + `lzop` are provided on
both ends (lzop is a near-no-op on raw-encrypted streams; mbuffer smooths
throughput). **Retention on iserlohn:** sanoid prunes the replicated copies
(`autosnap = false`) with a longer policy; it can prune the keyless encrypted
datasets without the key.

### 6. Stage-2 tank key-load + mount

A hand-written `systems/ulysses/tank.nix`:

- `boot.zfs.extraPools = ["tank"]` imports the pool at boot.
- `zfs-load-key-tank.service` (oneshot): ordered after `/persist` is mounted
  (`RequiresMountsFor=/persist`) and `zfs-import.target`; `mkdir -p /tank`; loads
  the key (idempotent) from `/persist/.tank.key`.
- One `fileSystems."/tank"` entry (`device=tank`, `fsType=zfs`, options
  `zfsutil,nofail,x-systemd.requires=…,x-systemd.after=zfs-load-key-tank.service`)
  mounts the dataset after the key is loaded; the impermanence bind `.mount`
  units then order after `/tank` via `RequiresMountsFor`.
- Sets `rat.impermanence.tank.enable = true`.

## Execution order

"Wipe first, slim backup after." The ~240G irreplaceable core is single-copy
(new, healthy Corsair only) from the Samsung wipe until the first sync lands.

1. **Destroy bench garbage** (~226G reclaimed).
2. **Build tank** — GPT + `zpool create tank` on the Samsung by-id (single
   dataset), write `/persist/.tank.key`, mount at a temp path.
3. **Relocate** — with Steam/launchers quiescent, `rsync -aH` each of the seven
   dirs into `/tank/home/awilliams/…`; verify.
4. **Slim persist** — delete the sources (reclaims ~1.38 TiB).
5. **Repoint + config** — set tank `mountpoint=/tank canmount=noauto`; land the
   disko reconcile, `tank.enable`, moved persistence decls, and `tank.nix`;
   `nixos-rebuild boot`; reboot; verify auto-unlock and binds.
6. **Backups** — land the sanoid/syncoid module; first sync (~1 h); verify on
   iserlohn. Risk window closes here.

## Safety constraints

- All destructive/device operations use `/dev/disk/by-id/…` or
  `/dev/disk/by-partlabel/…`, never `/dev/nvmeXnY`.
- Do not begin the Samsung wipe until ready to proceed through the backup.
- Never re-run `disko` destructively against the Samsung once Windows occupies
  its free space.
- Verify each `rsync` before deleting any source.

## Success criteria

- All seven dirs are backed by `tank`, survive a reboot, and tank auto-unlocks
  with no extra passphrase prompt.
- `safe/persist` is ~240G; `du /persist` no longer includes the bulk.
- `disko-config.nix` `disk.main` matches the live Corsair.
- sanoid snapshots exist on ulysses and are replicated under
  `zfspv-pool/backups/ulysses/…` on iserlohn.
- ~0.9 TB of unpartitioned space remains on the Samsung for Windows.
