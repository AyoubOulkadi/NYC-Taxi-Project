select
    zone_id,
    mode,
    trip_hour,
    trip_date,
    trip_count,
    baseline_demand_4w,
    case
        when baseline_demand_4w is null or baseline_demand_4w = 0 then null
        else round((trip_count - baseline_demand_4w) / baseline_demand_4w * 100, 1)
    end as pct_deviation_from_baseline,
    had_significant_rain,
    case
        when baseline_demand_4w > 0
             and (trip_count - baseline_demand_4w) / baseline_demand_4w >= 0.30
        then true
        else false
    end as is_demand_spike
from {{ ref('fct_zone_demand') }}
