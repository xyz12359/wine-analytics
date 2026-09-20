with kaynak as (

    select distinct
        country,
        province
    from {{ ref('stg_wine_reviews') }}

)

select
    row_number() over (order by country, province) as country_id,
    country,
    province
from kaynak