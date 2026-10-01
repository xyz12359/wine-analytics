with kaynak as (

    select distinct variety
    from {{ ref('stg_wine_reviews') }}

)

select
    row_number() over (order by variety) as variety_id,
    variety
from kaynak