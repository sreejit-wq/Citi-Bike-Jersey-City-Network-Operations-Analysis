USE citibike_trip_data_202509;
# DROP TABLE IF EXISTS trip_data;
SHOW TABLES;
SELECT COUNT(*)
FROM trip_data;
#__________________________________________________________________
# Query 1 - NET FLOW PER STATION PER DAY
WITH rides_out AS (
    SELECT
        start_station_id AS station_id,
        start_station_name AS station,
        date,
        COUNT(*) AS outbound
    FROM trip_data
    GROUP BY start_station_id, start_station_name, date
),

rides_in AS (
    SELECT
        end_station_id AS station_id,
        end_station_name AS station,
        date,
        COUNT(*) AS inbound
    FROM trip_data
    WHERE ride_incomplete = 0
    GROUP BY end_station_id, end_station_name, date
),

combined AS (

    SELECT
        o.station_id,
        o.station,
        o.date,
        o.outbound,
        COALESCE(i.inbound,0) AS inbound
    FROM rides_out o
    LEFT JOIN rides_in i
        ON o.station_id = i.station_id
       AND o.date = i.date

    UNION

    SELECT
        i.station_id,
        i.station,
        i.date,
        COALESCE(o.outbound,0) AS outbound,
        i.inbound
    FROM rides_in i
    LEFT JOIN rides_out o
        ON i.station_id = o.station_id
       AND i.date = o.date
    WHERE o.station_id IS NULL
)

SELECT
    station_id,
    station,
    date,
    outbound,
    inbound,
    inbound - outbound AS net_flow
FROM combined
ORDER BY date, net_flow ASC;
#__________________________________________________________________

SET SQL_SAFE_UPDATES = 0;

UPDATE trip_data t
JOIN (
    SELECT
        end_station_name,
        MAX(end_station_id) AS correct_id
    FROM trip_data
    WHERE end_station_id IS NOT NULL
    GROUP BY end_station_name
) s
ON t.end_station_name = s.end_station_name
SET t.end_station_id = s.correct_id
WHERE t.end_station_id IS NULL;

SET SQL_SAFE_UPDATES = 1;

#__________________________________________________________________
#Q2 — AVERAGE NET FLOW PER STATION ACROSS FULL MONTH
WITH station_flow AS (

    SELECT
        start_station_id AS station_id,
        start_station_name AS station,
        date,
        -COUNT(*) AS flow
    FROM trip_data
    WHERE ride_incomplete = 0
    GROUP BY start_station_id, start_station_name, date

    UNION ALL

    SELECT
        end_station_id,
        end_station_name,
        date,
        COUNT(*) AS flow
    FROM trip_data
    WHERE ride_incomplete = 0
      AND cross_river_trip = 0
    GROUP BY end_station_id, end_station_name, date
)

SELECT
    station_id,
    station,
    ROUND(AVG(net_flow),2) AS avg_daily_net_flow,
    MIN(net_flow) AS worst_deficit_day,
    MAX(net_flow) AS best_surplus_day,
    COUNT(*) AS days_observed,
    CASE
        WHEN AVG(net_flow) <= -5 THEN 'Chronic Deficit'
        WHEN AVG(net_flow) >= 5 THEN 'Chronic Surplus'
        ELSE 'Balanced'
    END AS station_type
FROM (

    SELECT
        station_id,
        station,
        date,
        SUM(flow) AS net_flow
    FROM station_flow
    GROUP BY station_id, station, date

) x
GROUP BY station_id, station
ORDER BY avg_daily_net_flow;
#__________________________________________________________________
# Q3 Morning peak demand by station per hour

SELECT
    start_station_id AS station_id,
    start_station_name AS station,
    hour_of_day,
    COUNT(*) AS rides,
    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (PARTITION BY start_station_id),
        1
    ) AS percentage_of_station_rides
    
FROM trip_data
WHERE hour_of_day BETWEEN 7 AND 9
  AND is_weekday = 1
  AND ride_incomplete = 0
GROUP BY
    start_station_id,
    start_station_name,
    hour_of_day
ORDER BY rides DESC;
#__________________________________________________________________
# Q4 Member vs Casual Hourwise No. of Ride and Avg duration
 SELECT
        hour_of_day,
        member_casual,
        COUNT(*) AS rides,
        ROUND(AVG(duration_min), 1) AS avg_duration_min
    FROM trip_data
    WHERE duration_outlier = 0
      AND ride_incomplete  = 0
    GROUP BY hour_of_day, member_casual
    ORDER BY hour_of_day, member_casual;
#__________________________________________________________________
# Q5 Overall Casual Vs Member Statistics

