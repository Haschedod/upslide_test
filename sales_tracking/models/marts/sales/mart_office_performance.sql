{#
    Office-level rollup for Q1 2026: how each office performed against target
    and the operational drivers that explain the gap (win rate, deal size,
    sales cycle, activity intensity, pipeline creation).
#}

{% set quarter = '2026Q1' %}

with attainment as (

    select
        account_office,
        sum(quarter_target) as quarter_target,
        sum(won_arr) as won_arr,
        sum(won_arr_new_business) as won_arr_new_business,
        sum(won_arr_upsell) as won_arr_upsell,
        count(*) as salespeople_with_target,
        count(*) filter (where is_target_met) as salespeople_on_target
    from {{ ref('fct_target_attainment') }}
    where target_quarter = '{{ quarter }}'
    group by 1

),

closed_q1 as (

    select *
    from {{ ref('fct_opportunities') }}
    where closed_quarter = '{{ quarter }}'
      and is_valid_account

),

deal_metrics as (

    select
        account_office,
        count(*) filter (where is_closed) as closed_deals,
        count(*) filter (where is_won) as won_deals,
        count(*) filter (where status = 'lost') as lost_deals,
        round(avg(arr) filter (where is_won), 0) as avg_won_deal_size,
        round(avg(sales_cycle_days) filter (where is_won), 1) as avg_sales_cycle_days,
        round(avg(total_activities) filter (where is_closed), 1) as avg_activities_per_closed_deal
    from closed_q1
    group by 1

),

created_q1 as (

    select
        account_office,
        count(*) as opportunities_created
    from {{ ref('fct_opportunities') }}
    where created_quarter = '{{ quarter }}'
      and is_valid_account
    group by 1

),

final as (

    select
        a.account_office,
        a.quarter_target,
        a.won_arr,
        a.won_arr_new_business,
        a.won_arr_upsell,
        a.won_arr - a.quarter_target as gap_to_target,
        round(a.won_arr * 100.0 / nullif(a.quarter_target, 0), 1) as attainment_pct,
        a.won_arr >= a.quarter_target as is_target_met,
        a.salespeople_with_target,
        a.salespeople_on_target,

        d.closed_deals,
        d.won_deals,
        d.lost_deals,
        round(d.won_deals * 100.0 / nullif(d.closed_deals, 0), 1) as win_rate_pct,
        d.avg_won_deal_size,
        d.avg_sales_cycle_days,
        d.avg_activities_per_closed_deal,

        c.opportunities_created

    from attainment a
    left join deal_metrics d on a.account_office = d.account_office
    left join created_q1 c on a.account_office = c.account_office

)

select * from final
order by attainment_pct
