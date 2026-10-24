# OutSystems application

Exported from the OutSystems 11 personal environment:

| File | What it is |
| --- | --- |
| `SG_Weather_AQ.osp` | Solution pack with all four modules (Service Center → Factory → Solutions → Upload and Publish a Solution) |
| `DataGovSG_IS.oml`, `WeatherAirQuality_Core.oml`, `WeatherAirQuality.oml`, `WeatherAirQuality_Tests.oml` | Individual modules, open in Service Studio 11 |

Built on Platform Server 11.42.1 with Service Studio 11.55.93. A solution pack can
only be published to the same or a newer platform version.

After importing into a new environment:

1. Install **BDDFramework** from the Forge first (the test module depends on it).
2. Publish the solution.
3. In Service Center → Factory → Modules → `WeatherAirQuality_Core` → Timers, set the sync Timer's effective schedule to **every 30 minutes** and click **Run Now** once to load data.
