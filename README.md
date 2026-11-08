# Bereket (Android)

Çiftçi ailesi için tarla, işletme ve ev bütçesi uygulaması.

Tarla ve işletme takibi: parseller, münavebe, ekim/hasat, dekar başı maliyet,
satışlar, depo, borsa/TMO fiyatları, borç-alacak, aile hesapları, pancar
kotaları, ek gelirler, ev bütçesi ve yıllık kârlılık.

## Ekranlar

| Ekran | Ne yapar |
|---|---|
| **Ana sayfa** | Üstte bu yıl kâr / alacak / borç / depo; işletme kartı, hasat ilerlemesi, görevler; İşletmelerim kareleri; büyük kartlar. |
| **Tarlalarım** | Parsel bilgisi (ada/parsel, dekar), ÇKS kimin üzerine, arazi durumu (kendi, kiralık, hazine kiralık, hazine ecrimisil, ortak), kim ekiyor (Ben/Babam/Kardeşim/Başkası, ortaklık payları), son 5 yılın ürünleri, münavebe kontrolü, **Ne Ekeyim?**, toplu "kim ekiyor" işaretleme. |
| **Üretim Merkezi** | Ekimler, ürünler, giderler. Faturalar ve işçilik seçilen tarlalara dekara göre bölünür; elektrik sayaca bağlanırsa sayacın suladığı ekili tarlalara bölünür. Dekar başı kullanım (kg, lt, kWh) ve dekar başı maliyet. |
| **Satışlarım** | Alıcıya göre satışlar, kesintiler (stopaj, borsa tescil, SGK), nakliye, ödemeler (avans, ürün bedeli, banka). Keleş Satış'tan aktarma. |
| **Depo** | Hasat − satış = kalan; en iyi fiyatla değeri. |
| **Piyasa** | 5 borsa + TMO + fabrika fiyatları (şimdilik elle), "Nereye satsam elime ne geçer?" (kesinti + nakliye). |
| **Borçlarım / Alacaklarım** | Kişi, bayi, banka, kooperatif, kredi kartı, kredi; altın (gram) borcu; vade ve taksit. Ödenmemiş gider/işçilik otomatik borca yazılır. |
| **Pancar & Kooperatif** | Kotalar (kimin adına, kiralık mı, kullanan), teslimat ve ödemeler, kooperatif hesapları, gelecek yıl kota tahmini, Türkşeker sayfası. |
| **Aile Hesapları** | Her kişi için malzeme, masraf, satış, destek, kâr ve **hesaplaşma**. |
| **Ek İşler** | İş yeri ve maaş günü, gelirler, diğer satışlar (saman, balya...), devlet destekleri. |
| **Ev Bütçem** (alt sekme) | Aylık ev ve araba harcamaları, kategoriler, sabit giderler, bankalara göre; **Ekstre Yükle** (Excel/CSV: Ziraat, Yapı Kredi, Kuveyt Türk, ING, Vakıfbank, Garanti) ile satır satır Ev / Tarla / Atla. |
| **Gelir - Gider** | Satış, maaş, destek, diğer gelirler, tarla/ev/araba giderleri ve borç ödemeleri tek listede, aylık ya da yıllık. |
| **Ev Alma Hedefi** | Ev fiyatı, biriktirilecek oran, hedef tarih → bu ay yatırılması gereken tutar ve son 3 ayın fazlasına göre gidişat. |
| **Malzemelerim** | Traktör, yağmurlama, ana boru, damlama, pompa, römork, şahsi araba; değer, sahip, konum, muayene; araba masraf özeti. |
| **Varlıklarım** | Net durum (birikim + ekipman + alacak − borç), aylık nakit özeti, birikimler. |
| **Ar-Ge** | Dekar başı mazot/elektrik/gübre/tohum yıllara göre, verim, girdi fiyat değişimleri. |
| **Raporlar** | Yıllık kârlılık (kişiye göre), gelir dağılımı, yıllara göre kâr grafiği, ürün bazında dekar kârı. |
| **Finans** | Borç uyarısı, yaklaşan taksitler, krediler, sat mı beklet mi hesabı. |
| **Profil** | Ayarlar (kesinti oranları, nakliye, altın fiyatı, münavebe kuralları, hesap sahipleri), ekip ve davet kodu. |

## Hesap kuralları

- Gider tarlalara **dekarlarına göre** bölünür; tarla o yıl kimin (ya da hangi
  ortakların) ekimindeyse o kişiye yazılır. Tarlaya bağlanmayan giderler "Ben"e aittir.
- **Destekler:** mazot-gübre ve toprak analizi (alan bazlı) arazi ailenin
  kendi mülküyse arazi sahibine (ÇKS sahibi), diğerleri o yıl ekene yazılır.
- **Hesaplaşma (kişi için):** satıştan sizin aldığınız − sizin yaptığınız
  masraf ± yanlış kişinin hesabına yatan destekler.
- Kiralık / hazine tarlasının yıllık bedeli ayrıca gider girilmediyse
  maliyete eklenir (kira ya da ecrimisil kalemi).
- Kiralık pancar kotasının bedeli, kullananın o yılki pancar tarlalarına dekara göre eklenir.

## Teknik

- Flutter + Firebase (Auth + Firestore). Keleş Satış ve Eğitim Takip ile
  **aynı Firebase projesi** (`egitim-takip-5a833`); veriler `tarlam_` ile
  başlayan ayrı koleksiyonlardadır. Aynı hesapla girildiğinde Keleş Satış
  satışları okunabilir (yalnızca okuma).
- `firestore.rules` üç uygulamanın kurallarını birlikte içerir. Değiştirince
  Firebase Console → Firestore → Kurallar'a dosyanın **tamamını** yapıştırıp
  Yayınla deyin.
- `main` dalına her gönderimde GitHub Actions APK derler ve Releases'e koyar;
  kurulu uygulama yeni sürümü kendisi bulur.
- İmza anahtarı `ci/bereket.p12`; şifresi depo ayarlarında
  `BEREKET_KEYSTORE_PASSWORD` gizli değişkenindedir. Şifre kaybolursa telefondaki
  uygulama güncellenemez.

## Sonraki sürümler

- ÇKS belgesini okuma (örnek belge bekleniyor)
- Fatura fotoğrafı / e-fatura okuma
- Borsa anlık bülteninden otomatik fiyat (Firebase zamanlanmış görev, Blaze plan)
- Garanti BBVA / Vakıfbank bildirimlerinden maaş ve ödeme yakalama
- Türkşeker ve kooperatif ekstrelerini okuma
