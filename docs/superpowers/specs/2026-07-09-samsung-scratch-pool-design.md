# Samsung Scratch Pool (ulysses)

**Status:** approved, not yet executed
**Gated on:** `2026-07-09-corsair-nvme-migration-design.md` landed and proven.

Spec 2 of 3. Repartition the Samsung, build an encrypted scratch pool, move ~1.16 TiB of re-downloadable bulk data off the root pool, and reserve space for Windows (built in spec 3).

## Why this is severed from spec 1

To put `~/AI` on the Samsung, the Samsung must be wiped — which destroys `zpool-old`, the intact fallback copy of the system created in spec 1 Phase 4. **Starting this spec destroys the fallback.** It must not begin until the Corsair has been running clean for long enough to trust.

Within this spec the data itself is never at risk: copy 1.16 TiB across, verify, and only then delete the originals. There is no single-copy window for the moved data.

## What moves, and the payoff

```
/home/awilliams/AI                  607G
/home/awilliams/Games               266G
/home/awilliams/.local/share/Steam  314G
                                   -----
                                  1187G ≈ 1.16 TiB
```

`findmnt` shows these are bind mounts of *directories inside* `zpool/safe/persist`, not datasets. There is no dataset boundary, so the move is `rsync`, not `zfs send`.

`/persist` is 1.92T. Removing 1.16 TiB of re-downloadable game and model-weight data leaves roughly **760G of genuinely irreplaceable data** — the difference between "backing this up is a project" and "backing this up is a weekend." Given that `/persist` currently has **no backup at all**, this is the real payoff, beyond freeing space on the fast drive.

## Samsung layout

Check 4Kn support first, exactly as with the Corsair — the drive is being wiped anyway, so it is free:

```bash
nvme id-ns /dev/nvme1n1 -H | grep -i 'lba format'
# if a 4096-byte format exists, use it:
nvme format /dev/nvme1n1 --lbaf=<n> --force
```

Then, after `zpool destroy zpool-old`:

| # | Label | Size | Type | Purpose |
|---|---|---|---|---|
| 1 | `win-esp` | 1 GiB | `EF00` | Windows' own ESP (spec 3) |
| 2 | `win-msr` | 16 MiB | `0C01` | Microsoft Reserved |
| 3 | `win-data` | 512 GiB | `0700` | Windows + Forza Horizon 6 |
| 4 | `scratch` | remainder ≈ 3.1 TiB | `BF00` | ZFS scratch pool |

All four partitions are created **now**, in one pass. Windows Setup is never allowed to create partitions — it installs *into* the existing `win-data`, using the existing `win-esp`. Partitions 1–3 sit empty until spec 3.

512 GiB for Windows: ~80 GiB for Windows 11, ~150–200 GiB for FH6, the rest headroom. Nothing else will ever live there.

## Scratch pool

Encrypted with a **raw keyfile on `/persist`**, so it unlocks automatically once the root pool is up — no second passphrase prompt. The root pool is itself encrypted, so the key is not sitting in the clear.

```bash
install -d -m 700 /persist/etc/zfs
dd if=/dev/urandom of=/persist/etc/zfs/scratch.key bs=32 count=1
chmod 400 /persist/etc/zfs/scratch.key

zpool create -o ashift=12 -o autotrim=on \
  -O encryption=aes-256-gcm \
  -O keyformat=raw -O keylocation=file:///persist/etc/zfs/scratch.key \
  -O compression=lz4 -O atime=off -O xattr=sa -O acltype=posixacl \
  -O mountpoint=none \
  scratch /dev/disk/by-partlabel/scratch
```

Datasets, each `recordsize=1M`:

| Dataset | Mountpoint |
|---|---|
| `scratch/ai` | `/scratch/home/awilliams/AI` |
| `scratch/games` | `/scratch/home/awilliams/Games` |
| `scratch/steam` | `/scratch/home/awilliams/.local/share/Steam` |

`recordsize=1M` suits large sequential files. `compression=lz4` rather than `zstd`: model weights (`safetensors`) and game assets are already compressed, so zstd would burn CPU for nothing, while lz4's early-abort heuristic makes it effectively free. `atime=off` avoids a write per read.

These datasets are **not snapshotted and not backed up, by design.** Everything on them is re-downloadable. That is the entire reason they are being separated from `/persist`.

### Unlock and mount ordering — the main implementation risk

The key lives on `/persist`, so `zfs load-key scratch` cannot run in initrd before the root pool is unlocked, and the scratch mounts must not be attempted before the key is loaded. Additionally, impermanence's bind mounts for `~/AI` et al. must be ordered *after* the scratch datasets are mounted.

Sketch: `boot.zfs.extraPools = [ "scratch" ]`, a `zfs-load-key-scratch` systemd service ordered before the scratch `fileSystems` entries, and the impermanence bind mounts ordered after those. **The exact unit ordering is to be resolved during implementation, not assumed here.** A wrong order fails at boot, so it warrants a deliberate test with `systemd-analyze critical-chain`.

## Impermanence rewiring

The three directories are declared across scattered modules, each writing into `home.persistence.${persistDir}`:

- `modules/home-manager/cli/ai.nix` → `"AI"`
- `modules/home-manager/desktop/gaming/default.nix` → `"Games"`, `".local/share/Steam"`

Hardcoding `/scratch` in those modules would break `hyperion` and `iserlohn`, which have no scratch pool. Instead, add to `modules/nixos/impermanence.nix`:

```nix
scratchDir = mkOption {
  type = types.nullOr types.str;
  default = null;
  description = "Pool for bulk, re-downloadable data. Falls back to persistDir when unset.";
};
```

Consumers resolve `bulkDir = if scratchDir != null then scratchDir else persistDir` and declare into `home.persistence.${bulkDir}`. Hosts without a scratch pool are unaffected; `ulysses` sets `rat.impermanence.scratchDir = "/scratch"`.

`.steam` (small — config and symlinks into the library) stays on `/persist`. Only `.local/share/Steam` moves.

## Data move

Per directory, in order, one at a time:

```bash
rsync -aHAX --numeric-ids --info=progress2 \
  /persist/home/awilliams/AI/ /scratch/home/awilliams/AI/

# verify before deleting anything
rsync -aHAXn --checksum --itemize-changes \
  /persist/home/awilliams/AI/ /scratch/home/awilliams/AI/    # must print nothing
```

Only after the checksum pass is silent, and after a reboot confirms the new bind mount resolves to the scratch dataset, delete the original from `/persist`.

**Gate:** never delete a source directory in the same session it was copied. Reboot, confirm `findmnt ~/AI` points at `scratch/ai`, confirm the contents, *then* remove.

## Follow-on (not this spec)

With `/persist` down to ~760G, a real backup becomes tractable. `sanoid` for local snapshots plus `syncoid` to `iserlohn` is the obvious shape, and `zpool/safe` already carries the `com.sun:auto-snapshot=true` tag that nothing currently consumes. Worth its own spec.

## Rollback

Once `zpool destroy zpool-old` runs, the spec-1 fallback is gone and the Corsair is the only copy. Before that command, everything here is reversible by walking away. After it, recovery depends on the Corsair alone — which is precisely why this spec waits.
