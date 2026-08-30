select
    zone_id,
    zone_name,
    borough,
    service_zone
from {{ ref('stg_taxi_zones') }}
