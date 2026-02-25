#!/usr/bin/env python3
"""Extract Apple Color Emoji.ttc from a macOS InstallAssistant.pkg.

Extraction chain:
  InstallAssistant.pkg (xar archive)
    -> SharedSupport.dmg (HFS+ disk image)
      -> <hash>.zip (~17GB, largest file)
        -> AssetData/payloadv2/payload.{000..050} (pbzx-compressed chunks)
          -> concatenated Apple Archive (YAA)
            -> neoaa unwrap -> Apple Color Emoji.ttc
"""

import argparse
import lzma
import shutil
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

FONT_PATH = "System/Library/Fonts/Apple Color Emoji.ttc"
PBZX_MAGIC = b"pbzx"


def run(cmd: list[str], cwd: Path | None = None) -> None:
    print(f"  $ {' '.join(cmd)}", file=sys.stderr)
    subprocess.run(cmd, check=True, cwd=cwd)


def extract_xar(pkg: Path, workdir: Path) -> Path:
    """Extract SharedSupport.dmg from the InstallAssistant.pkg xar archive."""
    print("Step 1: Extracting SharedSupport.dmg from pkg...", file=sys.stderr)
    run(["xar", "-xf", str(pkg), "SharedSupport.dmg"], cwd=workdir)
    dmg = workdir / "SharedSupport.dmg"
    if not dmg.exists():
        sys.exit("Error: SharedSupport.dmg not found in pkg")
    return dmg


def extract_dmg(dmg: Path, workdir: Path) -> Path:
    """Extract the large zip from SharedSupport.dmg using 7zz."""
    print("Step 2: Extracting zip from SharedSupport.dmg...", file=sys.stderr)
    run(["7zz", "e", str(dmg), "-o" + str(workdir)], cwd=workdir)

    # Find the extracted zip (largest .zip file)
    zips = sorted(workdir.glob("*.zip"), key=lambda p: p.stat().st_size, reverse=True)
    if not zips:
        sys.exit("Error: No zip file found in SharedSupport.dmg")
    print(
        f"  Found: {zips[0].name} ({zips[0].stat().st_size / (1024**3):.1f} GB)",
        file=sys.stderr,
    )
    return zips[0]


def extract_payloads(zipfile: Path, workdir: Path) -> list[Path]:
    """Extract payload chunks from the zip."""
    print("Step 3: Extracting payload chunks from zip...", file=sys.stderr)
    run(
        [
            "7zz",
            "e",
            str(zipfile),
            "AssetData/payloadv2/payload.*",
            "-x!*.ecc",
            "-o" + str(workdir),
        ],
        cwd=workdir,
    )

    # Filter out .ecc files (7zz exclusion isn't always reliable)
    payloads = sorted(
        p for p in workdir.glob("payload.*") if not p.suffix == ".ecc"
    )
    for ecc in workdir.glob("payload.*.ecc"):
        ecc.unlink()
    if not payloads:
        sys.exit("Error: No payload chunks found in zip")
    print(f"  Found {len(payloads)} payload chunks", file=sys.stderr)
    return payloads


def decompress_pbzx(payloads: list[Path], output: Path) -> None:
    """Decompress pbzx-encoded payload chunks into an Apple Archive (YAA).

    pbzx format per chunk file:
      - 4 bytes: magic "pbzx"
      - 8 bytes: chunk size (big-endian uint64)
      - Repeating blocks:
        - 8 bytes: uncompressed size (big-endian uint64)
        - 8 bytes: compressed size (big-endian uint64)
        - variable: xz-compressed data (or raw if compressed_size == uncompressed_size)
    """
    print("Step 4: Decompressing pbzx payload into Apple Archive...", file=sys.stderr)
    total_written = 0

    with open(output, "wb") as out:
        for i, payload in enumerate(payloads):
            print(
                f"  Processing {payload.name} ({i + 1}/{len(payloads)})...",
                file=sys.stderr,
                end="",
                flush=True,
            )
            chunk_written = 0

            with open(payload, "rb") as f:
                magic = f.read(4)
                if magic != PBZX_MAGIC:
                    sys.exit(
                        f"Error: {payload.name} is not a pbzx file (magic: {magic!r})"
                    )

                (_chunk_size,) = struct.unpack(">Q", f.read(8))

                while True:
                    header = f.read(16)
                    if len(header) < 16:
                        break

                    uncompressed_size, compressed_size = struct.unpack(">QQ", header)

                    if compressed_size == 0:
                        break

                    data = f.read(compressed_size)
                    if len(data) < compressed_size:
                        sys.exit(
                            f"Error: Truncated block in {payload.name} "
                            f"(expected {compressed_size}, got {len(data)})"
                        )

                    if compressed_size == uncompressed_size:
                        # Raw (uncompressed) block
                        out.write(data)
                        chunk_written += len(data)
                    else:
                        # XZ-compressed block
                        decompressed = lzma.decompress(data)
                        out.write(decompressed)
                        chunk_written += len(decompressed)

            total_written += chunk_written
            print(f" {chunk_written / (1024**2):.0f} MB", file=sys.stderr)

    print(
        f"  Total Apple Archive size: {total_written / (1024**3):.1f} GB", file=sys.stderr
    )


