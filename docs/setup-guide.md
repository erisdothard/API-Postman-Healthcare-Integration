# Setup Guide

## Prerequisites

- BridgeLink 4.6.1 (or Mirth Connect 4.x)
- PostgreSQL 14+
- pgAdmin (optional, for visual database management)
- curl (for testing)

## Database Setup

1. Start PostgreSQL on port 5433 (or adjust connection strings in channels)

2. Create two databases:
```bash
psql -h localhost -p 5433 -U postgres -c "CREATE DATABASE bridgelink_db;"
psql -h localhost -p 5433 -U postgres -c "CREATE DATABASE mirthdb;"
```

3. Run the schema script against both databases:
```bash
psql -h localhost -p 5433 -U postgres -d bridgelink_db -f database/schema.sql
psql -h localhost -p 5433 -U postgres -d mirthdb -f database/schema.sql
```

4. Seed the provider reference data (bridgelink_db only):
```bash
psql -h localhost -p 5433 -U postgres -d bridgelink_db -f database/seed-data.sql
```

## Channel Import

1. Open BridgeLink Administrator (https://localhost:8443)
2. Go to Channels > Import Channel
3. Import each XML file from the `channels/` directory:
   - ORU_Routing.xml
   - ADT_Processing.xml
   - FHIR_API.xml
   - FHIR_Patient_API.xml
4. Verify JDBC connection strings match your PostgreSQL setup
5. Deploy all channels

## Port Assignments

| Channel | Port | Purpose |
|---------|------|---------|
| ORU_Routing | 8081 | Receives HL7 ORU lab result messages |
| ADT_Processing | 8083 | Receives HL7 ADT patient movement messages |
| FHIR_API | 8082 | REST endpoint for FHIR Observation resources |
| FHIR_Patient_API | 8084 | REST endpoint for FHIR Patient resources |

## Verify Setup

After deploying all channels, test each one:

```bash
# Send a lab result
curl -s -X POST http://localhost:8081 -H "Content-Type: text/plain" -d @test-messages/oru/glucose-critical.hl7

# Send a patient admission
curl -s -X POST http://localhost:8083 -H "Content-Type: text/plain" -d @test-messages/adt/admit-a01.hl7

# Query FHIR Observations
curl -s http://localhost:8082 | python3 -m json.tool

# Query FHIR Patients
curl -s http://localhost:8084 | python3 -m json.tool
```
