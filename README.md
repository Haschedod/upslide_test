# Sales Tracking — Analytics Engineering pipeline

A dbt + DuckDB pipeline that turns the raw sales CSVs into a reliable, tested,
business-ready data model, and answers the Head of Sales' question:
**why did some teams miss their Q1 2026 targets?**

## TL;DR findings (Q1 2026)

- At **office** level, only **Germany** missed target (86.7% attainment). France, UK, US and Singapore all exceeded.
- At **salesperson** level, **3 of 11** reps missed:

  | Rep | Office | Attainment | Primary reason |
  |-----|--------|-----------:|----------------|
  | SP009 | Germany | **0%** | Closing breakdown: healthy open pipeline (15 open deals) but only 1 deal closed in the quarter (and it was lost). Conversion, not lead-gen, is the problem. |
  | SP001 | France | **76.5%** | Largest pipeline created (84 deals) but lowest win rate (26%) and one of the smallest avg deal sizes (~11k). Quantity over quality. |
  | SP005 | UK | **97.1%** | Near miss: low closed-deal volume (18) and the lowest activity intensity (1.7 activities/deal). |

- Germany's office miss is driven entirely by SP009's zero; SP008 (also selling into Germany) over-delivered and partly offset it.

See [sales_tracking/analyses/q1_2026_target_attainment.sql](sales_tracking/analyses/q1_2026_target_attainment.sql) and
[sales_tracking/analyses/q1_2026_root_cause_drivers.sql](sales_tracking/analyses/q1_2026_root_cause_drivers.sql) for the queries.

## Architecture

```
seeds (raw CSV)
  -> staging      (views)  light cleaning, typing, 1:1 with sources
  -> intermediate (views)  joins + business logic
  -> marts        (tables) dims, facts, and business-facing aggregates
```

- **staging** (`stg_*`): typing, renaming, NULL handling, date normalisation, deduplication.
- **intermediate** (`int_*`): `int_opportunities_enriched` (opportunity + account + salesperson, flags, sales cycle, quarter labels), `int_activities_per_opportunity` (activity rollup).
- **marts**
  - core: `dim_accounts`, `dim_salespeople`, `fct_opportunities` (one row per deal), `fct_activities` (one row per activity).
  - sales: `fct_target_attainment` (salesperson x office x quarter vs target), `mart_office_performance` (office rollup + operational drivers).

## Modelling decisions

- **Attainment** = ARR of opportunities with `status = 'won'` whose `closed_date` falls in the target quarter, attributed to `salesperson_id` + the account's `account_office`, compared to `quarter_target`.
- **Grain**: reported at salesperson level and rolled up to office.
- **Quarter label** uses `YYYYQn` to match `targets.target_quarter`.

## Data-quality handling

The raw seeds contain deliberate quality issues, all handled in staging and surfaced via tests:

| Issue | Where | Handling |
|-------|-------|----------|
| 4 different date formats in `opportunities` (ISO, ISO timestamp, `YYYY/MM/DD`, `DD/MM/YYYY`) | `stg_opportunities` | `clean_date` macro (`sales_tracking/macros/clean_date.sql`) coalesces multiple `try_strptime` formats. Fixed ~89 silently-nulled dates. |
| 15 duplicated `activity_id` (30 rows) | `stg_activities` | `qualify row_number()` keeps the earliest record. |
| 10 opportunities referencing non-existent accounts (`ACC_MISSING_*`) | `int_opportunities_enriched` | Retained and flagged with `is_valid_account`; excluded from office attribution. The staging relationships test is set to `warn` so it stays visible without blocking the pipeline. |
| Empty strings in `source` / `activity_type` | staging | Converted to `NULL`. |

Testing has two layers:

- **Data tests** (run against real data): primary-key `unique`/`not_null`, `relationships` (referential integrity), `accepted_values` (status/type), `dbt_utils.unique_combination_of_columns` (target grain), and `dbt_utils.accepted_range` (non-negative ARR).
- **Unit tests** (logic against mocked inputs, in `_*__unit_tests.yml`): cover every model, including the `clean_date` multi-format parsing, activity deduplication, enrichment flags / sales-cycle / quarter labels, activity-count coalescing, attainment math (won + valid-account filtering, `is_target_met`), and the office rollup.

Current run: 78 pass, 1 warn (expected orphan accounts), 0 errors. Run only the
unit tests with `dbt test --select test_type:unit`.

Note: the intermediate layer is materialized as **views** (not ephemeral) so the
models exist as relations that unit tests can introspect when mocked as inputs to
downstream models.

## How to run

```bash
# from the repo root
source .venv/bin/activate
cd sales_tracking

dbt deps      # install dbt_utils
dbt build     # seed CSVs + build all models + run tests
```

Inspect results in DuckDB:

```bash
duckdb dev.duckdb "select * from mart_office_performance;"
```

## Project layout

```
requirements.txt              dbt + reporting dependencies
reports/
  generate_dashboards.py      builds slide-ready PNGs from the marts
sales_tracking/               the dbt project
  dbt_project.yml
  models/
    staging/      stg_*.sql  + _stg__models.yml  + _stg__unit_tests.yml
    intermediate/ int_*.sql  + _int__models.yml  + _int__unit_tests.yml
    marts/
      core/       dim_*, fct_opportunities, fct_activities + _core__models.yml + _core__unit_tests.yml
      sales/      fct_target_attainment, mart_office_performance + _sales__models.yml + _sales__unit_tests.yml
  macros/clean_date.sql
  analyses/       q1_2026_*.sql
  seeds/          raw CSVs
```

## Reporting (slides)

`reports/generate_dashboards.py` (at the repo root) reads the marts from
`dev.duckdb` and writes charts into `reports/figures/`:

1. Office attainment vs target (the headline).
2. Won ARR vs target by office, split new business / upsell.
3. Salesperson attainment (met vs missed).
4. Performance drivers (win rate, average deal size).
5. SP009 pipeline by status (the closing-breakdown story).

```bash
# from the repo root, after dbt build
source .venv/bin/activate
pip install -r requirements.txt
python reports/generate_dashboards.py
```

The figures regenerate from the pipeline output, so they always match the marts.

