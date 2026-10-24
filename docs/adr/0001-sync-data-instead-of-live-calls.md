# ADR 0001: Sync data.gov.sg into the database instead of calling it live

**Status:** Accepted

## Context
The app shows PSI (air quality) and the 2-hour weather forecast from the
data.gov.sg real-time APIs. Those APIs:

- are rate limited (without an API key: about 6 calls per 10 seconds for real-time APIs),
- return only the *latest* reading, not history,
- are an external dependency that can be slow or unavailable.

## Decision
A scheduled Timer in `WeatherAirQuality_Core` syncs both APIs into our own entities
every 30 minutes (the forecast's publishing frequency). Screens only read from
the database. A "Refresh now" action triggers the same sync on demand.

The sync is **idempotent**: a reading/forecast period that is already stored is
skipped, so the Timer and manual refreshes can overlap safely.

## Consequences
- Page loads never hit the external API → no rate-limit errors for users, fast pages.
- The app keeps working with the last known data when data.gov.sg is down;
  a "stale data" banner appears when the last successful sync is too old.
- Stored snapshots build the history needed for trend charts.
- Trade-off: data can be up to ~30 minutes old. Acceptable for this use case,
  and the refresh button covers users who want the latest values.
- Trade-off: storage grows over time → a retention clean-up (e.g. keep 30 days)
  is a natural next step.
