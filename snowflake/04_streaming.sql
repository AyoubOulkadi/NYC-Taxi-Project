-- =============================================================
-- 04_streaming.sql — near-real-time in-warehouse 
-- =============================================================

USE ROLE ROLE_NYC_PROJECT;
USE WAREHOUSE WH_NYC_PROJECT;
USE DATABASE NYC_PROJECT;

-- 1) Dédoublonnage à la volée (équivalent dropDuplicatesWithinWatermark de Structured Streaming)
CREATE OR REPLACE DYNAMIC TABLE INTERMEDIATE.EVENTS_DEDUPED
  TARGET_LAG = '1 minute'
  WAREHOUSE = WH_NYC_PROJECT
AS
SELECT *
FROM (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY EVENT_ID ORDER BY INGESTION_TIME DESC) AS rn
    FROM RAW.RAW_EVENTS
)
WHERE rn = 1;

-- 2) Agrégation near-real-time : demande par zone sur fenêtre glissante 15 min
--    (équivalent fonctionnel du watermark + fenêtrage Structured Streaming,
--     recalculé automatiquement toutes les TARGET_LAG grâce au refresh incrémental)
CREATE OR REPLACE DYNAMIC TABLE MARTS.RT_ZONE_DEMAND_15MIN
  TARGET_LAG = '1 minute'
  WAREHOUSE = WH_NYC_PROJECT
AS
SELECT
    ZONE_ID,
    EVENT_TYPE,
    TIME_SLICE(EVENT_TIME, 15, 'MINUTE') AS window_start,
    COUNT(*) AS event_count
FROM INTERMEDIATE.EVENTS_DEDUPED
WHERE EVENT_TIME >= DATEADD('hour', -6, CURRENT_TIMESTAMP())  
  AND EVENT_TYPE IN ('taxi_trip', 'bike_trip')
GROUP BY ZONE_ID, EVENT_TYPE, TIME_SLICE(EVENT_TIME, 15, 'MINUTE');

-- 3) Détection de pic (consommé par le tool Anomaly Detection de l'agent, en complément
CREATE OR REPLACE DYNAMIC TABLE MARTS.RT_DEMAND_SPIKES
  TARGET_LAG = '1 minute'
  WAREHOUSE = WH_NYC_PROJECT
AS
SELECT
    r.ZONE_ID,
    r.window_start,
    r.event_count AS current_count,
    b.baseline_demand_4w,
    CASE
        WHEN b.baseline_demand_4w > 0
             AND (r.event_count - b.baseline_demand_4w) / b.baseline_demand_4w >= 0.30
        THEN TRUE ELSE FALSE
    END AS is_spike
FROM MARTS.RT_ZONE_DEMAND_15MIN r
LEFT JOIN MARTS.FCT_ZONE_DEMAND b
    ON r.ZONE_ID = b.ZONE_ID
   AND EXTRACT(HOUR FROM r.window_start) = EXTRACT(HOUR FROM b.trip_hour);

GRANT SELECT ON MARTS.RT_ZONE_DEMAND_15MIN TO ROLE ROLE_AGENT_READONLY;
GRANT SELECT ON MARTS.RT_DEMAND_SPIKES TO ROLE ROLE_AGENT_READONLY;
