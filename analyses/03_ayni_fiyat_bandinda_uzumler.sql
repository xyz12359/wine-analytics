select
    v.variety,
    count(*) as sarap_sayisi,
    round(avg(f.points), 2) as ort_puan
from {{ ref('fct_wine_review') }} f
join {{ ref('dim_variety') }} v
    on f.variety_id = v.variety_id
where f.price between 15 and 25
group by v.variety
having count(*) >= 300
order by ort_puan desc