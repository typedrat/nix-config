#!/usr/bin/env python3
"""Copy the ulysses tunnel token from Terraform into sops.

`tofu output -raw` writes no trailing newline and the terranix wrapper writes
its SSH tunnel chatter to stdout, so the token shares a line with whatever the
wrapper prints next. Splitting that apart by pattern does not work -- the
message that follows is made entirely of base64 characters -- so the token is
recovered by decoding the run of base64 and finding where its JSON ends.

The token is never printed; only the tunnel id it carries.

Usage: python3 terraform/set-tunnel-token.py
"""

import base64
import json
import pathlib
import re
import subprocess
import sys

REPO = pathlib.Path(__file__).resolve().parent.parent
SECRETS = "secrets/deploy.yaml"
KEY = '["cloudflare"]["tunnelToken"]'


def extract(blob):
    """Recover the exact token from a stream with output run on to its end.

    The token's length is not known up front and the trailing text is itself
    valid base64, so candidate lengths are tried until one decodes to the
    complete tunnel JSON. `=` is excluded from the match so a padded token
    ends the run by itself.
    """
    match = re.search(r"eyJ[A-Za-z0-9+/]+", blob)
    if not match:
        sys.exit("no base64 token found in terraform output")
    body = match.group(0)

    for end in range(4, len(body) + 1):
        if end % 4 == 1:
            continue  # never a valid base64 length
        chunk = body[:end] + "=" * (-end % 4)
        try:
            raw = base64.b64decode(chunk)
            payload, stop = json.JSONDecoder().raw_decode(
                raw.decode("utf-8", "ignore")
            )
        except Exception:
            continue
        if {"a", "t", "s"} <= payload.keys():
            # Re-encoding exactly the JSON bytes reproduces the original token.
            return base64.b64encode(raw[:stop]).decode(), payload

    sys.exit("found no decodable tunnel token")


def main():
    out = subprocess.run(
        [
            "nix", "develop", ".#terraform", "--command",
            "tofu", "output", "-raw", "ulysses-tunnel-token",
        ],
        cwd=REPO,
        capture_output=True,
        text=True,
    )
    if out.returncode != 0:
        sys.exit(f"tofu output failed:\n{out.stderr[-500:]}")

    token, payload = extract(out.stdout)

    subprocess.run(
        ["sops", "set", SECRETS, KEY, json.dumps(token)], cwd=REPO, check=True
    )
    print("wrote token for tunnel", payload["t"])


if __name__ == "__main__":
    main()
