# Spoolman: filament spool inventory on iserlohn

Status: approved, not yet implemented
Date: 2026-08-27

## Summary

Run [Spoolman](https://github.com/Donkie/Spoolman) on iserlohn as
`rat.services.spoolman`, reachable at `https://spoolman.thisratis.gay`. Three
machine clients drive it — Moonraker on the Centauri Carbon (per-print filament
deduction), Home Assistant (dashboards and low-filament alerts), and
`spoolman2slicer` on ulysses — alongside browser use.

Spoolman ships no authentication of any kind. That single fact drives most of
this design: the machine clients cannot pass Authentik forward auth, so the LAN
needs an unauthenticated path to the API while the public internet does not.
Traefik v3's `ClientIP()` router matcher can split those two audiences on one
hostname, but only if LAN clients actually arrive bearing LAN addresses — which
today they do not. Fixing that is a router change, and it is a prerequisite
rather than a nicety.

## Goals

- Spoolman on iserlohn, backed by the repo's existing Traefik/Authentik/
  impermanence/Prometheus patterns.
- Browser access from anywhere, behind Authentik.
- Unauthenticated API access from the LAN, and only from the LAN.
- Moonraker reporting real filament usage per print.
- LAN clients reaching hosted services with their true source addresses, which
  benefits every service on iserlohn and not just this one.

## Non-goals

- Authenticating the machine clients. Spoolman has no auth to authenticate
  against; LAN-scoping is the whole of the access control.
- Managing the printer's OS declaratively. The Centauri Carbon runs a custom
  Linux image maintained outside this repo.
- Slicer integration in Nix. `spoolman2slicer` is a user-run helper on ulysses.

## Prerequisite: LAN clients must carry LAN source addresses

### The problem

`*.thisratis.gay` is a wildcard CNAME to `iserlohn.thisratis.gay`, an A record
for the WAN address `71.195.171.238`. LAN clients therefore resolve hosted names
to the public address and reach Traefik through the router's NAT reflection.

Both Traefik port forwards are configured `reflection_src='external'`:

```
chain srcnat_lan {
  ip saddr 10.0.0.0/24 ip daddr 10.0.0.10 tcp dport 443 snat ip to 71.195.171.238  # Traefik HTTPS
  ip saddr 10.0.0.0/24 ip daddr 10.0.0.10 tcp dport 22  snat ip to 10.0.0.1        # Server SSH
```

So every LAN client arrives at Traefik as the WAN address, indistinguishable
from the public internet. (The other five forwards use `internal` and SNAT to
`10.0.0.1`; the Traefik pair are the outliers.)

### Why hairpin NAT cannot preserve the source address

The SNAT is structurally required, not a configuration choice. With DNAT alone:
ulysses sends to `71.195.171.238:443`; the router rewrites the destination to
`10.0.0.10:443` and forwards it back out `br-lan` with the source intact;
iserlohn — on the same L2 segment — replies **directly** to `10.0.0.151`,
bypassing the router entirely; ulysses receives a `SYN/ACK` from `10.0.0.10:443`
that matches no socket it opened and drops it. The SNAT exists solely to force
the reply back through the router so it can reverse the translation.

`reflection_src` therefore only selects *which of the router's own addresses* to
masquerade as. The original client address is lost either way. Preserving it
requires either taking the router off the path (split-horizon DNS) or genuinely
putting it on the path (moving iserlohn to its own subnet — a network
re-architecture, rejected as disproportionate).

### Why overriding only the CNAME target is not enough

Overriding `iserlohn.thisratis.gay` alone does not work, because Cloudflare is
authoritative for both names and returns the resolved chain in one response:

```
spoolman.thisratis.gay.  300  IN CNAME iserlohn.thisratis.gay.
iserlohn.thisratis.gay.  300  IN A     71.195.171.238
```

dnsmasq forwards the query and returns that answer verbatim; it does not
re-resolve CNAME targets against local config. The client never issues a second
query, so the override is never consulted. Verified empirically against a
throwaway dnsmasq. CNAME flattening is orthogonal — it is already effectively
off, and enabling it would strip the CNAME while still returning the address.

### Chosen fix: DNS doctoring via `alias`

`alias` rewrites addresses in upstream replies, ignoring names and CNAME
structure entirely:

```
alias=71.195.171.238,10.0.0.10
```

Verified behaviour:

| Query | Result |
|---|---|
| `spoolman.thisratis.gay` | `10.0.0.10` (CNAME chain preserved) |
| `auth.thisratis.gay` | `10.0.0.10` |
| `thisratis.gay` (apex) | `10.0.0.10` |
| `ulysses-webhook.thisratis.gay` | `104.21.72.129` — untouched |
| `example.com` | untouched |

`ulysses-webhook` is carved out **automatically**: it resolves to Cloudflare's
proxy rather than the WAN address, so the rewrite never matches it. No
exception list to maintain as services are added — the rule keys on the intent
("traffic destined for this house stays inside it") rather than on an
enumeration.

Rejected alternative: `address=/thisratis.gay/10.0.0.10` plus
`server=/ulysses-webhook.thisratis.gay/#`. Also works and is immune to WAN
address changes, but requires manually carving out every externally-hosted
subdomain forever, and silently breaks any that is forgotten.

DNSSEC validation is not enabled on the router, so rewriting answers introduces
no validation conflict. ACME is DNS-01 via Cloudflare with an explicit
`dnsResolver = "1.1.1.1:53"`, so LAN DNS changes cannot affect certificate
issuance.

### Handling the DHCP lease

WAN is `proto='dhcp'` with a 4-day lease, so the address is stable in practice
but not guaranteed. If it changes, the alias silently stops matching and LAN
clients fall back to appearing external — which would make the `ClientIP()`
match fail and start bouncing LAN clients into Authentik, with no obvious cause.

A `/etc/hotplug.d/iface` script rewrites the alias whenever WAN comes up,
closing that failure mode.

### Implementation

UCI-native, via `dhcp.@dnsmasq[0].extraconftext` (the OpenWrt init script writes
it into the generated `conf-dir`), plus the hotplug script. Reversible with
`uci delete`.

### Consequences

Authentik and fail2ban begin seeing `10.0.0.x` for local traffic where they
previously saw the WAN address. That is the point of the change, but any policy
keyed on the old behaviour will need review. LAN clients may hold stale public
answers for up to the 300s TTL after the switch.

## Traefik: one hostname, two routers

Traefik 3.7.10 supports the `ClientIP()` router matcher, so both audiences share
a hostname:

| Router | Rule | Auth | Priority |
|---|---|---|---|
| `spoolman-lan` | ``Host(`spoolman.thisratis.gay`) && ClientIP(`10.0.0.0/24`)`` | none | higher |
| `spoolman` | ``Host(`spoolman.thisratis.gay`)`` | Authentik | default |

LAN clients match the first and pass through unauthenticated; everything else
falls to the second. One hostname, one certificate, no port numbers in client
config, and no unauthenticated surface reachable from the internet.

This is added to the Traefik route module as a reusable option rather than
special-cased for Spoolman:

```nix
authentikBypassFrom = mkOption {
  type = types.listOf types.str;
  default = [];
  description = "Client IP CIDRs that bypass Authentik forward auth.";
};
```

When non-empty and `authentik` is true, the module emits the additional
higher-priority router. Priority is set explicitly rather than relying on
Traefik's longest-rule-wins default.

### Accepted risk

Spoolman becomes fully read/write to anything on the LAN, IoT devices included.
This is inherent to wanting Moonraker to talk to it, and is accepted.

## NixOS module: `rat.services.spoolman`

Wraps the nixpkgs `services.spoolman` module, following the shape of
`modules/nixos/services/home/printguard.nix`.

### Options

- `enable`
- `subdomain` (default `spoolman`)
- `enableTraefik` (default true)
- `authentik` (default true — with the LAN bypass above, this only gates
  non-LAN traffic)

### Ports

`links.spoolman` with `protocol = "http"`, rather than the upstream default of
7912, so the port reservation lives with every other service's.

### Database: SQLite

Deliberately against the house Postgres convention, for three reasons:

1. Spoolman's automatic backups and its `/api/v1/backup` endpoint are
   **SQLite-only**. On Postgres they are simply unavailable.
2. iserlohn does not snapshot its own datasets — `services.sanoid` there only
   *prunes* the received-backup subtree from ulysses. So the data has RAID-Z2
   redundancy but no rollback path, and Spoolman's own backups are the only one
   it would get.
3. The dataset is a few hundred spools with a single writer. Postgres would
   cost a SOPS secret, a DB user, a credentials template and unit ordering for
   no benefit at this scale.

`SPOOLMAN_AUTOMATIC_BACKUP=TRUE`, so dated copies land in
`/var/lib/spoolman/backups`, inside the persisted directory.

### Environment

- `SPOOLMAN_AUTOMATIC_BACKUP=TRUE`
- `SPOOLMAN_METRICS_ENABLED=TRUE`

`SPOOLMAN_CORS_ORIGIN` is left unset; no planned client is a browser on a
different origin. Revisit if a web tool needs cross-origin access.

### Service user

The upstream module's `DynamicUser = true` is kept. Nothing else touches the
state directory, so no fixed UID is needed — unlike zipline, which had to force
`DynamicUser` off for Postgres peer authentication.

### Persistence

`/var/lib/spoolman` added to `environment.persistence.${persistDir}` under
`mkIf (cfg.enable && impermanenceCfg.enable)`, matching the printguard pattern.
With `DynamicUser` the directory is owned by a per-boot UID, so the persistence
entry records the directory without pinning user/group.

## Monitoring

A `scrapeConfigs` entry following the `modules/nixos/services/monitoring/prometheus/exporters/`
pattern, pointed at `config.links.spoolman`.

`SPOOLMAN_METRICS_ENABLED` is listed in the nixpkgs module's example but the
endpoint path and exposition format are unverified. Implementation must confirm
the endpoint actually serves Prometheus text format before wiring the scrape
config; if it does not, drop the scrape config rather than ship a job that
fails.

## Integrations

### Home Assistant

Points at `config.links.spoolman.url` on loopback — never touches Traefik, DNS,
or the LAN bypass, since it runs on iserlohn itself.

### Moonraker

The printer is rooted and running a custom Linux image, so `moonraker.conf` is
editable over SSH as root (reachability confirmed):

```ini
[spoolman]
server: https://spoolman.thisratis.gay
sync_rate: 5
```

Reached via the LAN router, so no Authentik and no port number. The printer is
`10.0.0.13`, inside the `10.0.0.0/24` bypass CIDR.

The exact config path is not yet known — `/etc/moonraker.conf` and
`/home/*/printer_data/config/moonraker.conf` are both absent, so implementation
must locate it first.

Because this edit lives on the printer's filesystem rather than in this repo,
the snippet is also checked in here so the configuration is not recorded only on
the printer.

### Slicer

`spoolman2slicer` on ulysses generates filament profiles from the API. User-run,
not configured by this repo. The API is reachable from ulysses via the LAN
router.

## Verification plan

1. `nix build .#nixosConfigurations.iserlohn.config.system.build.toplevel`.
2. After deploy: `systemctl status spoolman`, and confirm it is listening on the
   `links`-assigned port.
3. From ulysses, `curl https://spoolman.thisratis.gay/api/v1/info` — expect a
   JSON body with no Authentik redirect, confirming the LAN bypass.
4. Confirm Traefik access logs show `10.0.0.151` rather than the WAN address,
   proving the DNS doctoring works end to end.
5. From outside the LAN, confirm the same URL redirects to Authentik.
6. Confirm the metrics endpoint's format, then that Prometheus scrapes it.
7. On the printer, restart Moonraker and confirm it connects to Spoolman.
8. Run a short print and confirm the spool's remaining weight decreases.
9. Confirm `ulysses-webhook.thisratis.gay` still resolves to Cloudflare from a
   LAN host, i.e. the automatic carve-out held.

## Risks

- **WAN address change** silently breaks the alias. Mitigated by the hotplug
  script; step 4 above is the check that would catch it.
- **Whole-LAN trust of Spoolman.** Accepted; inherent to Moonraker integration.
- **Authentik/fail2ban now see real LAN addresses.** Any policy keyed on the old
  behaviour needs review.
- **Router change affects every hosted service**, not just Spoolman. It is a
  one-line `uci delete` to revert.
- **Metrics may not exist as assumed.** Handled by verifying before wiring.
