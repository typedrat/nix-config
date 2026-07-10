# Secure Boot + Windows Dual-Boot (ulysses)

**Status:** approved, not yet executed
**Gated on:** `2026-07-09-samsung-scratch-pool-design.md` (Windows needs the `win-esp` / `win-msr` / `win-data` partitions it creates).

Spec 3 of 3. Enable Secure Boot on Limine, then install Windows 11 to the Samsung for the Forza Horizon 6 custom-livery tool, which cannot work under Linux due to process-isolation constraints on the injector.

## Bootloader decision: stay on Limine

The stated intent was "flip the switch on lanzaboote." Two findings override that:

1. **`ulysses` is already staged for *Limine* Secure Boot, not lanzaboote.** `systems/ulysses/default.nix` sets `rat.boot.loader = "limine"` with `limine.secureBoot.validateChecksums = true` and `enrollConfig = true`. The only missing line is `enable = true`.
2. **Lanzaboote structurally forbids the layout wanted here.** From `modules/nixos/boot/default.nix`:
   ```
   assertion = cfg.windows.efiDeviceHandle == null;
   message = "... must be null for lanzaboote - Windows must be on the same ESP";
   ```
   Windows is going on the **Samsung**, with its own ESP. Lanzaboote would force it onto the **Corsair's** ESP. Limine's `windows.efiPartition = "guid(…)"` chainloads an arbitrary partition, which is exactly the requirement.

Limine + Secure Boot is the only combination in this repo's own module set that supports Windows on a separate drive.

Note the module's other assertion: `autoEnrollKeys` is **not supported** with Limine. Keys are enrolled manually with `sbctl`.

## Ordering: Secure Boot first, alone

Secure Boot and the disk migration are both "the machine might not come up" events. They are serialized across specs so that a failure identifies its own cause. Within *this* spec the same rule applies: **enable Secure Boot and prove Linux still boots with video before Windows installation media is ever inserted.**

## Phase 1 — Secure Boot

```bash
sbctl create-keys
sbctl enroll-keys --microsoft     # ← the --microsoft flag is not optional here
```

Then in `systems/ulysses/default.nix`:

```nix
limine.secureBoot = {
  enable = true;              # the switch
  validateChecksums = true;
  enrollConfig = true;
};
```

`nixos-rebuild boot`, then enable Secure Boot in firmware (the firmware must be in Setup Mode for enrollment to have succeeded).

### Why `--microsoft` is mandatory

Enrolling only custom keys is the default advice for a machine with no Windows and integrated graphics. Neither applies here.

1. Windows' `bootmgfw.efi` is Microsoft-signed. Limine chainloads it, but *firmware* verifies it against `db`. Without Microsoft's certificates, the Windows entry cannot boot.
2. **The RTX 5090's option ROM is signed by the "Microsoft UEFI CA 2011" third-party CA.** With Secure Boot on and only custom keys in `db`, firmware can refuse to execute the GPU's GOP driver, producing **no display output** — on a machine that then cannot be seen in order to fix it.

This is the standard `sbctl` / NixOS-wiki warning for discrete GPUs, and a 5090 is squarely in scope.

**Recovery if it happens anyway:** the Ryzen 9 9950X3D has integrated graphics. Firmware setup renders on the iGPU regardless of the kernel-level `amdgpu` blacklist, so moving the monitor to a motherboard display output restores access to the firmware menu, where Secure Boot can be turned back off. Failing that, clear CMOS.

**Gate:** reboot. `sbctl status` reports Secure Boot enabled and all files signed; the machine has video on the 5090; `bootctl status` shows Secure Boot enabled. **Do not proceed to Phase 2 until all three hold.**

## Phase 2 — Verify Windows is needed at all

**Secure Boot is resolved.** FH6's anti-cheat runs under Proton, which means it loads no kernel driver and therefore performs no boot attestation. It does not read Secure Boot state, and a custom PK is invisible to it. Windows will report `SecureBootEnabled = true` regardless, since `bootmgfw.efi` remains Microsoft-signed and verified against the enrolled Microsoft certificates.

