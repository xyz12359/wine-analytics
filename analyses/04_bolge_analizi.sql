select
    c.country,
    c.province,
    count(*) as sarap_sayisi,
    round(avg(f.points), 2) as ort_puan,
    approx_quantiles(f.price, 2)[offset(1)] as ortanca_fiyat
from {{ ref('fct_wine_review') }} f
join {{ ref('dim_country') }} c
    on f.country_id = c.country_id
where f.price is not null
group by c.country, c.province
having count(*) >= 300
order by ort_puan desc