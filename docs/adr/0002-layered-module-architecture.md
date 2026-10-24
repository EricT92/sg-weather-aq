# ADR 0002: Three-layer OutSystems module architecture

**Status:** Accepted

## Decision
Follow the OutSystems Architecture Canvas with three modules:

| Layer | Module | Responsibility |
| --- | --- | --- |
| Foundation | `DataGovSG_IS` | Only talks to data.gov.sg. Wraps each REST method in a public server action that never throws and returns `Success` / `ErrorMessage`. |
| Core | `WeatherAirQuality_Core` | Entities, sync logic, Timer, business rules (e.g. PSI → NEA health band). Entities are public **read-only**, so only Core can write. |
| End-user | `WeatherAirQuality` | Screens and blocks only. No business logic, no direct API calls. |

## Consequences
- Dependencies only point downwards (UI → Core → IS); no cycles.
- If data.gov.sg changes, adds mandatory API keys or needs retry logic, only
  `DataGovSG_IS` changes.
- Business rules are testable without the UI (see `tests/outsystems`).
- Trade-off: more modules than a single-module app; justified because it keeps
  each part small and replaceable.
