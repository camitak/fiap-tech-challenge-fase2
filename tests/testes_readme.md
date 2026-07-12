# Estratégia de testes

As validações deste projeto são executadas como Data Quality as Code.

Os testes estão localizados em:

- `src/batch/validate_bronze.sh`
- `sql/silver/validate_silver.sql`
- `src/silver/validate_silver.sh`
- `sql/gold/validate_gold.sql`
- `src/gold/validate_gold.sh`
- `sql/streaming/validate_streaming.sql`
- `src/streaming/validate_streaming.sh`
- `sql/ops/validate_observability.sql`
- `src/ops/validate_observability.sh`

Eles cobrem reconciliação, unicidade, completude, validade, consistência,
integridade de chaves, cobertura e latência.