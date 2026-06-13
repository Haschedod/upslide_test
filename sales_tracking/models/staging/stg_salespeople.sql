with src as (

    select * from {{ ref('salespeople') }}

),

renamed as (

    select
        salesperson_id,
        name as salesperson_name,
        salesperson_office
    from src

)

select * from renamed
