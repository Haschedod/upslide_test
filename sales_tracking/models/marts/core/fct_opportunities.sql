with opportunities as (

    select * from {{ ref('int_opportunities_enriched') }}

),

activities as (

    select * from {{ ref('int_activities_per_opportunity') }}

),

final as (

    select
        o.opportunity_id,
        o.account_id,
        o.salesperson_id,
        o.account_name,
        o.account_office,
        o.salesperson_name,
        o.salesperson_office,

        o.created_date,
        o.closed_date,
        o.created_quarter,
        o.closed_quarter,
        o.sales_cycle_days,

        o.arr,
        o.status,
        o.opportunity_type,
        o.lead_source,

        o.is_valid_account,
        o.is_won,
        o.is_closed,

        coalesce(a.total_activities, 0) as total_activities,
        coalesce(a.calls, 0) as calls,
        coalesce(a.linkedin_touches, 0) as linkedin_touches,
        coalesce(a.meetings_online, 0) as meetings_online,
        coalesce(a.meetings_f2f, 0) as meetings_f2f,
        a.first_activity_date,
        a.last_activity_date

    from opportunities o
    left join activities a on o.opportunity_id = a.opportunity_id

)

select * from final
