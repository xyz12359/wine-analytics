# sorumuz: aynı fiyata hangi ülke daha iyi şarap veriyor?
#Sadece 15-25 dolar arası şarapları alıp ülkelerin ortalama puanını karşılaştırırız. Fiyat sabitlendiği için doğrudan kalite kıyaslanır
select
    country,
    count(*) as sarap_sayisi,
    round(avg(points), 2) as ort_puan
from {{ ref('rpt_wine_dashboard') }}
where fiyat_bandi = '2. 15-25$'
group by country
having count(*) >= 200
order by ort_puan desc


