-- Q1 2026 target attainment, salesperson grain rolled up to office.
-- Run with: dbt compile -s q1_2026_target_attainment  (then inspect compiled SQL)
-- or paste the compiled query into DuckDB.

with attainment as (

    select
        t.account_office,
        t.salesperson_id,
        d.salesperson_name,
        t.quarter_target,
        t.won_arr,
        t.attainment_pct,
        t.is_target_met
    from {{ ref('fct_target_attainment') }} t
    left join {{ ref('dim_salespeople') }} d using (salesperson_id)
    where t.target_quarter = '2026Q1'

)

select *
from attainment
order by is_target_met, attainment_pct
