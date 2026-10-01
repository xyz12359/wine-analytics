select
    c.country,
    count(*) as sarap_sayisi,
    round(avg(f.points), 2) as ort_puan,
    approx_quantiles(f.price, 2)[offset(1)] as ortanca_fiyat,
    round(
        (avg(f.points) - 80) / approx_quantiles(f.price, 2)[offset(1)],
        3
    ) as dolar_basina_ek_puan
from {{ ref('fct_wine_review') }} f
join {{ ref('dim_country') }} c
    on f.country_id = c.country_id
where f.price is not null
group by c.country
having count(*) >= 500
order by dolar_basina_ek_puan desc