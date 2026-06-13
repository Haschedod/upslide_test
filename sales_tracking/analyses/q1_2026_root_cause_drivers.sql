-- Drivers behind Q1 2026 attainment: win rate, deal size, sales cycle,
-- activity intensity (closed deals) vs pipeline generation (created deals).
-- Helps explain WHY a team over/under-performed against target.

with closed as (

    select
        salesperson_id,
        account_office,
        count(*) filter (where is_closed) as closed_deals,
        count(*) filter (where is_won) as won_deals,
        round(100.0 * count(*) filter (where is_won)
              / nullif(count(*) filter (where is_closed), 0), 1) as win_rate_pct,
        round(avg(arr) filter (where is_won), 0) as avg_won_deal_size,
        round(avg(sales_cycle_days) filter (where is_won), 1) as avg_sales_cycle_days,
        round(avg(total_activities) filter (where is_closed), 1) as avg_activities_per_closed_deal
    from {{ ref('fct_opportunities') }}
    where closed_quarter = '2026Q1'
      and is_valid_account
    group by 1, 2

),

created as (

    select
        salesperson_id,
        account_office,
        count(*) as opportunities_created,
        sum(arr) as pipeline_arr_created
    from {{ ref('fct_opportunities') }}
    where created_quarter = '2026Q1'
      and is_valid_account
    group by 1, 2

)

select
    c.salesperson_id,
    c.account_office,
    cr.opportunities_created,
    cr.pipeline_arr_created,
    c.closed_deals,
    c.won_deals,
    c.win_rate_pct,
    c.avg_won_deal_size,
    c.avg_sales_cycle_days,
    c.avg_activities_per_closed_deal
from closed c
left join created cr
    on c.salesperson_id = cr.salesperson_id
   and c.account_office = cr.account_office
order by c.win_rate_pct
