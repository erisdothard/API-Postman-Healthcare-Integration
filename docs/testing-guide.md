# Testing Guide

## ORU_Routing Channel Tests

### Send a critical lab result (Glucose HH)
```bash
curl -s -X POST http://localhost:8081 -H "Content-Type: text/plain" -d 'MSH|^~\&|LAB|LAB_FACILITY|EHR|EHR_FACILITY|20260415||ORU^R01|MSG001|P|2.5
PID|1||PAT001||Doe^John||19850101|M
OBR|1||ORD001|GLU^Glucose^L|||20260415|||||||||1234567890^Chen^Sarah
OBX|1|NM|GLU^Glucose^L||250|mg/dL|70-100|HH|||F' && echo ""
```
Expected: ACK response with MSA|AA, result routed to Critical file writer, written to both databases with ordering_provider = "Sarah Chen"

### Send a normal lab result (Creatinine N)
```bash
curl -s -X POST http://localhost:8081 -H "Content-Type: text/plain" -d 'MSH|^~\&|LAB|LAB_FACILITY|EHR|EHR_FACILITY|20260415||ORU^R01|MSG002|P|2.5
PID|1||PAT008||Williams^Sarah||19920703|F
OBR|1||ORD002|CREAT^Creatinine^L|||20260415|||||||||0987654321^Wilson^James
OBX|1|NM|CREAT^Creatinine^L||0.9|mg/dL|0.7-1.3|N|||F' && echo ""
```
Expected: ACK response, result routed to Normal file writer

### Send a malformed message (missing OBX)
```bash
curl -s -X POST http://localhost:8081 -H "Content-Type: text/plain" -d 'MSH|^~\&|LAB|LAB_FACILITY|EHR|EHR_FACILITY|20260415||ORU^R01|MSG003|P|2.5
PID|1||PAT999||Smith^Jane||19900515|F' && echo ""
```
Expected: No errors, UNKNOWN values in database, demonstrates error handling

### Verify database writes
```bash
psql -h localhost -p 5433 -U postgres -d bridgelink_db -c "SELECT patient_id, test_name, abnormal_flag, ordering_provider, admission_status FROM lab_results;"
```

## ADT_Processing Channel Tests

### Admit a patient (A01)
```bash
curl -s -X POST http://localhost:8083 -H "Content-Type: text/plain" -d 'MSH|^~\&|ADT|HOSPITAL|EHR|EHR_FACILITY|20260415||ADT^A01|ADT001|P|2.5
EVN|A01|20260415
PID|1||PAT101||Rivera^Carlos||19820915|M
PV1|1|I|ICU^101^A||||Smith^Sarah||||||||||||V001|||||||||||||||||||||||||20260415120000' && echo ""
```
Expected: New row in patients table with admission_status = ADMITTED

### Discharge the patient (A03)
```bash
curl -s -X POST http://localhost:8083 -H "Content-Type: text/plain" -d 'MSH|^~\&|ADT|HOSPITAL|EHR|EHR_FACILITY|20260415||ADT^A03|ADT002|P|2.5
EVN|A03|20260415
PID|1||PAT101||Rivera^Carlos||19820915|M
PV1|1|I|ICU^101^A||||Smith^Sarah||||||||||||V001|||||||||||||||||||||||||20260415120000' && echo ""
```
Expected: Same row updated to admission_status = DISCHARGED, discharge_date populated

### Update demographics (A08)
```bash
curl -s -X POST http://localhost:8083 -H "Content-Type: text/plain" -d 'MSH|^~\&|ADT|HOSPITAL|EHR|EHR_FACILITY|20260415||ADT^A08|ADT003|P|2.5
EVN|A08|20260415
PID|1||PAT101||Rivera^Carlos||19820915|M
PV1|1|I|ICU^101^A||||Wilson^Robert||||||||||||V001|||||||||||||||||||||||||20260415120000' && echo ""
```
Expected: Same row updated, attending_physician changed to Robert Wilson

### Duplicate admit (UPSERT test)
```bash
curl -s -X POST http://localhost:8083 -H "Content-Type: text/plain" -d 'MSH|^~\&|ADT|HOSPITAL|EHR|EHR_FACILITY|20260415||ADT^A01|ADT004|P|2.5
EVN|A01|20260415
PID|1||PAT101||Rivera^Carlos||19820915|M
PV1|1|I|ICU^101^A||||Smith^Sarah||||||||||||V001|||||||||||||||||||||||||20260415120000' && echo ""
```
Expected: No error, row updated via UPSERT

### Verify patients table
```bash
psql -h localhost -p 5433 -U postgres -d bridgelink_db -c "SELECT patient_id, admission_status, attending_physician, admit_date, discharge_date FROM patients;"
```

## Cross-Channel Test

### Send lab result for an admitted patient
```bash
# First admit PAT102
curl -s -X POST http://localhost:8083 -H "Content-Type: text/plain" -d 'MSH|^~\&|ADT|HOSPITAL|EHR|EHR_FACILITY|20260415||ADT^A01|ADT005|P|2.5
EVN|A01|20260415
PID|1||PAT102||Nguyen^Thanh||19750612|F
PV1|1|I|MED^202^B||||Johnson^James||||||||||||V002|||||||||||||||||||||||||20260415090000' && echo ""

# Then send a lab result for PAT102
curl -s -X POST http://localhost:8081 -H "Content-Type: text/plain" -d 'MSH|^~\&|LAB|LAB_FACILITY|EHR|EHR_FACILITY|20260415||ORU^R01|MSG004|P|2.5
PID|1||PAT102||Nguyen^Thanh||19750612|F
OBR|1||ORD004|GLU^Glucose^L|||20260415|||||||||1234567890^Chen^Sarah
OBX|1|NM|GLU^Glucose^L||88|mg/dL|70-100|N|||F' && echo ""
```
Expected: Lab result has admission_status = ADMITTED (cross-channel lookup)

```bash
psql -h localhost -p 5433 -U postgres -d bridgelink_db -c "SELECT patient_id, test_name, ordering_provider, admission_status FROM lab_results WHERE patient_id = 'PAT102';"
```

## FHIR API Tests

### Get all Observations
```bash
curl -s http://localhost:8082 | python3 -m json.tool
```
Expected: FHIR Bundle with Observation resources including LOINC codes

### Get Observations for specific patient
```bash
curl -s "http://localhost:8082?patient_id=PAT005" | python3 -m json.tool
```

### Get all Patients
```bash
curl -s http://localhost:8084 | python3 -m json.tool
```
Expected: FHIR Bundle with Patient resources including admission status
