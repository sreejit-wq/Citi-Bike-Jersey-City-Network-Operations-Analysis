# Citi-Bike-Jersey-City-Network-Operations-Analysis
### September 2025 | End-to-End Data Analytics Portfolio Project

---

## Project Summary

This project analyses 116,055 Citi Bike trips from Jersey City (September 2025) to answer a operational question:

> **How should Citi Bike Jersey City prioritize fleet rebalancing to reduce lost demand and improve service reliability?**


---

## Key Findings

| Finding | Detail |
|---|---|
| **Network has a distribution problem, not a volume problem** |
| **2 chronic deficit stations** | McGinley Square (-6.1/day), Oakland Ave (-5.3/day) |
| **2 chronic surplus stations** | Grove St PATH (+6.8/day), River St & Newark St (+9.1/day) |
| **Rebalancing window needs to be pre-7am** | Both deficit stations hit worst deficit by 7-8am |
| **Member Rides drives the operational pressure** | 75.6% of rides, sharp dual commute peaks |
| **Casuals Riders are a leisure segment** | 65.8% longer trips, 2x higher round-trip rate |
| **Cross-river is a member commuter behavior** | 83.48% of cross-river trips are by members |
| **Riverfront station surplus is self-correcting** | Cross-river commuters return bikes in the evening |

---

## Tools & Technologies

| Tool | Purpose |
|---|---|
| **Python** (pandas) | Data cleaning, feature engineering|
| **MySQL Workbench** | SQL analysis — 8 queries |
| **Power BI** | Interactive 3-page dashboard |
| **DAX** | Custom measures for KPI cards |

---

## Project Structure

```
citibike-jc-analysis/
│
├── data/
│   ├── JC-202509-citibike-tripdata.csv        # Raw Data source                   
│
├── python/
│   ├── bike_ride_analysis.ipynb                # Data cleaning script and # Feature engineering
│   ├── EDA_citibike_project.ipynb              # EDA visualizations      
│
├── sql/
│   └── SQL_Script.sql                          # All 8 SQL queries
│
├── sql_outputs/
│   ├── Q1_net_flow_per_station_per_day.csv
│   ├── Q2_avg_net_flow_per_station.csv
│   ├── Q3_morning_peak_demand.csv
│   ├── Q4_hourly_demand_by_member_type.csv
│   ├── Q5_member_vs_casual_behavior.csv
│   ├── Q6_member_casual_by_day_of_week.csv
│   ├── Q7_cross_river_analysis.csv
│   └── Q8_deficit_stations_by_hour.csv
│

│
├── dashboard/
│   └── CitiBike_Project_Power_BI.pbix          # Power BI dashboard
│
│
└── README.md
```

---

## Data Pipeline

```
Raw CSV (116,071 rows)
    ↓ Data Cleaning
    • Drop August spillover (16 rows)
    • Flag incomplete trips (361 rows) — ride_incomplete
    • Flag duration outliers >240min (332 rows) — duration_outlier
    • Flag cross-river trips (448 rows) — cross_river_trip
    • Flag round trips (4,237 rows) — round_trip
    • Recover 126 missing end_station_ids via name→ID lookup
    ↓ Feature Engineering
    • Haversine distance (km)
    • Trip duration (min)
    • Hour of day, day of week, day name
    • is_weekday flag
    ↓ SQL Analysis (8 queries)
    ↓ Power BI Dashboard (3 pages)
    ↓ Executive Recommendations
```

---

## SQL Queries

| Query | Business Question |
|---|---|
| Q1 — Net Flow Per Station Per Day | Which stations gain or lose bikes daily? |
| Q2 — Avg Net Flow Per Station | Which stations have persistent imbalance? |
| Q3 — AM Peak Demand by Station | Which stations face greatest commuter pressure? |
| Q4 — Hourly Demand by Rider Type | How does demand vary by hour and rider type? |
| Q5 — Member vs Casual Behavior | How differently do the two segments use the network? |
| Q6 — Behavior by Day of Week | How do patterns change across weekdays and weekends? |
| Q7 — Cross-River Analysis | Who makes cross-river trips and how significant are they? |
| Q8 — Hourly Station Deficit Matrix | At what hour does each station hit its worst deficit? |

---

## Power BI Dashboard

3-page interactive dashboard:

- **Page 1 — Network Overview:** KPI cards, hourly demand curve, day-of-week breakdown, rider type split
- **Page 2 — Station Operations:** Net flow map, surplus/deficit bar chart, deficit station table, daily trend for chronic deficit stations
- **Page 3 — Rider Behavior:** Duration and distance by day of week, cross-river split, behavioral summary table

---

## Key Design Decisions

**Flag-not-drop cleaning philosophy**
Rather than silently deleting problematic rows (nulls, outliers, incomplete trips), every data quality issue was flagged with a boolean column. This preserves 100% of rows while enabling precise exclusion in downstream queries — and surfaces operationally meaningful signals (e.g. incomplete trips = bikes never properly docked).

**Station ID as join key**
All SQL joins use `station_id` (system-generated, unique) rather than `station_name` (human-readable, vulnerable to typos). Station names are retained as display columns only.

**±5 threshold for chronic classification**
The chronic deficit/surplus threshold of ±5 bikes/day is calibrated to an estimated average station capacity of ~10 docking points — representing a 50% daily stock change. Stations below this threshold can self-correct through normal ride patterns; those beyond it require dedicated intervention.

**Cross-river trips preserved, not filtered**
143 NYC-side stations appear only as trip endpoints, never as origins. Rather than treating these as data errors, they were flagged as `cross_river_trip = True` and used as a genuine behavioral insight — confirmed by the 83.48% member share of cross-river trips.

---

## Limitations

- Single month September 2025
- No dock capacity or opening inventory data the net flow calculated is relative, not absolute
- Haversine distance is straight-line, not road distance (~60-80% of actual route)
- Cross-river origin-station breakdown requires NYC system data not available here
- Lack of Data Regarding Weather on each particular Day during the Month
---

**Dataset:** [Citi Bike System Data](https://citibikenyc.com/system-data) — JC-202509-citibike-tripdata.csv
