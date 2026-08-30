
{{
  config(
    materialized='table',
    cluster_by=['trip_date', 'zone_id']
  )
}}

with base as (
    select
        zone_id,
        mode,
        trip_hour,
        date(trip_hour) as trip_date,
        avg_temperature_c,
        total_precipitation_mm,
        had_significant_rain
    from {{ ref('int_trips_with_weather') }}
)

select
    zone_id,
    mode,
    trip_hour,
    trip_date,
    count(*) as trip_count,
    avg(avg_temperature_c) as avg_temperature_c,
    max(total_precipitation_mm) as total_precipitation_mm,
    max(had_significant_rain::int)::boolean as had_significant_rain,
    avg(count(*)) over (
        partition by zone_id, mode, extract(hour from trip_hour), extract(dayofweek from trip_hour)
        order by trip_date
        rows between 28 preceding and 1 preceding
    ) as baseline_demand_4w
from base
group by zone_id, mode, trip_hour, trip_date, avg_temperature_c, total_precipitation_mm, had_significant_rain
