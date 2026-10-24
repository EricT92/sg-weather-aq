# OutSystems automated tests (BDDFramework)

Unit and integration tests for the Core logic live in the
`WeatherAirQuality_Tests` module (Traditional Web, created from the
**BDDFramework** Forge template). Scenarios are written as Given / When / Then
steps; each step runs a screen action that calls the public Core logic and
checks the result with BDDFramework assertions (`AssertValue`, `AssertTrue`,
`AssertFalse`).

**Run them in a browser:**
https://personal-s1hc9xux.outsystemscloud.com/WeatherAirQuality_Tests/WeatherAirQualityTests

**Run them from CI / a pipeline** (the `outsystems-tests` job in `ci.yml`):

```
GET https://personal-s1hc9xux.outsystemscloud.com/BDDFramework/rest/v1/BDDTestRunner/WeatherAirQuality_Tests/WeatherAirQualityTests
```

The test screen allows the Anonymous role so the runner can call it.

## Scenarios

| Scenario (block) | Steps | What it proves | Type |
| --- | --- | --- | --- |
| `PSIBandScenario`: PSI value maps to the correct NEA health band | Then 50 → Good, 51 → Moderate, 200 → Unhealthy, 201 → Very Unhealthy, 301 → Hazardous | `GetPSIBand2` boundary values (both sides of each band edge) | Unit |
| `StalenessScenario`: data older than the threshold is flagged as stale | Then a sync 61 min ago is stale and 5 min ago is not (60-min threshold) | `IsDataStale` takes the current time as an input, so it is deterministic and testable | Unit |
| `SyncIdempotencyScenario`: running the PSI sync twice does not create duplicates | Given the data has been synced (row count stored), When the sync runs again, Then the row count is unchanged | `SyncPSI` is idempotent, so the Timer and manual refresh can overlap safely | Integration (calls data.gov.sg) |

Result: **all scenarios pass**.

## A bug the tests caught

The first run of `PSIBandScenario` failed:
`Expected "Very Unhealthy" but obtained "VeryUnhealthy"`.
The label in the `PSIBand` static entity had no space, so a PSI above 200 would
have shown "VeryUnhealthy" on the dashboard. Fixed in the static data, and the
test now guards it.

## Design notes

- Only what the tests need is Public in Core: `GetPSIBand2`, `IsDataStale`,
  `SyncPSI` (plus `SyncAll` for the UI). `SyncForecast` stays private.
- The idempotency test compares total `PSIReading` row counts a few seconds
  apart. In the rare case that data.gov.sg publishes a new hourly reading
  between the two calls it could fail, and a re-run would pass. A stricter version would
  count rows for the specific reading timestamp.

## Other automated tests in this repository

- `infra/terraform/**/tests/*.tftest.hcl`: Terraform tests (mocked AWS provider)
- `tests/e2e`: Playwright smoke tests against the deployed app
- `.github/workflows/ci.yml`: runs all of the above