SELECT
    member_casual,

    COUNT(*) AS total_rides,

    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(),
        1
    ) AS pct_of_total,

    ROUND(AVG(duration_min), 1) AS avg_duration_min,

    ROUND(
        AVG(
            CASE
                WHEN duration_outlier = 0
                THEN duration_min
            END
        ),
        1
    ) AS avg_duration_excl_outliers,

    ROUND(
        AVG(
            CASE
                WHEN ride_incomplete = 0
                 AND round_trip = 0
                THEN distance_km
            END
        ),
        2
    ) AS avg_distance_km,

    ROUND(
        SUM(
            CASE
                WHEN ride_incomplete = 0
                 AND round_trip = 0
                THEN distance_km
            END
        ),
        2
    ) AS total_distance_km,

    ROUND(
        AVG(
            CASE
                WHEN ride_incomplete = 0
                 AND duration_outlier = 0
                 AND speed_kmh IS NOT NULL
                THEN speed_kmh
            END
        ),
        2
    ) AS avg_speed_kmh,

    -- Round Trips
    SUM(
        CASE
            WHEN round_trip = 1 THEN 1
            ELSE 0
        END
    ) AS round_trips,

    ROUND(
        SUM(
            CASE
                WHEN round_trip = 1 THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS round_trip_pct,

    ROUND(
        SUM(
            CASE
                WHEN round_trip = 1 THEN 1
                ELSE 0
            END
        ) * 100.0 /
        SUM(
            SUM(
                CASE
                    WHEN round_trip = 1 THEN 1
                    ELSE 0
                END
            )
        ) OVER (),
        2
    ) AS pct_of_all_round_trips,

    -- Cross River Trips
    SUM(
        CASE
            WHEN cross_river_trip = 1 THEN 1
            ELSE 0
        END
    ) AS cross_river_rides,

    ROUND(
        SUM(
            CASE
                WHEN cross_river_trip = 1 THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*),
        2
    ) AS cross_river_pct,

    ROUND(
        SUM(
            CASE
                WHEN cross_river_trip = 1 THEN 1
                ELSE 0
            END
        ) * 100.0 /
        SUM(
            SUM(
                CASE
                    WHEN cross_river_trip = 1 THEN 1
                    ELSE 0
                END
            )
        ) OVER (),
        2
    ) AS pct_of_all_cross_river_rides

FROM trip_data
GROUP BY member_casual;

#__________________________________________________________________
# Q6 Day-wise statictics of Member Vs Casual in terms of No. of Rides, Avg Duration and Avg Distance

SELECT
        day_name,
        day_of_week,
        member_casual,
        COUNT(*)                        AS rides,
        ROUND(AVG(CASE WHEN duration_outlier = 0
                       THEN duration_min END), 1) AS avg_duration_min,
        ROUND(AVG(CASE WHEN ride_incomplete = 0
                       AND round_trip = 0
                       THEN distance_km END), 2)  AS avg_distance_km
    FROM trip_data
    GROUP BY day_name, day_of_week, member_casual
    ORDER BY day_of_week, member_casual; 
#__________________________________________________________________
# Q7 Crossriver Trip Analysis 
SELECT
    cross_river_trip,
    member_casual,

    COUNT(*) AS rides,

    -- % of all rides
    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (),
        2
    ) AS pct_of_all_rides,

    -- % within each rider type
    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (PARTITION BY member_casual),
        2
    ) AS pct_of_rider_type,

    -- % within each trip type (cross-river or not)
    ROUND(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER (PARTITION BY cross_river_trip),
        2
    ) AS pct_of_cross_river_group,

    ROUND(
        AVG(
            CASE
                WHEN duration_outlier = 0
                THEN duration_min
            END
        ),
        1
    ) AS avg_duration_min,

    ROUND(
        AVG(
            CASE
                WHEN ride_incomplete = 0
                THEN distance_km
            END
        ),
        2
    ) AS avg_distance_km

FROM trip_data
GROUP BY
    cross_river_trip,
    member_casual

ORDER BY
    cross_river_trip,
    member_casual;
    
#__________________________________________________________________
# Q8 Hourwise Stations Deficit
WITH hourly_out AS (
    SELECT
        start_station_id AS station_id,
        start_station_name AS station,
        hour_of_day,
        COUNT(*) AS outbound
    FROM trip_data
    WHERE ride_incomplete = 0
      AND is_weekday = 1
    GROUP BY
        start_station_id,
        start_station_name,
        hour_of_day
),

hourly_in AS (
    SELECT
        end_station_id AS station_id,
        end_station_name AS station,
        hour_of_day,
        COUNT(*) AS inbound
    FROM trip_data
    WHERE ride_incomplete = 0
      AND cross_river_trip = 0
      AND is_weekday = 1
    GROUP BY
        end_station_id,
        end_station_name,
        hour_of_day
),

