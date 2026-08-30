-- =============================================================
-- 03_load_raw.sql — charge les fichiers uploadés en RAW
-- À lancer après chaque upload via scripts/load_to_adls.py
-- =============================================================

USE ROLE ROLE_NYC_PROJECT;
USE WAREHOUSE WH_NYC_PROJECT;
USE DATABASE NYC_PROJECT;

-- Exemple : charger les fichiers taxi du mois de janvier 2024
COPY INTO RAW.TAXI_TRIPS (
  VENDOR_ID, PICKUP_DATETIME, DROPOFF_DATETIME, PASSENGER_COUNT, TRIP_DISTANCE,
  PICKUP_LOCATION_ID, DROPOFF_LOCATION_ID, PAYMENT_TYPE, FARE_AMOUNT, TIP_AMOUNT,
  TOTAL_AMOUNT, SOURCE_FILE
)
FROM (
  SELECT
    $1:vendor_id::NUMBER,
    $1:pickup_datetime::TIMESTAMP_NTZ,
    $1:dropoff_datetime::TIMESTAMP_NTZ,
    $1:passenger_count::NUMBER,
    $1:trip_distance::FLOAT,
    $1:pickup_location_id::NUMBER,
    $1:dropoff_location_id::NUMBER,
    $1:payment_type::NUMBER,
    $1:fare_amount::FLOAT,
    $1:tip_amount::FLOAT,
    $1:total_amount::FLOAT,
    METADATA$FILENAME
  FROM @NYC_PROJECT.RAW.STAGE_RAW/taxi/2024-01/
)
FILE_FORMAT = (TYPE = 'PARQUET')
ON_ERROR = 'CONTINUE';   

-- Idem pour bike (adapter le chemin de stage et les colonnes CSV)
COPY INTO RAW.BIKE_TRIPS
FROM @NYC_PROJECT.RAW.STAGE_RAW/bike/2024-01/
FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 1)
ON_ERROR = 'CONTINUE';


SELECT COUNT(*) AS nb_taxi_trips, MIN(PICKUP_DATETIME), MAX(PICKUP_DATETIME) FROM RAW.TAXI_TRIPS;
SELECT COUNT(*) AS nb_bike_trips, MIN(STARTED_AT), MAX(STARTED_AT) FROM RAW.BIKE_TRIPS;

-- Historique des erreurs de chargement
SELECT * FROM TABLE(VALIDATE(RAW.TAXI_TRIPS, JOB_ID => '_last'));
