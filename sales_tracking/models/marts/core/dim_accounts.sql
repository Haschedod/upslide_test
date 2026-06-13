with accounts as (

    select * from {{ ref('stg_accounts') }}

)

select
    account_id,
    account_name,
    account_office
from accounts
