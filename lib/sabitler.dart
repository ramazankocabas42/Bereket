/// Ürünler, gider kalemleri ve satış yerleri gibi sabit listeler.
library;

class Urun {
  const Urun(this.ad, this.simge, this.aile, this.araYil);

  final String ad;
  final String simge;

  /// Münavebe için ürün ailesi (tahıl, baklagil, yağlı tohum...).
  final String aile;

  /// Aynı ürünün aynı tarlaya tekrar ekilmesi için gereken en az yıl farkı.
  /// 1: üst üste ekilebilir, 2: bir yıl ara, 4: üç yıl ara...
  final int araYil;
}

const urunler = <Urun>[
  Urun('Buğday', '🌾', 'tahıl', 2),
  Urun('Arpa', '🌾', 'tahıl', 2),
  Urun('Yulaf', '🌾', 'tahıl', 2),
  Urun('Çavdar', '🌾', 'tahıl', 2),
  Urun('Mısır', '🌽', 'mısır', 2),
  Urun('Silajlık Mısır', '🌽', 'mısır', 2),
  Urun('Şeker Pancarı', '🟣', 'pancar', 4),
  Urun('Ayçiçeği', '🌻', 'yağlı', 4),
  Urun('Çerezlik Ayçiçeği', '🌻', 'yağlı', 4),
  Urun('Kanola', '🌼', 'yağlı', 3),
  Urun('Kabak Çekirdeği', '🎃', 'kabak', 3),
  Urun('Kuru Fasulye', '🫘', 'baklagil', 3),
  Urun('Nohut', '🫘', 'baklagil', 3),
  Urun('Mercimek', '🫘', 'baklagil', 3),
  Urun('Patates', '🥔', 'patlıcangil', 3),
  Urun('Kuru Soğan', '🧅', 'soğan', 3),
  Urun('Havuç', '🥕', 'havuç', 3),
  Urun('Domates', '🍅', 'patlıcangil', 3),
  Urun('Yonca', '☘️', 'yem', 1),
  Urun('Fiğ', '☘️', 'baklagil', 2),
];

Urun? urunBul(String ad) {
  for (final u in urunler) {
    if (u.ad == ad) return u;
  }
  return null;
}

String urunSimge(String ad) => urunBul(ad)?.simge ?? '🌱';

/// Tarla gider kalemleri ve varsayılan birimleri.
const giderKalemleri = <String, String>{
  'Tohum': 'kg',
  'Gübre': 'kg',
  'İlaç': 'lt',
  'Mazot': 'lt',
  'Elektrik': 'kWh',
  'İşçilik (Yevmiye)': 'gün',
  'Makine İşçiliği': 'dekar',
  'Sulama': 'saat',
  'Arazi Kirası': 'dekar',
  'Ecrimisil': 'dekar',
  'Nakliye': 'ton',
  'Sigorta (TARSİM)': 'adet',
  'Ziraat Odası Ücreti': 'dekar',
  'Çiftçi Koruma (Bekçi)': 'dekar',
  'Diğer': 'adet',
};

const giderSimge = <String, String>{
  'Tohum': '🌱',
  'Gübre': '🧪',
  'İlaç': '💧',
  'Mazot': '⛽',
  'Elektrik': '⚡',
  'İşçilik (Yevmiye)': '👷',
  'Makine İşçiliği': '🚜',
  'Sulama': '🚿',
  'Arazi Kirası': '📜',
  'Ecrimisil': '🏛️',
  'Nakliye': '🚚',
  'Sigorta (TARSİM)': '🛡️',
  'Ziraat Odası Ücreti': '🏢',
  'Çiftçi Koruma (Bekçi)': '👮',
  'Diğer': '📦',
};

const evKategorileri = <String>[
  'Ev Kirası',
  'Elektrik',
  'Su',
  'Doğalgaz',
  'İnternet / Telefon',
  'Market',
  'Okul',
  'Sağlık',
  'Araba (yakıt)',
  'Araba (bakım/tamir)',
  'Araba (sigorta/kasko)',
  'Araba (MTV/muayene)',
  'Araba (lastik/diğer)',
  'Giyim',
  'Diğer',
];

/// Takip edilen borsalar (sırası ekranda da böyle görünür).
const borsalar = <String>[
  'Karapınar Borsası',
  'Konya Borsası',
  'Karaman Borsası',
  'Çumra Borsası',
  'Altınekin Borsası',
];

