# NYC Intelligent Mobility Platform — Implémentation

Squelette de projet complet correspondant au blueprint (Azure + Snowflake + dbt).
Ordre d'exécution ci-dessous. Chaque étape suppose que la précédente est terminée.

## Pré-requis

- Compte Azure (avec droits de créer des ressources : RG, Storage, Event Hubs, Key Vault)
- Compte Snowflake (trial gratuit possible : https://signup.snowflake.com, choisir la région **Azure**)
- Azure CLI installé + connecté (`az login`)
- Terraform >= 1.5
- Python 3.10+
- dbt-core + dbt-snowflake (`pip install dbt-core dbt-snowflake`)
- SnowSQL ou l'UI Snowflake (Snowsight) pour lancer les scripts SQL

## Étape 1 — Infra Azure (Terraform)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # renseigne tes valeurs
terraform init
terraform plan
terraform apply
```

Crée : Resource Group, Storage Account (ADLS Gen2, hierarchical namespace), containers `raw` et `landing`,
Event Hubs Namespace + Event Hub (`nyc-events`), Key Vault.
Récupère les outputs (`terraform output`) : tu en auras besoin pour Snowflake et les scripts Python.

## Étape 2 — Snowflake (SQL)

Dans Snowsight, exécute dans l'ordre (en tant que `ACCOUNTADMIN` puis rôle projet) :

```bash
snowflake/00_setup.sql               # database, warehouse, rôles
snowflake/01_storage_integration.sql # connexion Snowflake <-> ADLS (à adapter avec tes valeurs Terraform)
snowflake/02_raw_tables.sql          # tables RAW (taxi, bike, weather, events)
```

## Étape 3 — Scripts d'ingestion 

```bash
cd scripts
cp .env.example .env    # renseigne connection strings Azure + Snowflake
pip install -r requirements.txt
python load_to_adls.py --source taxi --month 2024-01
python load_to_adls.py --source bike --month 2024-01
```

Puis, dans Snowsight, lance un `COPY INTO` (fourni dans `snowflake/03_load_raw.sql`) ou configure Snowpipe pour l'auto-ingestion.

## Étape 4 — dbt (staging → marts)

```bash
cd dbt_nyc
cp profiles.yml.example ~/.dbt/profiles.yml   # renseigne tes creds Snowflake
dbt deps
dbt debug          # vérifie la connexion
dbt run            # exécute staging -> intermediate -> marts
dbt test           # lance les tests de qualité
dbt docs generate && dbt docs serve   # lineage visuel
```

## Étape 5 — Streaming simulé + near-real-time Snowflake

```bash
# Terminal 1 : flux météo réellement live
python scripts/weather_poller.py --interval 300

# Terminal 2 : rejeu de l'historique taxi/bike comme flux d'événements
python scripts/event_replay_simulator.py --source taxi --input path/to/taxi_2024-01.parquet --limit 5000
```

Côté Snowflake :
1. Configure le **Kafka connector Snowflake** pour consommer l'Event Hub `nyc-events`
   (endpoint compatible Kafka — voir doc Snowflake "Snowpipe Streaming with Kafka connector",
   utilise `eventhub_consumer_connection_string` de Terraform).
2. Lance `snowflake/04_streaming.sql` : crée les Dynamic Tables de dédup et d'agrégation
   near-real-time (`RT_ZONE_DEMAND_15MIN`, `RT_DEMAND_SPIKES`) — équivalent fonctionnel
   de Structured Streaming, sans cluster Spark à gérer.

## Ce qui est livré à date

| Phase | Statut | Fichiers |
|---|---|---|
| 1–2. Infra Azure | ✅ Code prêt | `terraform/` |
| 2. Snowflake setup | ✅ Code prêt | `snowflake/00_setup.sql`, `01_storage_integration.sql` |
| 3. Ingestion → ADLS → RAW | ✅ Code prêt | `scripts/load_to_adls.py`, `snowflake/02_raw_tables.sql`, `03_load_raw.sql` |
| 4. dbt staging/intermediate/marts | ✅ Code prêt | `dbt_nyc/models/` (taxi, bike, weather, zones, demande, anomalies) |
| 5. Streaming simulé + Dynamic Tables | ✅ Code prêt | `scripts/event_replay_simulator.py`, `weather_poller.py`, `snowflake/04_streaming.sql` |

