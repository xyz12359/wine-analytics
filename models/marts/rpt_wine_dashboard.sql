with birlesik as (

    select
        f.review_id,
        c.country,
        c.province,
        v.variety,
        f.winery,
        f.taster_name,
        f.title,
        f.vintage,
        f.points,
        f.price,

        case
            when f.price is null then '0. Fiyat bilinmiyor'
            when f.price <= 15  then '1. 0-15$'
            when f.price <= 25  then '2. 15-25$'
            when f.price <= 50  then '3. 25-50$'
            when f.price <= 100 then '4. 50-100$'
            else '5. 100$+'
        end as fiyat_bandi,

        case
            when f.points >= 94 then '4. 94-100 (Üstün)'
            when f.points >= 90 then '3. 90-93 (Mükemmel)'
            when f.points >= 87 then '2. 87-89 (Çok iyi)'
            else '1. 80-86 (İyi)'
        end as puan_bandi

    from {{ ref('fct_wine_review') }} f
    join {{ ref('dim_country') }} c on f.country_id = c.country_id
    join {{ ref('dim_variety') }} v on f.variety_id = v.variety_id

)

select
    *,
    count(*) over (partition by country,  fiyat_bandi) as ulke_bant_sayisi,
    count(*) over (partition by variety,  fiyat_bandi) as cesit_bant_sayisi,
    count(*) over (partition by province, fiyat_bandi) as bolge_bant_sayisi
from birlesik