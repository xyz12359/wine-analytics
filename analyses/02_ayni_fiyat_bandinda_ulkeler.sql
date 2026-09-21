# sorumuz: aynı fiyata hangi ülke daha iyi şarap veriyor?
#Sadece 15-25 dolar arası şarapları alıp ülkelerin ortalama puanını karşılaştırırız. Fiyat sabitlendiği için doğrudan kalite kıyaslanır
select
    c.country,
    count(*) as sarap_sayisi,
    round(avg(f.points), 2) as ort_puan
from {{ ref('fct_wine_review') }} f
join {{ ref('dim_country') }} c
    on f.country_id = c.country_id
where f.price between 15 and 25
group by c.country
having count(*) >= 200
order by ort_puan desc