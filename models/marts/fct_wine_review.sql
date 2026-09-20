with stg as (

    select * from {{ ref('stg_wine_reviews') }}

),

ulke as (

    select * from {{ ref('dim_country') }}

),

uzum as (

    select * from {{ ref('dim_variety') }}

)

select
    stg.review_id,

    -- boyut bağlantıları
    ulke.country_id,
    uzum.variety_id,

    -- boyuta ayırmadığımız nitelikler
    stg.winery,
    stg.designation,
    stg.taster_name,
    stg.title,
    stg.vintage,

    -- ölçümler
    stg.points,
    stg.price,
    case
        when stg.price is not null then round(stg.price / stg.points, 2)
    end as price_per_point,

    -- metin (ML aşamasında kullanacağız)
    stg.description

from stg
left join ulke
    on stg.country = ulke.country
    and stg.province = ulke.province
left join uzum
    on stg.variety = uzum.variety