combined AS (

    SELECT
        o.station_id,
        o.station,
        o.hour_of_day,
        o.outbound,
        COALESCE(i.inbound,0) AS inbound
    FROM hourly_out o
    LEFT JOIN hourly_in i
      ON o.station_id = i.station_id
     AND o.hour_of_day = i.hour_of_day

    UNION

    SELECT
        i.station_id,
        i.station,
        i.hour_of_day,
        COALESCE(o.outbound,0),
        i.inbound
    FROM hourly_in i
    LEFT JOIN hourly_out o
      ON i.station_id = o.station_id
     AND i.hour_of_day = o.hour_of_day
    WHERE o.station_id IS NULL
),

hourly_flow AS (

    SELECT
        station_id,
        station,
        hour_of_day,
        inbound - outbound AS net_flow
    FROM combined
)

SELECT

    station_id,
    station,

    SUM(net_flow) AS total_daily_net_flow,

    MIN(net_flow) AS worst_hour_net_flow,

    CASE
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 0 THEN net_flow END) THEN '12 AM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 1 THEN net_flow END) THEN '1 AM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 2 THEN net_flow END) THEN '2 AM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 3 THEN net_flow END) THEN '3 AM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 4 THEN net_flow END) THEN '4 AM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 5 THEN net_flow END) THEN '5 AM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 6 THEN net_flow END) THEN '6 AM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 7 THEN net_flow END) THEN '7 AM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 8 THEN net_flow END) THEN '8 AM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 9 THEN net_flow END) THEN '9 AM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 10 THEN net_flow END) THEN '10 AM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 11 THEN net_flow END) THEN '11 AM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 12 THEN net_flow END) THEN '12 PM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 13 THEN net_flow END) THEN '1 PM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 14 THEN net_flow END) THEN '2 PM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 15 THEN net_flow END) THEN '3 PM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 16 THEN net_flow END) THEN '4 PM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 17 THEN net_flow END) THEN '5 PM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 18 THEN net_flow END) THEN '6 PM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 19 THEN net_flow END) THEN '7 PM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 20 THEN net_flow END) THEN '8 PM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 21 THEN net_flow END) THEN '9 PM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 22 THEN net_flow END) THEN '10 PM'
        WHEN MIN(net_flow) = MAX(CASE WHEN hour_of_day = 23 THEN net_flow END) THEN '11 PM'
    END AS worst_hour,

    MAX(CASE WHEN hour_of_day=0 THEN net_flow END) AS `12 AM`,
    MAX(CASE WHEN hour_of_day=1 THEN net_flow END) AS `1 AM`,
    MAX(CASE WHEN hour_of_day=2 THEN net_flow END) AS `2 AM`,
    MAX(CASE WHEN hour_of_day=3 THEN net_flow END) AS `3 AM`,
    MAX(CASE WHEN hour_of_day=4 THEN net_flow END) AS `4 AM`,
    MAX(CASE WHEN hour_of_day=5 THEN net_flow END) AS `5 AM`,
    MAX(CASE WHEN hour_of_day=6 THEN net_flow END) AS `6 AM`,
    MAX(CASE WHEN hour_of_day=7 THEN net_flow END) AS `7 AM`,
    MAX(CASE WHEN hour_of_day=8 THEN net_flow END) AS `8 AM`,
    MAX(CASE WHEN hour_of_day=9 THEN net_flow END) AS `9 AM`,
    MAX(CASE WHEN hour_of_day=10 THEN net_flow END) AS `10 AM`,
    MAX(CASE WHEN hour_of_day=11 THEN net_flow END) AS `11 AM`,
    MAX(CASE WHEN hour_of_day=12 THEN net_flow END) AS `12 PM`,
    MAX(CASE WHEN hour_of_day=13 THEN net_flow END) AS `1 PM`,
    MAX(CASE WHEN hour_of_day=14 THEN net_flow END) AS `2 PM`,
    MAX(CASE WHEN hour_of_day=15 THEN net_flow END) AS `3 PM`,
    MAX(CASE WHEN hour_of_day=16 THEN net_flow END) AS `4 PM`,
    MAX(CASE WHEN hour_of_day=17 THEN net_flow END) AS `5 PM`,
    MAX(CASE WHEN hour_of_day=18 THEN net_flow END) AS `6 PM`,
    MAX(CASE WHEN hour_of_day=19 THEN net_flow END) AS `7 PM`,
    MAX(CASE WHEN hour_of_day=20 THEN net_flow END) AS `8 PM`,
    MAX(CASE WHEN hour_of_day=21 THEN net_flow END) AS `9 PM`,
    MAX(CASE WHEN hour_of_day=22 THEN net_flow END) AS `10 PM`,
    MAX(CASE WHEN hour_of_day=23 THEN net_flow END) AS `11 PM`

FROM hourly_flow

GROUP BY
    station_id,
    station

ORDER BY
    total_daily_net_flow ASC;
#__________________________________________________________________
