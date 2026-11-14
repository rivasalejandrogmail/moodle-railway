# Moodle on Railway

A thin, Railway-specific layer over [`erseco/alpine-moodle`](https://github.com/erseco/alpine-moodle)
(nginx + PHP-FPM 8.3 + runit, with Moodle's cron supervised in the same
container). The upstream image is configured entirely by environment variables;
this repository exists only for the four things a variable cannot express.

## What this layer adds

| | Why |
|---|---|
| `railway-entrypoint.sh` | Railway mounts volumes root-owned and the image runs as `nobody`, so Moodle cannot create its dataroot. Ownership is taken as root, then `su-exec` drops back to `nobody` before anything Moodle owns runs. |
| Baked Composer dependencies | Moodle 5.1+ has real runtime dependencies, and the image resolves them on every boot. Doing it in a build layer turns a multi-minute, network-dependent start into a no-op. |
| `00-railway-db.sh` | Railway's managed Postgres hands out the superuser on a shared database. This creates Moodle its own owner role and database from that credential, then revokes `PUBLIC` connect everywhere else. |
| `50-railway.sh` | Sets `$CFG->getremoteaddrconf` and `$CFG->reverseproxyignore` so Moodle reads the real client address from behind Railway's edge instead of the edge itself. |
| `zz-railway.ini`, `pm.max_children`, paced cron | The image ships opcache untuned, `pm.max_children=100` sized for a host rather than a container quota, and a cron loop that restarts as fast as runit allows. |

## Services

| Service | Public | Port | Volume |
|---|---|---|---|
| `moodle` (this repo) | yes | 8080 | `/var/www/moodledata` |
| Postgres | no | 5432 | managed |
| Redis | no | 6379 | managed |
| `mailpit` | yes (basic auth) | 8025 | `/data` |

Moodle's cron needs the same filesystem as the web tier, and Railway volumes are
strictly one-to-one with a service, so cron runs inside this container rather
than as a separate service.

## Environment variables

Everything the upstream image reads still applies —
see <https://erseco.github.io/alpine-moodle/environment-variables/>. The ones
that matter on Railway:

| Variable | Value |
|---|---|
| `SITE_URL` | `https://${{RAILWAY_PUBLIC_DOMAIN}}` — this becomes `$CFG->wwwroot` on first boot |
| `SSLPROXY` | `true` — the edge terminates TLS |
| `DB_BOOTSTRAP_URL` | `${{Postgres.DATABASE_URL}}` — used once per boot to provision the scoped role; unset it to bring your own database |
| `DB_HOST` / `DB_NAME` / `DB_USER` / `DB_PASS` | the scoped role this layer creates, not the managed superuser |
| `REDIS_HOST` / `REDIS_PASSWORD` | managed Redis; enables Moodle's Redis session handler and application cache |
| `SMTP_*` | Mailpit on the private network |
| `MOODLE_USERNAME` / `MOODLE_PASSWORD` / `MOODLE_EMAIL` | the site administrator, re-applied on every boot |
| `PHP_FPM_MAX_CHILDREN` | worker cap, default `16` |
| `MOODLE_CRON_INTERVAL` | seconds between cron runs, default `60` |

`MOODLE_SITENAME` and `MOODLE_PASSWORD` are passed to Moodle's CLI installer
unquoted by the upstream image, so neither may contain spaces or shell
metacharacters.

Because the administrator credentials are re-applied from the environment on
every boot, change them by editing these variables — a password changed in
Moodle's own UI is reverted by the next deployment.

## Licence

Moodle is GPL-3.0-or-later; the upstream image is MIT. This layer is MIT.

## Carbono Forestal campus branding

`branding/` contains the login welcome content, scoped CSS and public brand images. The startup hook `60-carbono-campus.sh` applies the native Moodle `auth_instructions` and `additionalhtmlhead` settings and the site display name after Moodle is ready. It preserves unrelated head additions and skips unchanged revisions. Login authentication, accounts, course records and uploaded files are not replaced.

The assets are served by Nginx under `/carbono-campus/` from the image, outside the Moodle source sync. Update the branding files to revise the design; the next deployment reapplies it and purges Moodle caches once.

Local design preview: `node branding/preview.cjs`, then open `http://localhost:3110`. This uses a disabled mock form; actual Moodle integration must be checked after deployment. To disable the branding, remove its marked block from the additional head setting and clear the authentication instructions; disable the startup hook before the next deployment to keep those changes.
