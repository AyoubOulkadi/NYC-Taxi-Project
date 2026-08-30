-- Union taxi + bike sur un schéma commun, pour calculer la demande tous modes confondus par zone.

with taxi as (
    select
        trip_key as trip_id,
        mode,
        pickup_datetime as trip_start,
        zone_id
    from {{ ref('stg_taxi_trips') }}
),

bike as (
    select
        ride_id as trip_id,
        mode,
        started_at as trip_start,
        start_station_id as zone_id   
    from {{ ref('stg_bike_trips') }}
)

select * from taxi
union all
select * from bike
