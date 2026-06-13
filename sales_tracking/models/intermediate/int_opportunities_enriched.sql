with opportunities as (

    select * from {{ ref('stg_opportunities') }}

),

accounts as (

    select * from {{ ref('stg_accounts') }}

),

salespeople as (

    select * from {{ ref('stg_salespeople') }}

),

enriched as (

    select
        o.opportunity_id,
        o.account_id,
        o.salesperson_id,

        a.account_name,
        a.account_office,
        s.salesperson_name,
        s.salesperson_office,

        o.created_date,
        o.closed_date,
        o.arr,
        o.status,
        o.lead_source,
        o.opportunity_type,

        -- flags
        a.account_id is not null as is_valid_account,
        o.status = 'won' as is_won,
        o.status in ('won', 'lost') as is_closed,

        -- time-to-close in days (only meaningful once both dates are known)
        case
            when o.created_date is not null and o.closed_date is not null
            then date_diff('day', o.created_date, o.closed_date)
        end as sales_cycle_days,

        -- quarter labels in YYYYQn form to match targets.target_quarter
        case
            when o.created_date is not null
            then extract(year from o.created_date)::varchar
                 || 'Q' || extract(quarter from o.created_date)::varchar
        end as created_quarter,
        case
            when o.closed_date is not null
            then extract(year from o.closed_date)::varchar
                 || 'Q' || extract(quarter from o.closed_date)::varchar
        end as closed_quarter

    from opportunities o
    left join accounts a on o.account_id = a.account_id
    left join salespeople s on o.salesperson_id = s.salesperson_id

)

select * from enriched
