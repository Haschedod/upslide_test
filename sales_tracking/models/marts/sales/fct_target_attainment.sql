with targets as (

    select * from {{ ref('stg_targets') }}

),

-- won revenue attributed to the salesperson + the account's office,
-- in the quarter the deal was closed. Orphan-account deals are excluded
-- because they have no office to attribute to.
won as (

    select
        salesperson_id,
        account_office,
        closed_quarter as target_quarter,
        -- new ARR = new business + upsell (expansion); no renewals in scope
        sum(arr) as won_arr,
        sum(arr) filter (where opportunity_type = 'new business') as won_arr_new_business,
        sum(arr) filter (where opportunity_type = 'upsell') as won_arr_upsell,
        count(*) as won_deals
    from {{ ref('fct_opportunities') }}
    where is_won
      and is_valid_account
    group by 1, 2, 3

),

final as (

    select
        t.salesperson_id,
        t.account_office,
        t.target_quarter,
        t.quarter_target,
        coalesce(w.won_arr, 0) as won_arr,
        coalesce(w.won_arr_new_business, 0) as won_arr_new_business,
        coalesce(w.won_arr_upsell, 0) as won_arr_upsell,
        coalesce(w.won_deals, 0) as won_deals,
        coalesce(w.won_arr, 0) - t.quarter_target as gap_to_target,
        round(coalesce(w.won_arr, 0) * 100.0 / nullif(t.quarter_target, 0), 1) as attainment_pct,
        coalesce(w.won_arr, 0) >= t.quarter_target as is_target_met
    from targets t
    left join won w
        on  t.salesperson_id = w.salesperson_id
        and t.account_office = w.account_office
        and t.target_quarter = w.target_quarter

)

select * from final