def extract_font_from_yaa(yaa_archive: Path, workdir: Path) -> Path:
    """Extract Apple Color Emoji.ttc from an Apple Archive (YAA) using neoaa."""
    print("Step 5: Extracting font from Apple Archive...", file=sys.stderr)
    font = workdir / "Apple Color Emoji.ttc"
    run(["neoaa", "unwrap", "-i", str(yaa_archive), "-o", str(font), "-p", FONT_PATH])
    if not font.exists():
        sys.exit(f"Error: {FONT_PATH} not found in Apple Archive")
    print(f"  Font size: {font.stat().st_size / (1024**2):.1f} MB", file=sys.stderr)
    return font


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Extract Apple Color Emoji.ttc from a macOS InstallAssistant.pkg"
    )
    source = parser.add_mutually_exclusive_group()
    source.add_argument("pkg", type=Path, nargs="?", help="Path to InstallAssistant.pkg")
    source.add_argument(
        "--from-yaa",
        type=Path,
        metavar="ARCHIVE",
        help="Extract font directly from an existing Apple Archive (YAA)",
    )
    parser.add_argument(
        "-o",
        "--output-dir",
        type=Path,
        default=Path.cwd(),
        help="Output directory (default: current directory)",
    )
    args = parser.parse_args()

    if not args.from_yaa and not args.pkg:
        parser.error("either pkg or --from-yaa is required")

    input_path = args.from_yaa or args.pkg
    if not input_path.exists():
        sys.exit(f"Error: {input_path} does not exist")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    dest = args.output_dir / "Apple Color Emoji.ttc"

    if args.from_yaa:
        # Skip straight to font extraction from YAA
        with tempfile.TemporaryDirectory(prefix="apple-emoji-") as tmpdir:
            font = extract_font_from_yaa(args.from_yaa, Path(tmpdir))
            shutil.copy2(font, dest)
    else:
        with tempfile.TemporaryDirectory(prefix="apple-emoji-") as tmpdir:
            tmp = Path(tmpdir)

            # Step 1: xar -> SharedSupport.dmg
            dmg = extract_xar(args.pkg, tmp)

            # Step 2: dmg -> <hash>.zip
            dmg_dir = tmp / "dmg"
            dmg_dir.mkdir()
            zipfile = extract_dmg(dmg, dmg_dir)
            dmg.unlink()  # Free ~12GB

            # Step 3: zip -> payload chunks
            payload_dir = tmp / "payloads"
            payload_dir.mkdir()
            payloads = extract_payloads(zipfile, payload_dir)
            zipfile.unlink()  # Free ~17GB

            # Step 4: pbzx decompress -> Apple Archive (YAA)
            yaa_archive = tmp / "payload.yaa"
            decompress_pbzx(payloads, yaa_archive)
            for p in payloads:
                p.unlink()

            # Step 5: YAA -> Apple Color Emoji.ttc
            font_dir = tmp / "font"
            font_dir.mkdir()
            font = extract_font_from_yaa(yaa_archive, font_dir)
            yaa_archive.unlink()

            shutil.copy2(font, dest)

    print(f"\nDone! Extracted to: {dest}", file=sys.stderr)


if __name__ == "__main__":
    main()