That resolution raises a sharper question. If the anti-cheat runs under Proton, **the game already runs on Linux**, and this entire spec exists to host one tool: the custom-livery injector.

Before building it, test the injector **inside the game's own Proton prefix**:

```bash
protontricks-launch --appid <fh6-appid> LiveryTool.exe
```

The reported blocker — "stronger process isolation" — is real for a Win32 injector calling `OpenProcess` / `WriteProcessMemory` against a *different* prefix, or against a native Linux process (Yama `ptrace_scope`). It does **not** hold inside a single prefix: processes sharing a `wineserver` share a Windows-side process namespace, and those calls are serviced by wineserver, not the Linux kernel. This is the standard mechanism by which mod injectors work under Proton, and it is the specific failure mode that same-prefix launching fixes.

If it works, **abandon this spec** and reclaim the `win-*` partitions into the scratch pool. Twenty minutes here is weighed against 512 GiB, a dual-boot, and permanent Secure Boot key management.

Residual wrinkle if Windows is built anyway: chainloading `bootmgfw.efi` from Limine yields different TPM PCR measurements than a direct firmware boot. This is harmless with BitLocker disabled (see Phase 3), but would cause recovery-key prompts otherwise.

## Phase 3 — Windows installation

**Physically disconnect the Corsair.** Windows Setup writes its bootloader into the first ESP it finds and reorders firmware boot entries. Disconnecting the drive is faster and more reliable than repairing afterward.

- Install to the existing `win-data` partition. **Do not let Setup create or resize partitions.** It should use the existing `win-esp` and `win-msr`.
- Secure Boot is enabled and TPM 2.0 is present, so the Windows 11 hardware check passes with no bypass required.
- **Decline / disable BitLocker.** Windows 11 auto-encrypts on some paths; a TPM-sealed volume that later sees a changed boot chain becomes a recovery-key prompt.
- **Disable Fast Startup.** It leaves NTFS in a dirty hibernated state that Linux will refuse to mount cleanly (`boot.supportedFilesystems = ["ntfs"]` is already set).
- Set the RTC to UTC so the clock does not fight NixOS:
  ```
  reg add "HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation" /v RealTimeIsUniversal /t REG_DWORD /d 1 /f
  ```

Reconnect the Corsair. Check the firmware boot order still prefers it; `efibootmgr -o` if Windows displaced it.

## Phase 4 — Chainload entry

Get the `win-esp` partition GUID:

```bash
sgdisk -i 1 /dev/nvme1n1 | grep 'unique GUID'
```

In `systems/ulysses/default.nix`:

```nix
rat.boot.windows = {
  enable = true;
  efiPartition = "guid(<win-esp partition GUID>)";
  # efiPath defaults to /EFI/Microsoft/Boot/bootmgfw.efi
};
```

`efiDeviceHandle` stays `null` — it is systemd-boot-only, and the module asserts on it.

**Gate:** the Limine menu shows a Windows entry, it boots, and NixOS still boots. Confirm FH6 and the livery tool both run.

## Risks

| Risk | Mitigation |
|---|---|
| No video after enabling Secure Boot | `--microsoft` at enrollment; iGPU display output as recovery; CMOS clear |
| Windows clobbers the Corsair ESP | Corsair physically disconnected during install |
| Windows Update overwrites its ESP | Isolated on `win-esp`; the Corsair ESP is never mounted by Windows |
| FH6 anti-cheat rejects the setup | Resolved: runs under Proton, so no kernel driver, no boot attestation |
| Windows built unnecessarily | Phase 2 tests the injector in-prefix first; if it works, this spec is void |
| NTFS unmountable from Linux | Fast Startup disabled |
| Clock skew between OSes | `RealTimeIsUniversal=1` |

## Rollback

Secure Boot is a firmware toggle plus one Nix option; both revert cleanly, and `sbctl` key enrollment is undone by clearing keys in firmware. Windows is confined to `win-*` partitions on the Samsung and touches nothing on the Corsair. The Limine Windows entry is one option away from disappearing.
