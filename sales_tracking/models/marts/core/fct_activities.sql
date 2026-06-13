with activities as (

    select * from {{ ref('stg_activities') }}

),

opportunities as (

    select * from {{ ref('int_opportunities_enriched') }}

),

final as (

    select
        a.activity_id,
        a.opportunity_id,
        a.activity_type,
        a.activity_date,

        o.salesperson_id,
        o.account_id,
        o.account_office,
        o.salesperson_office,
        o.status as opportunity_status,
        o.opportunity_type

    from activities a
    left join opportunities o on a.opportunity_id = o.opportunity_id

)

select * from final
