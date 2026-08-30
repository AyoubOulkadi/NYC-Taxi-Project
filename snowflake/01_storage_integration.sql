

USE ROLE ACCOUNTADMIN;
USE DATABASE NYC_PROJECT;

-- 1) Storage integration : Snowflake obtient un accès délégué (pas de clé stockée en clair)
CREATE STORAGE INTEGRATION IF NOT EXISTS INT_ADLS_NYC
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'AZURE'
  ENABLED = TRUE
  AZURE_TENANT_ID = '<AZURE_TENANT_ID>'
  STORAGE_ALLOWED_LOCATIONS = (
    'azure://<STORAGE_ACCOUNT_NAME>.blob.core.windows.net/landing',
    'azure://<STORAGE_ACCOUNT_NAME>.blob.core.windows.net/raw'
  );

-- 2) Récupère les infos d'identité générées par Snowflake pour cette intégration
DESC STORAGE INTEGRATION INT_ADLS_NYC;


-- 3) Stages externes (un par container)
CREATE STAGE IF NOT EXISTS NYC_PROJECT.RAW.STAGE_LANDING
  STORAGE_INTEGRATION = INT_ADLS_NYC
  URL = 'azure://<STORAGE_ACCOUNT_NAME>.blob.core.windows.net/landing'
  FILE_FORMAT = (TYPE = 'CSV' SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"');

CREATE STAGE IF NOT EXISTS NYC_PROJECT.RAW.STAGE_RAW
  STORAGE_INTEGRATION = INT_ADLS_NYC
  URL = 'azure://<STORAGE_ACCOUNT_NAME>.blob.core.windows.net/raw'
  FILE_FORMAT = (TYPE = 'PARQUET');

GRANT USAGE ON STAGE NYC_PROJECT.RAW.STAGE_LANDING TO ROLE ROLE_NYC_PROJECT;
GRANT USAGE ON STAGE NYC_PROJECT.RAW.STAGE_RAW TO ROLE ROLE_NYC_PROJECT;

-- Vérification rapide (doit lister les fichiers uploadés à l'étape 3 du README)
LIST @NYC_PROJECT.RAW.STAGE_LANDING;
