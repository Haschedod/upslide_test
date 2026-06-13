with salespeople as (

    select * from {{ ref('stg_salespeople') }}

)

select
    salesperson_id,
    salesperson_name,
    salesperson_office
from salespeople
