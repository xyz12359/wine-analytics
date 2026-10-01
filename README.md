# Wine Reviews — Uçtan Uca Veri Analizi Projesi

129.907 şarap değerlendirmesi üzerinden kurulmuş bir veri hattı: ham CSV'den
başlayıp veri ambarı, katmanlı modelleme, analiz, istatistiksel test, makine
öğrenmesi ve dashboard'a kadar gidiyor.

**Dashboard:** [Looker Studio'da aç](https://datastudio.google.com/reporting/22436018-d704-4ae4-b783-fea7b80bdfca)

---

## Projenin amacı

Şarap fiyatları 4 dolardan 3.300 dolara kadar uzanıyor. Bu farkın karşılığı
kalitede ne kadar görünüyor? Proje bu soruyla başladı ve veriyi keşfederken
dört somut soruya dönüştü:

1. Pahalı şarap gerçekten daha iyi mi?
2. Aynı bütçeyle en iyi şarap nerede?
3. Pahalı şaraplar yıllanmış şaraplar mı?
4. Tadımcının yazdığı metinden puan tahmin edilebilir mi?

## Veri seti

| | |
|---|---|
| Kaynak | [Kaggle — Wine Reviews](https://www.kaggle.com/datasets/zynicide/wine-reviews) (WineEnthusiast, Haziran 2017) |
| Dosya | `winemag-data-130k-v2.csv` · 53 MB · 14 kolon |
| Ham satır | 129.971 |
| Temizlik sonrası | 129.907 |
| Kapsam | 43 ülke · 425 il/bölge · 701 üzüm çeşidi · 16.757 üretici |
| Puan aralığı | 80–100 (dergi 80 altını yayınlamıyor) |

Her kayıtta ülke, bölge, üzüm çeşidi, üretici, fiyat, 100 üzerinden puan ve
tadımcının serbest yazdığı değerlendirme metni bulunuyor.

---

## Mimari

```
Kaggle CSV
    │
    ▼
Python / Colab          keşifsel analiz (EDA) + BigQuery'ye yükleme
    │
    ▼
BigQuery  wine_raw      ham katman — hiç değiştirilmiyor
    │
    ▼
dbt       staging       temizlik (view)
    │
    ▼
dbt       marts         yıldız şeması + raporlama tablosu (table)
    │
    ├──────────────► Looker Studio   dashboard
    └──────────────► scikit-learn    puan tahmin modeli
```

### Neden ELT, neden ETL değil

Temizlik Python tarafında yapılıp veri öyle yüklenebilirdi. Bunun yerine ham
veri olduğu gibi ambara alındı, dönüşüm ambarın içinde SQL ile yapıldı.

Böylece ham veri hiç bozulmuyor. Bir temizlik kararı değiştiğinde kaynağa
dönmek gerekmiyor, modeli yeniden çalıştırmak yetiyor. Kararlar da bir script'in
içine gömülü değil, versiyonlanmış SQL dosyalarında duruyor ve commit
geçmişinden takip edilebiliyor.

---

## Veri modeli

```
wine_reviews_raw  (kaynak)
        │
        ▼
stg_wine_reviews  (view)      kırpma, yıl çıkarma, eksik anahtar temizliği
        │
        ├──────────────┬──────────────┐
        ▼              ▼              ▼
   dim_country   fct_wine_review   dim_variety
     425 satır     129.907 satır      701 satır
        └──────────────┴──────────────┘
                       │
                       ▼
            rpt_wine_dashboard  (table)
            raporlamaya hazır tek tablo
```

**Neden parçalandı.** Ham tabloda `France` kelimesi 22.093 kez yazılı duruyor.
Boyut tablosunda bir kez geçiyor, olgu tablosu ona kimlikle bağlanıyor. Kimball
yıldız şemasının temel fikri bu.

**Neden sonra birleştirildi.** `rpt_wine_dashboard`, raporlamaya hazır tek bir
tablo. Looker Studio'da birleştirme kurmaya gerek kalmıyor; fiyat ve puan
bantları ile grup büyüklüğü kolonları hazır geliyor.

**Materyalizasyon.** Staging bir view — sorgulandığı anda hesaplanıyor, sonucu
diske yazılmıyor. Marts tablo — dashboard ve analiz sorguları oraya defalarca
bağlandığı için sonuç bir kez hesaplanıp saklanıyor.

### Veri kalitesi testleri

| Test | Nerede |
|---|---|
| `unique` | tüm boyut ve olgu tablolarının kimlik kolonları |
| `not_null` | puan, ülke, üzüm çeşidi ve tüm kimlik kolonları |
| `relationships` | `fct_wine_review` → `dim_country`, `dim_variety` |

Testler YAML'da tanımlı; dbt bunları arka planda "kuralı bozan satırları getir"
sorgusuna çeviriyor. Sorgu satır dönerse çalıştırma hata vererek duruyor, yani
bozuk veri dashboard'a ve modele ulaşmadan yakalanıyor. Tümü geçiyor.

---

## Bulgular

### 1. Pahalı şarap daha iyi — ama fiyat farkı kadar değil

| Fiyat bandı | Şarap sayısı | Ortalama puan |
|---|---|---|
| 0–15 $ | 25.102 | 85,91 |
| 15–25 $ | 36.174 | 87,64 |
| 25–50 $ | 39.925 | 89,26 |
| 50–100 $ | 16.408 | 91,05 |
| 100 $ + | 3.366 | 92,82 |

En ucuz bandın ortalama fiyatı 12 $, en pahalınınki 185 $. Yani **15 kat fiyat
farkına karşılık 6,9 puan** kazanç.

İlişkiyi iki ayrı yoldan ölçtüm:

- **Gruplama** (yukarıdaki tablo)
- **Korelasyon** (gruplamadan bağımsız, tüm satırlar üzerinden): **0,416**

İkisi de aynı şeyi söyledi: ilişki var ama zayıf. Farklı yöntemlerin aynı
cevaba varması bulguyu sağlamlaştırıyor.

**Log dönüşümü.** İlişki doğrusal değil — fiyat yükseldikçe aynı tutarlı artışın
kalitedeki karşılığı azalıyor. Fiyat mutlak tutar yerine kat ölçeğine
çevrildiğinde korelasyon **0,612**'ye çıktı, yani açıklama gücü %17'den
**%37**'ye yükseldi. Fiyat her iki katına çıktığında puan ortalama **2,0**
artıyor; bu sayı sabit, yani azalan getiri.

### 2. Aynı paraya en iyi şarap nerede?

Burada fiyat 15–25 $ bandına sabitlendi. Farklı fiyatlardaki şarapları
karşılaştırmak yanıltıcı olurdu — pahalı olan zaten yüksek puan alır. Fiyat
sabitlenince geriye kalite farkı kalıyor.

**Ülkeler** (en az 200 kayıt)

| # | Ülke | Ort. puan |
|---|---|---|
| 1 | Avusturya | 89,41 |
| 2 | Almanya | 89,00 |
| 3 | Portekiz | 88,79 |
| — | Fransa | 87,90 |
| — | ABD | 87,37 |

**Üzüm çeşitleri** (en az 300 kayıt)

| # | Çeşit | Ort. puan |
|---|---|---|
| 1 | Grüner Veltliner | 89,39 |
| 2 | Portuguese Red | 89,13 |
| 3 | Riesling | 88,57 |
| — | Pinot Noir | 86,84 |
| — | Merlot | 86,60 |

Alt sıralardaki üzümler dünyanın en tanınmışları. Talep yüksek olduğu için bu
bütçeye iyi örneklerini bulmak zor.

**Bölge kırılımı** (tüm veri, fiyatlar ortanca)

| Bölge | Ort. puan | Ortanca fiyat |
|---|---|---|
| Kamptal (Avusturya) | 91,40 | 29 $ |
| Mosel (Almanya) | 90,04 | 26 $ |
| Burgundy (Fransa) | 89,64 | 43 $ |
| Douro (Portekiz) | 89,14 | 20 $ |

Burgundy'nin puanını Mosel 17 dolar, Douro 23 dolar daha ucuza veriyor.

### 3. Pahalı şarap "yıllanmış şarap" demek değil

| Fiyat bandı | Ortalama yaş | Ortanca üretim yılı |
|---|---|---|
| 0–15 $ | 6,0 yıl | 2012 |
| 15–25 $ | 5,9 yıl | 2012 |
| 25–50 $ | 6,4 yıl | 2011 |
| 50–100 $ | 6,8 yıl | 2011 |
| 100 $ + | 7,9 yıl | 2010 |

Yaş fiyatla birlikte artıyor, ama ortalama fiyat 15 kat artarken yaş yalnızca
1,9 yıl artıyor. İlk iki bant neredeyse aynı. 100 doların üstündeki şarapların
bile ortanca üretim yılı 2010.

*Sınırlama:* veride değerlendirme tarihi yok, yalnızca üretim yılı var. Yaş 2017
baz alınarak hesaplandı; mutlak rakamlar yaklaşık, ama hata tüm bantlarda aynı
olduğu için bantlar arası karşılaştırma geçerli. Adında yıl geçmeyen 4.633
şarap (non-vintage) bu analizin dışında.

---

## Hipotez testleri

Ortalamalar arasındaki farkların tesadüf olup olmadığı Welch t-testi ile
sınandı (`scipy.stats`, %95 anlamlılık düzeyi).

**Test 1 — Avusturya ve Arjantin**

| | Ortalama | n |
|---|---|---|
| Avusturya | 90,10 | 3.345 |
| Arjantin | 86,71 | 3.800 |

p ≈ 0. Fark hem gerçek, hem de büyüklüğü anlamlı: **3,4 puan**.

**Test 2 — Alsace ve Burgundy**

| | Ortalama | Ortanca fiyat | n |
|---|---|---|---|
| Alsace | 89,37 | 25 $ | 2.440 |
| Burgundy | 89,57 | 43 $ | 3.980 |

p = 0,011. Fark istatistiksel olarak gerçek — ama yalnızca **0,2 puan**, buna
karşılık ortanca fiyat farkı **%72**.

**Çıkarılacak ders.** p-değeri bir farkın *gerçek* olup olmadığını gösterir,
*önemli* olup olmadığını göstermez. Örneklem büyüdükçe küçük farklar da anlamlı
çıkar: 6.420 kayıtla yapılan bu testte 0,2 puanlık fark bile anlamlı sonuç
verdi. 80–100 ölçeğinde 0,2 puanın pratik karşılığı yok.

---

## Makine öğrenmesi

Veride tadımcının yazdığı serbest metin var. Bu metin yalnızca okunacak bir not
mu, yoksa içinde ölçülebilir bir bilgi mi taşıyor? Sorunun cevabı için metinden
puan tahmin eden bir model kuruldu.

| | |
|---|---|
| Girdi | `fct_wine_review.description` (ham CSV değil, test edilmiş dbt çıktısı) |
| Vektörleştirme | TF-IDF · 5.000 özellik · 1–2 gram · `min_df=5` · İngilizce stop words |
| Model | Ridge regresyon (`alpha=1.0`) |
| Bölme | %80 / %20 · 103.925 eğitim / 25.982 test · `random_state=42` |

| Ölçüm | Ortalama mutlak hata |
|---|---|
| Kıyas noktası (herkese ortalama puanı ver) | 2,48 puan |
| Model | **1,34 puan** |

Kıyas noktası önce kuruldu. Onsuz "1,34 hata"nın iyi mi kötü mü olduğu
anlaşılamazdı. Model hatayı yaklaşık yarıya indiriyor.

### Model neyi öğrendi?

| Puanı yükseltenler | | Puanı düşürenler | |
|---|---|---|---|
| superb | +7,83 | lacks | −4,98 |
| 2030 | +7,76 | watery | −4,60 |
| gorgeous | +7,65 | strange | −4,15 |
| beautiful | +7,24 | odd | −3,67 |
| stunning | +7,13 | golden delicious | −3,42 |
| decades | +6,83 | simple | −3,18 |

İki gözlem:

- **İyi şarap eski değil, yıllanabilen şarap.** `decades`, `2030`, `2026` gibi
  ifadeler tadımcının yıllanma potansiyelinden bahsettiği notlar — ve 3. bulgu
  ile tutarlı.
- **`delicious` puanı yükseltiyor, `golden delicious` düşürüyor.** Golden
  Delicious bir elma türü. Yalnızca tek kelimelere bakılsaydı bu ayrım
  yakalanamazdı; iki kelimelik ifadeler bunun için var.

**Önemli uyarı.** Bu model şarabı tatmıyor, tadımcının dilini okuyor. Tadımcı
önce tadıyor, puanı veriyor, sonra notu yazıyor — yani not zaten puanın
yansıması. "Model şarap kalitesini tahmin ediyor" demek yanlış olur.

---

## Karşılaşılan sorunlar

| Sorun | Çözüm |
|---|---|
| En eski şarap 1904 çıktı. Yılı addan çeken kalıp ilk dört haneli sayıyı alıyordu; `1912 Winemakers` gibi üretici adlarını yıl sanıyordu. | Kalıp 1950–2029 aralığı ile sınırlandı. |
| Fiyatı bilinmeyen 8.992 şarap `100$+` bandına düşüyordu. Bant tanımında boş değer için kural yoktu. | Ayrı bir "fiyat bilinmiyor" bandı açıldı. |
| Lider tablolarının başında Hindistan ve Fas çıkıyordu — veride birkaç kaydı olan ülkeler, tek bir yüksek puanlı şarap yüzünden zirveye oturuyordu. | Asgari örneklem filtresi eklendi (`having count(*) >= N`). |
| Model `93` ve `94` kelimelerine yüksek ağırlık verdi — notların içinde puan yazıyor olabilirdi, bu modelin kopya çekmesi demekti. | Kontrol edildi: harman oranıymış (%93 Merlot). 129.907 notun yalnızca 9'unda açık puan ifadesi geçiyor, sızıntı yok. |

---

## Sınırlamalar

- **Seçilmiş örneklem.** Dergi yalnızca 80 ve üzeri puan alan şarapları
  yayınlıyor. "Kötü şarap nasıl olur" sorusu bu veriyle cevaplanamaz.
- **Coğrafi yanlılık.** ABD tek başına verinin %42'si. Dergi Amerikan olduğu
  için ülke karşılaştırmaları bu gözle okunmalı.
- **Tek yıl, tek dergi.** Veri 2017'de toplandı; zaman içindeki değişim
  izlenemiyor.
- **Tekrar eden kayıtlar.** Ham veride 9.979 satır tamamen aynı (aynı şarap,
  aynı metin, aynı puan). Bu projede ayıklanmadı; staging katmanına bir dedup
  adımı eklemek sonraki adımlardan biri.

## Sonraki adımlar

- **Otomasyon (Zapier).** Bu projede Zapier kullanılmadı. Kurulabilecek senaryo
  şuydu: GitHub deposuna yeni bir commit geldiğinde ya da dbt çalıştırması
  bittiğinde otomatik e-posta/bildirim göndermek. Kaynak tek seferlik statik bir
  dosya olduğu için tetiklenecek gerçek bir olay yoktu; zorlama bir kurgu
  yapmak yerine yapılmadı. Gerçek bir hatta ilk eklenecek şey bu olurdu.
- **Modeli güçlendirmek.** Kelime köklerini birleştirmek, fiyatı da girdi olarak
  eklemek, hiperparametreleri ayrı bir doğrulama setiyle ayarlamak.
- **Boyutları zenginleştirmek.** Üzüm çeşidine renk ve gövde bilgisi eklemek.

---

## Kullanılan teknolojiler

| Katman | Araç |
|---|---|
| Keşif ve yükleme | Python · pandas · Google Colab |
| Veri ambarı | BigQuery |
| Dönüşüm | dbt |
| Görselleştirme | Looker Studio |
| Makine öğrenmesi | scikit-learn · scipy |
| Versiyon kontrolü | Git · GitHub |
| Yapay zekâ desteği | Claude (Anthropic) |

## Depo yapısı

```
├── models/
│   ├── staging/
│   │   ├── sources.yml
│   │   └── stg_wine_reviews.sql
│   └── marts/
│       ├── dim_country.sql
│       ├── dim_variety.sql
│       ├── fct_wine_review.sql
│       ├── rpt_wine_dashboard.sql
│       └── schema.yml              testler burada
├── analyses/
│   ├── 01_fiyat_ve_yas.sql
│   ├── 02_ayni_fiyat_bandinda_ulkeler.sql
│   ├── 03_ayni_fiyat_bandinda_uzumler.sql
│   └── 04_bolge_analizi.sql
├── notebooks/
│   ├── 01_eda_ve_yukleme.ipynb     EDA + BigQuery'ye yükleme
│   └── 02_model.ipynb              hipotez testleri + ML
└── dbt_project.yml
```

## Çalıştırmak için

```bash
dbt deps
dbt build      # modelleri kurar ve testleri çalıştırır
dbt compile    # analyses/ altındaki sorguları derler
```

Derlenmiş analiz sorguları `target/compiled/wine_analytics/analyses/` altına
çıkar ve BigQuery konsolunda çalıştırılabilir.

Notebook'lar Google Colab'da çalışacak şekilde yazıldı; BigQuery erişimi için
`google.colab.auth` kullanılıyor.

---

## Kapsam dışı bırakılan araç

**Google Sheets.** Veri 130 bin satır; e-tablo bu boyut için doğru araç değil.
Ara çıktıları Sheets'e taşımak hattı kırar ve tek doğruluk kaynağı ilkesini
bozardı.
