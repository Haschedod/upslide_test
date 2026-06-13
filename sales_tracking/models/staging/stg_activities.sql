with src as (

    select * from {{ ref('activities') }}

),

renamed as (

    select
        activity_id,
        opportunity_id,
        nullif(activity_type, '') as activity_type,
        cast(activity_date as date) as activity_date
    from src

),

deduped as (

    -- raw seed contains duplicated activity_id rows; keep the earliest record
    select *
    from renamed
    qualify row_number() over (
        partition by activity_id
        order by activity_date
    ) = 1

)

select * from deduped
