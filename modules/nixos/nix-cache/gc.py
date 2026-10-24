"""Mark-and-sweep garbage collection for the Nix binary cache bucket.

The push service records every system it uploads as roots/<host>/<unix time>,
whose body lists the pushed store paths. Live paths are the closures of the
roots inside the retention window plus the newest root of each host; their
.narinfo files and the NARs those point at survive, and everything else past
the grace period is deleted. Closures are walked through the bucket's own
narinfo references, so the result does not depend on what the local store
still holds.

Usage: gc.py BUCKET STORE_URI
Environment: AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY (a B2 application key),
RETENTION_DAYS, GRACE_DAYS, and DRY_RUN=1 to only report.
"""

import io
import json
import os
import subprocess
import sys
import time

# b2sdk.v3 speaks B2 API v4, the only version that accepts bucket-restricted keys.
from b2sdk.v3 import B2Api, InMemoryAccountInfo

DAY = 86400


def main() -> int:
    bucket_name, store_uri = sys.argv[1], sys.argv[2]
    retention = int(os.environ["RETENTION_DAYS"]) * DAY
    grace = int(os.environ["GRACE_DAYS"]) * DAY
    dry_run = os.environ.get("DRY_RUN") == "1"
    now = time.time()

    api = B2Api(InMemoryAccountInfo())
    api.authorize_account(
        os.environ["AWS_ACCESS_KEY_ID"],
        os.environ["AWS_SECRET_ACCESS_KEY"],
    )
    bucket = api.get_bucket_by_name(bucket_name)

    versions = [fv for fv, _ in bucket.ls(recursive=True, latest_only=False)]

    def age(fv) -> float:
        return now - fv.upload_timestamp / 1000

    roots = [fv for fv in versions if fv.file_name.startswith("roots/")]
    newest = {}
    for fv in roots:
        host = fv.file_name.split("/")[1]
        if host not in newest or fv.upload_timestamp > newest[host].upload_timestamp:
            newest[host] = fv
    kept_roots = [
        fv for fv in roots if age(fv) < retention or fv is newest[fv.file_name.split("/")[1]]
    ]
    if not kept_roots:
        print("no roots recorded; refusing to collect", file=sys.stderr)
        return 1

    root_paths = set()
    for fv in kept_roots:
        buf = io.BytesIO()
        bucket.download_file_by_id(fv.id_).save(buf)
        root_paths.update(line for line in buf.getvalue().decode().split() if line)

    # A missing reference makes path-info fail, which aborts the run: a partial
    # live set would delete paths that are still in use.
    info = json.loads(
        subprocess.run(
            [
                "nix", "path-info", "--recursive", "--json", "--json-format", "1",
                "--store", store_uri, *sorted(root_paths),
            ],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
    )
    live_hashes = {os.path.basename(p)[:32] for p in info}
    live_nars = {i["url"] for i in info.values() if i and "url" in i}

    doomed = []
    for fv in versions:
        name = fv.file_name
        if age(fv) < grace:
            continue
        if name.endswith(".narinfo") and "/" not in name:
            dead = name.removesuffix(".narinfo") not in live_hashes
        elif name.startswith("nar/"):
            dead = name not in live_nars
        elif name.startswith("roots/"):
            dead = not any(fv is k for k in kept_roots)
        else:
            dead = False
        if dead:
            doomed.append(fv)

    freed = sum(fv.size for fv in doomed)
    print(
        f"{len(kept_roots)} roots, {len(info)} live paths; "
        f"{'would delete' if dry_run else 'deleting'} {len(doomed)} files "
        f"({freed / 2**30:.2f} GiB)"
    )
    if not dry_run:
        for fv in doomed:
            api.delete_file_version(fv.id_, fv.file_name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
