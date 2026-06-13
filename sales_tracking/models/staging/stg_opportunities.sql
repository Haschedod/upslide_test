with src as (

    select * from {{ ref('opportunities') }}

),

renamed as (

    select
        opportunity_id,
        account_id,
        salesperson_id,

        -- raw CSV mixes ISO, ISO timestamp, YYYY/MM/DD and DD/MM/YYYY formats
        {{ clean_date('created_date') }} as created_date,
        {{ clean_date('closed_date') }} as closed_date,

        cast(arr as integer) as arr,
        status,
        nullif(source, '') as lead_source,
        type as opportunity_type
    from src

)

select * from renamed
