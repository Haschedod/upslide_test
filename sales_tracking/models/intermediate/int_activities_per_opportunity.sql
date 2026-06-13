with activities as (

    select * from {{ ref('stg_activities') }}

),

aggregated as (

    select
        opportunity_id,
        count(*) as total_activities,
        count(*) filter (where activity_type = 'call') as calls,
        count(*) filter (where activity_type = 'linkedin') as linkedin_touches,
        count(*) filter (where activity_type = 'meeting_online') as meetings_online,
        count(*) filter (where activity_type = 'meeting_f2f') as meetings_f2f,
        min(activity_date) as first_activity_date,
        max(activity_date) as last_activity_date
    from activities
    group by opportunity_id

)

select * from aggregated
