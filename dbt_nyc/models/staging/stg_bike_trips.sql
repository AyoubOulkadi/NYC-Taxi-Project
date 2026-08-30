
{{
  config(
    materialized='incremental',
    unique_key='ride_id',
    incremental_strategy='merge'
  )
}}

with source as (
    select * from {{ source('raw', 'bike_trips') }}
    {% if is_incremental() %}
    where ingested_at > (select coalesce(max(ingested_at), '1900-01-01') from {{ this }})
    {% endif %}
),

cleaned as (
    select
        ride_id,
        rideable_type,
        started_at,
        ended_at,
        datediff('minute', started_at, ended_at) as trip_duration_minutes,
        start_station_id,
        start_station_name,
        end_station_id,
        end_station_name,
        start_lat,
        start_lng,
        member_casual,
        source_file,
        ingested_at,
        'bike' as mode
    from source
    where
        started_at is not null
        and ended_at > started_at
        and datediff('minute', started_at, ended_at) < 24 * 60  
)

select * from cleaned
