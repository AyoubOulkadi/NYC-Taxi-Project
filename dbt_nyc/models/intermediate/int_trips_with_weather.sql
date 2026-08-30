-- Rattache chaque trip à l'observation météo la plus proche dans le temps (fenêtre horaire).

with trips as (
    select *, date_trunc('hour', trip_start) as trip_hour
    from {{ ref('int_trips_unioned') }}
),

weather_hourly as (
    select
        date_trunc('hour', observed_at) as weather_hour,
        avg(temperature_c) as avg_temperature_c,
        sum(precipitation_mm) as total_precipitation_mm,
        max(is_significant_rain::int)::boolean as had_significant_rain
    from {{ ref('stg_weather') }}
    group by 1
)

select
    trips.*,
    weather_hourly.avg_temperature_c,
    weather_hourly.total_precipitation_mm,
    weather_hourly.had_significant_rain
from trips
left join weather_hourly
    on trips.trip_hour = weather_hourly.weather_hour
