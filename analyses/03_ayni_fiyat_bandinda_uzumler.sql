select
    case
        when price <= 15 then '1. 0-15$'
        when price <= 25 then '2. 15-25$'
        when price <= 50 then '3. 25-50$'
        when price <= 100 then '4. 50-100$'
        else '5. 100$+'
    end as fiyat_bandi,
    count(*) as sarap_sayisi,
    round(avg(2017 - vintage), 1) as ort_yas,
    approx_quantiles(vintage, 2)[offset(1)] as ortanca_yil,
    round(avg(points), 2) as ort_puan
from {{ ref('fct_wine_review') }}
where price is not null
  and vintage is not null
group by 1
order by 1