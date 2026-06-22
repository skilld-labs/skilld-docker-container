---
name: observability-up
description: Get logs and traces out of the running stack. Tier 1 is Docker logs (no extra services); Tier 2 brings up the opt-in OpenTelemetry trace stack (Tempo + Grafana) and prints the Grafana URL. Use for "show me the logs", "enable tracing", "bring up observability".
---

# Observability up

Implements [docs/observability.md](../../../docs/observability.md).

## Tier 1 — logs (always available)

```sh
docker compose logs -f php                  # access + PHP error log (stdout/stderr)
make drush -- watchdog:tail                  # live Drupal log
make watchdogval                             # fail on Emergency|Alert|Critical|Error
```

Mail: open Mailpit at `mail-${MAIN_DOMAIN_NAME}`. This is the default answer to "get me the logs".

## Tier 2 — traces (opt-in OpenTelemetry)

Trace tooling comes from PR #466 (Tempo + Grafana + the OTel PHP extensions). Steps:

1. Ensure the OTel pieces are present (rebase/land PR #466 if not): Tempo + Grafana services in
   `docker/docker-compose.override.yml`, `docker/tempo.yml`, `docker/grafana-datasources.yml`, the
   `php83-pecl-opentelemetry|grpc|protobuf` extensions in `ADDITIONAL_PHP_PACKAGES`, and the `OTEL_*`
   env vars on the `php` service.
2. Enable the opt-in profile/flag (keep it **off by default** so plain review apps stay cheap), then
   `make provision reload` (or `docker compose up -d`) to start Tempo + Grafana and install the
   extensions.
3. Print the Grafana URL (via `make info` / the Traefik host label) and tell the user to open
   **Explore → Tempo**.
4. Generate a trace: load a page, then search in Grafana.

## Hosted alternative
NewRelic: set `NEW_RELIC_LICENSE_KEY`, `make newrelic reload`. Bumping the agent is the
[`dep-bump`](../dep-bump/SKILL.md) skill's job.

## Guardrails
- Don't enable Tier 2 by default in CI/review apps — it adds two services per app.
- If PR #466 isn't landed yet, say so and offer to run the rebase rather than hand-rolling config.
