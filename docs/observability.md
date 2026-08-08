# Observability

Two tiers, by cost. **Tier 1 (logs)** needs no extra services and works today. **Tier 2 (traces)** is
an opt-in OpenTelemetry stack, default-off so review apps stay cheap.

## Tier 1 — Logs (zero extra services)

Whatever SAPI the `php` container runs, it logs to **stdout/stderr**, so Docker captures everything:

- Nginx Unit writes `access_log` and app stdout/stderr to the container log
  ([`docker/unit.json`](../docker/unit.json): `"access_log": "/dev/stdout"`, app `stdout`/`stderr`).
- FrankenPHP/Caddy logs to stdout as well.

Useful commands:

```sh
docker compose logs -f php                 # live web/app log (access + PHP errors)
make drush -- watchdog:tail                 # live Drupal log (dblog)
make watchdogval                            # fail if any Emergency|Alert|Critical|Error was logged
```

Mail is captured by **Mailpit** (the `mailhog` service in the override), browsable at
`mail-${MAIN_DOMAIN_NAME}` — no real mail leaves the box.

This already satisfies "logs easy to get from Docker." A handy addition (issue #152): expose Nginx
Unit's status/health route as a liveness probe in the override file's `php` service `healthcheck:`.

## Tier 2 — Traces (opt-in OpenTelemetry)

Distributed tracing is prototyped in **PR #466** (`otel` branch). Rather than reinvent it, the plan is
to **rebase and finish that PR**, then gate it behind a flag. What it wires up (none of these files/
settings exist on this branch yet — they land with PR #466):

| Piece | Where (added by PR #466) |
| --- | --- |
| Tempo (trace store) + Grafana (UI) services | `docker/docker-compose.override.yml.default` |
| Tempo config | `docker/tempo.yml` |
| Grafana datasource (→ Tempo) | `docker/grafana-datasources.yml` |
| PHP extensions | `ADDITIONAL_PHP_PACKAGES`: `php83-pecl-opentelemetry`, `php83-pecl-grpc`, `php83-pecl-protobuf` |
| Drupal/OTel glue | composer: `mladenrtl/opentelemetry-auto-drupal`, `open-telemetry/exporter-otlp` |
| Wiring | env: `OTEL_PHP_AUTOLOAD_ENABLED=true`, `OTEL_TRACES_EXPORTER=otlp`, `OTEL_EXPORTER_OTLP_ENDPOINT=http://tempo:4318`, `OTEL_EXPORTER_OTLP_PROTOCOL=http/json` |

**Open TODOs to land it** (carried from the PR): a review-app **collector** path, a **make-it-optional
flag** (a Compose profile / env switch so it is off by default), and starter **Grafana dashboards**.
Rebase onto current master first — the PR predates the Unit-default revert and recent NewRelic bumps.

The [`observability-up`](../.claude/skills/observability-up/SKILL.md) skill wraps bringing the stack
up/down and printing the Grafana URL; it reuses the existing `ADDITIONAL_PHP_PACKAGES` + `make reload`
install path.

### Verifying traces

```sh
# with the opt-in profile enabled:
docker compose up -d            # brings up tempo + grafana alongside php
# hit a page, then open Grafana (printed by observability-up) → Explore → Tempo → search traces
```

A single page request should produce at least one trace spanning the PHP request and Drupal's
bootstrap/render.

## Hosted alternative — NewRelic

For hosted APM instead of self-managed traces, set `NEW_RELIC_LICENSE_KEY` and run `make newrelic`
(enables the agent and the `newrelic` daemon service in the override). The agent version is pinned in
[`scripts/makefile/newrelic.sh`](../scripts/makefile/newrelic.sh) and bumped frequently — that bump is
automated by the [`dep-bump`](../.claude/skills/dep-bump/SKILL.md) skill /
[`newrelic-bump`](../.claude/workflows/newrelic-bump.workflow.js) workflow.

## Choosing a tier

- **Just debugging a review app?** Tier 1 logs.
- **Performance / where-is-the-time questions?** Tier 2 traces (or NewRelic if you have a license).
- **Production-like APM?** NewRelic.