/// Satış yerleri: borsalar + TMO + fabrika + serbest tüccar.
const satisYerleri = <String>[
  ...borsalar,
  'TMO',
  'Şeker Fabrikası',
  'Tüccar',
  'Diğer',
];

const hesapTurleri = <String>[
  'Bayi',
  'Banka',
  'Kooperatif',
  'Kişi',
  'Kredi Kartı',
  'Kredi',
  'Tüccar',
  'Diğer',
];

const hesapSimge = <String, String>{
  'Bayi': '🏪',
  'Banka': '🏦',
  'Kooperatif': '🤝',
  'Kişi': '👤',
  'Kredi Kartı': '💳',
  'Kredi': '📄',
  'Tüccar': '🚛',
  'Diğer': '📌',
};

const varlikTurleri = <String, String>{
  'Altın': 'gram',
  'Döviz': 'adet',
  'Mevduat': '₺',
  'Fon / Hisse': 'adet',
  'Diğer': 'adet',
};

const varlikSimge = <String, String>{
  'Altın': '🪙',
  'Döviz': '💵',
  'Mevduat': '🏦',
  'Fon / Hisse': '📈',
  'Diğer': '💼',
};

const ekimDurumlari = <String>['Ekildi', 'Büyüyor', 'Hasat edildi'];

const mulkiyetler = <String>[
  'Kendi',
  'Kiralık',
  'Hazine (kiralık)',
  'Hazine (ecrimisil)',
  'Ortak',
];

/// Arazi durumuna göre yıllık bedelin gider kalemi.
String kiraKalemi(String mulkiyet) =>
    mulkiyet.contains('ecrimisil') ? 'Ecrimisil' : 'Arazi Kirası';

/// Tarlayı aileden biri değil, başka biri ekiyorsa "Kim ekiyor" değeri.
const baskasi = 'Başkası';

/// ÇKS ailede kimsenin üzerine değilse.
const cksBizdeDegil = 'ÇKS bizde değil';

/// Başkasına yaptırılan makine işleri.
const makineIsleri = <String>[
  'Sürüm',
  'Diskaro',
  'Tırmık / Merdane',
  'Ekim',
  'Gübre atma',
  'İlaçlama',
  'Çapa',
  'Biçerdöver hasat',
  'Pancar söküm',
  'Balya',
  'Nakliye',
  'Diğer',
];

const makineBirimleri = <String>['dekar', 'saat', 'sefer', 'ton'];

const gelirTurleri = <String>['Maaş', 'Prim / İkramiye', 'Destek', 'Kira Geliri', 'Diğer'];

const destekTurleri = <String>[
  'Mazot-Gübre Desteği',
  'Fark Ödemesi (Ürün Desteği)',
  'Sertifikalı Tohum Desteği',
  'Toprak Analizi Desteği',
  'Hayvancılık Desteği',
  'Diğer Destek',
];

const tahsilatTurleri = <String>['Avans', 'Ürün bedeli', 'Peşin', 'Kısmi ödeme', 'Diğer'];

const bankalar = <String>[
  'Ziraat Bankası',
  'Yapı Kredi',
  'Kuveyt Türk',
  'ING',
  'Vakıfbank',
  'Garanti BBVA',
  'Nakit',
  'Diğer',
];

/// Arazi sahibine yazılan (alan bazlı) destekler. Diğerleri ekene yazılır.
const alanBazliDestekler = <String>{'Mazot-Gübre Desteği', 'Toprak Analizi Desteği'};

const ekipmanTurleri = <String, String>{
  'Traktör': '🚜',
  'Sulama': '💦',
  'Makine / Ekipman': '⚙️',
  'Römork / Taşıma': '🛻',
  'Şahsi Araç': '🚗',
  'Depo / Bina': '🏚️',
  'Diğer': '🧰',
};

const ekipmanOnerileri = <String>[
  'Traktör',
  'Yağmurlama takımı',
  'Ana boru',
  'Damlama hattı',
  'Dalgıç pompa',
  'Römork',
  'Pulluk',
  'Diskaro',
  'Mibzer',
  'İlaçlama makinesi',
  'Gübre serpme',
  'Şahsi araba',
];

bool arabaKategorisi(String k) => k.startsWith('Araba');
