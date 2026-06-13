with src as (

    select * from {{ ref('targets') }}

),

renamed as (

    select
        salesperson_id,
        account_office,
        target_quarter,
        cast(quarter_target as integer) as quarter_target
    from src

)

select * from renamed
