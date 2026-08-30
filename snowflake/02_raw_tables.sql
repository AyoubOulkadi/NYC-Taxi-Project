-- =============================================================
-- 02_raw_tables.sql — tables RAW (append-only, schéma souple)
-- Exécute avec ROLE_NYC_PROJECT
-- =============================================================

USE ROLE ROLE_NYC_PROJECT;
USE WAREHOUSE WH_NYC_PROJECT;
USE DATABASE NYC_PROJECT;
USE SCHEMA RAW;

-- Taxi trips (TLC monthly parquet — colonnes principales du dataset Yellow/Green Taxi)
CREATE TABLE IF NOT EXISTS RAW.TAXI_TRIPS (
  VENDOR_ID            NUMBER,
  PICKUP_DATETIME       TIMESTAMP_NTZ,
  DROPOFF_DATETIME      TIMESTAMP_NTZ,
  PASSENGER_COUNT        NUMBER,
  TRIP_DISTANCE          FLOAT,
  PICKUP_LOCATION_ID     NUMBER,
  DROPOFF_LOCATION_ID    NUMBER,
  PAYMENT_TYPE            NUMBER,
  FARE_AMOUNT              FLOAT,
  TIP_AMOUNT                FLOAT,
  TOTAL_AMOUNT               FLOAT,
  SOURCE_FILE                  STRING,      
  INGESTED_AT                   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Citi Bike trips (monthly CSV)
CREATE TABLE IF NOT EXISTS RAW.BIKE_TRIPS (
  RIDE_ID               STRING,
  RIDEABLE_TYPE           STRING,
  STARTED_AT               TIMESTAMP_NTZ,
  ENDED_AT                  TIMESTAMP_NTZ,
  START_STATION_ID           STRING,
  START_STATION_NAME          STRING,
  END_STATION_ID                STRING,
  END_STATION_NAME               STRING,
  START_LAT                       FLOAT,
  START_LNG                        FLOAT,
  END_LAT                           FLOAT,
  END_LNG                            FLOAT,
  MEMBER_CASUAL                       STRING,
  SOURCE_FILE                           STRING,
  INGESTED_AT                            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Weather (flux réel, appels API réguliers — voir scripts/weather_poller.py)
CREATE TABLE IF NOT EXISTS RAW.WEATHER_OBSERVATIONS (
  OBSERVED_AT        TIMESTAMP_NTZ,
  TEMPERATURE_C        FLOAT,
  PRECIPITATION_MM       FLOAT,
  WIND_SPEED_KMH            FLOAT,
  CONDITIONS                  STRING,
  RAW_PAYLOAD                   VARIANT,     
  INGESTED_AT                    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Schéma volontairement semi-structuré (VARIANT) : les events peuvent évoluer sans migration
CREATE TABLE IF NOT EXISTS RAW.RAW_EVENTS (
  EVENT_ID           STRING,
  EVENT_TYPE            STRING,       
  EVENT_TIME              TIMESTAMP_NTZ,  
  ZONE_ID                    STRING,
  PAYLOAD                      VARIANT,
  INGESTION_TIME                 TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Table de référence zones NYC (TLC Taxi Zone Lookup — à charger une fois, statique)
CREATE TABLE IF NOT EXISTS RAW.TAXI_ZONE_LOOKUP (
  LOCATION_ID   NUMBER,
  BOROUGH         STRING,
  ZONE              STRING,
  SERVICE_ZONE        STRING
);
