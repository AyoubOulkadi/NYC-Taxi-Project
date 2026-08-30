

{{
  config(
    materialized='incremental',
    unique_key='trip_key',
    incremental_strategy='merge'
  )
}}

with source as (
    select * from {{ source('raw', 'taxi_trips') }}
    {% if is_incremental() %}
    where ingested_at > (select coalesce(max(ingested_at), '1900-01-01') from {{ this }})
    {% endif %}
),

cleaned as (
    select
        {{ dbt_utils.generate_surrogate_key(['vendor_id', 'pickup_datetime', 'pickup_location_id', 'dropoff_location_id']) }} as trip_key,
        vendor_id,
        pickup_datetime,
        dropoff_datetime,
        datediff('minute', pickup_datetime, dropoff_datetime) as trip_duration_minutes,
        passenger_count,
        trip_distance,
        pickup_location_id as zone_id,
        dropoff_location_id,
        payment_type,
        fare_amount,
        tip_amount,
        total_amount,
        source_file,
        ingested_at,
        'taxi' as mode
    from source
    where
        -- règles de qualité de base : pas de trip négatif/aberrant
        pickup_datetime is not null
        and dropoff_datetime > pickup_datetime
        and trip_distance >= 0
        and fare_amount >= 0
        and passenger_count between 0 and 8
)

select * from cleaned
