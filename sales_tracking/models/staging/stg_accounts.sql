with src as (

    select * from {{ ref('accounts') }}

),

renamed as (

    select
        account_id,
        account_name,
        account_office
    from src

)

select * from renamed
