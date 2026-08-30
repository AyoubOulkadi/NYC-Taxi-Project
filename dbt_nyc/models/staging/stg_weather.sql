
select
    observed_at,
    temperature_c,
    precipitation_mm,
    wind_speed_kmh,
    conditions,
    case when precipitation_mm > 2.5 then true else false end as is_significant_rain,
    ingested_at
from {{ source('raw', 'weather_observations') }}
