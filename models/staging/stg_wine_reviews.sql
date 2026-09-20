with kaynak as (

    select * from {{ source('wine_raw', 'wine_reviews_raw') }}

),

temizlenmis as (

    select
        -- benzersiz kimlik
        row_number() over (order by title, winery, points) as review_id,

        -- coğrafya
        trim(country) as country,
        trim(province) as province,
        coalesce(nullif(trim(region_1), ''), 'Bilinmiyor') as region,

        -- şarap bilgisi
        trim(title) as title,
        trim(variety) as variety,
        trim(winery) as winery,
        coalesce(nullif(trim(designation), ''), 'Bilinmiyor') as designation,

        -- başlıktan üretim yılı
        safe_cast(
            regexp_extract(title, r'\b(19[5-9][0-9]|20[0-2][0-9])\b') as int64
        ) as vintage,

        -- değerlendirme
        points,
        price,
        trim(description) as description,
        coalesce(nullif(trim(taster_name), ''), 'Anonim') as taster_name

    from kaynak
    where country is not null
      and variety is not null

)

select * from temizlenmis