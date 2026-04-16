# Healthcare Integration Portfolio

End-to-end healthcare integration system built with BridgeLink (Mirth Connect), demonstrating HL7 v2.5 message processing, FHIR R4 API exposure, multi-database routing, mid-flight data enrichment, and cross-channel data flow.

## Architecture

```
┌─────────────────┐         ┌──────────────────────────────────────────────────────┐
│  Lab System      │         │                  BridgeLink                          │
│  (HL7 ORU^R01)   │────────▶│  ORU_Routing Channel (port 8081)                    │
└─────────────────┘         │    ├─ Parse PID, OBR, OBX segments                   │
                            │    ├─ Provider NPI lookup (OBR-16 → providers table)  │
                            │    ├─ Patient status lookup (→ patients table)        │
                            │    ├─▶ Critical file writer (HH, LL flags)           │
                            │    ├─▶ Normal file writer (N flag)                   │
                            │    ├─▶ Database Writer → bridgelink_db.lab_results   │
                            │    └─▶ Database Writer → mirthdb.lab_results         │
                            │                                                      │
┌─────────────────┐         │  ADT_Processing Channel (port 8083)                  │
│  Hospital ADT    │────────▶│    ├─ Parse event type (A01/A03/A08)                │
│  (HL7 ADT)       │         │    ├─ UPSERT to patients table                      │
└─────────────────┘         │    └─ Handles admit, discharge, update               │
                            │                                                      │
                            │  FHIR_API Channel (port 8082)                        │
┌─────────────────┐         │    ├─ Reads from mirthdb.lab_results                 │
│  Modern App      │◀───────│    ├─ Returns FHIR R4 Observation Bundle             │
│  (REST/JSON)     │         │    └─ LOINC coded with interpretation flags          │
│                  │         │                                                      │
│                  │◀───────│  FHIR_Patient_API Channel (port 8084)                │
└─────────────────┘         │    ├─ Reads from bridgelink_db.patients              │
                            │    └─ Returns FHIR R4 Patient Bundle                 │
                            └──────────────────────────────────────────────────────┘

                            ┌──────────────────────────────────────────────────────┐
                            │                   PostgreSQL                         │
                            │                                                      │
                            │  bridgelink_db          mirthdb                      │
                            │  ├─ lab_results         ├─ lab_results               │
                            │  ├─ patients            └──────────────              │
                            │  └─ providers (reference)                            │
                            └──────────────────────────────────────────────────────┘
```

## What This Demonstrates

**HL7 v2.5 Processing**
- ORU^R01 (lab results) and ADT^A01/A03/A08 (patient movement) message parsing
- Segment extraction: MSH, PID, PV1, OBR, OBX, EVN
- ACK (MSH+MSA) response generation for every inbound message
- Error handling with try-catch on all field reads — malformed messages don't crash channels

**FHIR R4 API Layer**
- Observation resources with LOINC coding (2345-7 Glucose, 2823-3 Potassium, 6690-2 WBC, 718-7 Hemoglobin, 2160-0 Creatinine)
- Patient resources with proper name structure (family/given), gender mapping, and admission status
- FHIR Bundle responses with searchset type
- Unit coding via http://unitsofmeasure.org
- Interpretation codes via HL7 ObservationInterpretation CodeSystem

**Integration Patterns**
- Conditional routing: critical vs normal lab results to separate destinations
- Multi-destination output: one inbound message writes to files and two databases
- Mid-flight enrichment: NPI lookup from OBR-16 against provider reference table
- Cross-channel data flow: ORU channel reads patient admission status from ADT channel's database
- UPSERT logic: duplicate ADT messages update existing rows instead of failing
- Date casting: HL7 date strings (YYYYMMDD) to PostgreSQL DATE/TIMESTAMP types

## Tech Stack

- **Integration Engine**: BridgeLink 4.6.1 (Mirth Connect fork by Innovar Healthcare)
- **Database**: PostgreSQL 14+ (two databases: bridgelink_db, mirthdb)
- **Standards**: HL7 v2.5, FHIR R4, LOINC, HL7 FHIR terminology
- **Language**: JavaScript (BridgeLink transformers and JavaScript Writers)
- **Testing**: curl, psql

## Project Structure

```
healthcare-integration-portfolio/
├── README.md
├── channels/
│   ├── ORU_Routing.xml
│   ├── ADT_Processing.xml
│   ├── FHIR_API.xml
│   └── FHIR_Patient_API.xml
├── database/
│   ├── schema.sql
│   └── seed-data.sql
├── test-messages/
│   ├── oru/
│   │   ├── glucose-critical.hl7
│   │   ├── glucose-normal.hl7
│   │   ├── potassium-critical.hl7
│   │   ├── wbc-normal.hl7
│   │   ├── hemoglobin-critical.hl7
│   │   ├── creatinine-normal.hl7
│   │   └── missing-obx.hl7
│   └── adt/
│       ├── admit-a01.hl7
│       ├── discharge-a03.hl7
│       ├── update-a08.hl7
│       └── duplicate-admit.hl7
├── fhir-examples/
│   ├── observation-response.json
│   └── patient-response.json
└── docs/
    ├── setup-guide.md
    └── testing-guide.md
```

## Quick Start

1. Install BridgeLink 4.6.1 and PostgreSQL
2. Run database setup: `psql -f database/schema.sql` against both databases
3. Seed provider data: `psql -d bridgelink_db -f database/seed-data.sql`
4. Import all four channel XML files into BridgeLink
5. Deploy channels
6. See [Setup Guide](docs/setup-guide.md) for detailed instructions

## Testing

See [Testing Guide](docs/testing-guide.md) for complete test scenarios including:
- Critical and normal lab result routing
- Patient admit/discharge/update lifecycle
- Cross-channel enrichment verification
- FHIR API response validation
- Error handling with malformed messages

## Key Design Decisions

**Why two databases?** Demonstrates multi-destination routing — a single HL7 message writing to multiple data stores simultaneously, which is common in production where different systems consume the same data.

**Why UPSERT for ADT?** Hospital systems frequently resend messages (interface restarts, message replays). Without UPSERT, duplicate admits would crash the integration. ON CONFLICT DO UPDATE makes the system resilient to duplicates.

**Why mid-flight enrichment?** Lab systems send NPI numbers, not provider names. The receiving system needs human-readable data. Looking up the provider during transformation is how production integrations add context to raw messages.

**Why cross-channel lookup?** Lab results in isolation lack clinical context. Knowing whether a patient is currently admitted when their lab result arrives enables clinical decision support — a critical glucose on an admitted ICU patient is handled differently than one from an outpatient visit.

**Why LOINC codes?** FHIR Observations without standardized terminology coding are not interoperable. LOINC is the universal standard for lab test identification. Including proper coding demonstrates awareness of real-world FHIR compliance requirements.
