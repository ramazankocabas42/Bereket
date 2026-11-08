/// Banka hesap hareketi / kredi kartı ekstresi okuma (Excel ya da CSV'den
/// gelen satırlar). Bankaya özel biçimler yerine başlık satırındaki sütun
/// adlarına bakarak tarih, açıklama ve tutarı bulur. Saf Dart.
library;

import 'bicim.dart';

class EkstreSatir {
  EkstreSatir({
    required this.tarih,
    required this.aciklama,
    required this.tutar,
    required this.harcama,
  });

  final int tarih; // ms
  final String aciklama;
  final double tutar; // her zaman pozitif
  final bool harcama; // false: gelen para

  String get anahtar =>
      '$tarih|${tutar.toStringAsFixed(2)}|${araMetni(aciklama).replaceAll(RegExp(r'\s+'), ' ')}';
}

/// Basit CSV okuyucu: ; , ya da sekme ile ayrılmış, tırnaklı alanlar.
List<List<String>> csvOku(String metin) {
  final satirlar = metin.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  final ornek = satirlar.take(30).join('\n');
  final adaylar = {';': ';'.allMatches(ornek).length, '\t': '\t'.allMatches(ornek).length,
    ',': ','.allMatches(ornek).length};
  // Virgül ondalık ayırıcı da olabildiği için önce ; ve sekme tercih edilir.
  var ayrac = ';';
  if (adaylar[';']! == 0) ayrac = adaylar['\t']! > 0 ? '\t' : ',';
  final out = <List<String>>[];
  for (final s in satirlar) {
    if (s.trim().isEmpty) continue;
    final hucreler = <String>[];
    final b = StringBuffer();
    var tirnak = false;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '"') {
        if (tirnak && i + 1 < s.length && s[i + 1] == '"') {
          b.write('"');
          i++;
        } else {
          tirnak = !tirnak;
        }
      } else if (c == ayrac && !tirnak) {
        hucreler.add(b.toString().trim());
        b.clear();
      } else {
        b.write(c);
      }
    }
    hucreler.add(b.toString().trim());
    out.add(hucreler);
  }
  return out;
}

/// "05.11.2026", "05/11/2026 14:32", "2026-11-05", "2026-11-05T00:00:00"
int? tarihOku(String s) {
  final t = s.trim();
  var m = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{4})').firstMatch(t);
  if (m != null) {
    return DateTime(int.parse(m.group(3)!), int.parse(m.group(2)!), int.parse(m.group(1)!), 12)
        .millisecondsSinceEpoch;
  }
  m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(t);
  if (m != null) {
    return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!), 12)
        .millisecondsSinceEpoch;
  }
  return null;
}

/// Tutar: "1.234,56", "-1.234,56 TL", "1,234.56", "1234.5", "(150,00)"
double? tutarOku(String s) {
  var t = s.replaceAll(RegExp(r'(TL|TRY|₺|\s)', caseSensitive: false), '');
  if (t.isEmpty) return null;
  var eksi = false;
  if (t.startsWith('(') && t.endsWith(')')) {
    eksi = true;
    t = t.substring(1, t.length - 1);
  }
  if (t.endsWith('-')) {
    eksi = true;
    t = t.substring(0, t.length - 1);
  }
  if (t.startsWith('+')) t = t.substring(1);
  // "1,234.56" (İngilizce biçim) → virgül binlik
  if (RegExp(r'^-?\d{1,3}(,\d{3})+(\.\d+)?$').hasMatch(t)) t = t.replaceAll(',', '');
  final v = sayiOku(t);
  if (v == null) return null;
  return eksi ? -v.abs() : v;
}

int _sutun(List<String> baslik, List<String> anahtarlar, {List<String> haric = const []}) {
  for (var i = 0; i < baslik.length; i++) {
    final h = araMetni(baslik[i]);
    if (haric.any(h.contains)) continue;
    if (anahtarlar.any(h.contains)) return i;
  }
  return -1;
}

/// Satırlardan harcama ve gelen paraları çıkarır.
List<EkstreSatir> ekstreCoz(List<List<String>> satirlar) {
  // Başlık satırı: hem tarih hem tutar/borç sütunu olan ilk satır.
  var bi = -1;
  for (var i = 0; i < satirlar.length && i < 60; i++) {
    final h = satirlar[i].map(araMetni).toList();
    final tarihVar = h.any((x) => x.contains('tarih'));
    final tutarVar = h.any((x) =>
        x.contains('tutar') || x.contains('borc') || x.contains('alacak') || x.contains('miktar'));
    if (tarihVar && tutarVar) {
      bi = i;
      break;
    }
  }
  if (bi < 0) return const [];
  final b = satirlar[bi];
  final cTarih = _sutun(b, ['islem tarihi', 'tarih'], haric: ['valor']);
  final cAciklama = _sutun(b, ['aciklama', 'islem detay', 'isyeri', 'islem', 'detay'],
      haric: ['tarih', 'tutar', 'no']);
  final cBorc = _sutun(b, ['borc', 'cikan', 'giden']);
  final cAlacak = _sutun(b, ['alacak', 'giren', 'gelen']);
  final cTutar = _sutun(b, ['islem tutari', 'tutar', 'miktar'],
      haric: ['bakiye', 'taksit sayisi', 'puan', 'doviz']);
  if (cTarih < 0 || (cTutar < 0 && cBorc < 0)) return const [];

  String hucre(List<String> r, int c) => (c >= 0 && c < r.length) ? r[c] : '';

  final ham = <(int, String, double)>[];
  for (final r in satirlar.skip(bi + 1)) {
    final t = tarihOku(hucre(r, cTarih));
    if (t == null) continue;
    final ac = hucre(r, cAciklama);
    double? tutar;
    if (cBorc >= 0 || cAlacak >= 0) {
      final borc = tutarOku(hucre(r, cBorc))?.abs() ?? 0;
      final alacak = tutarOku(hucre(r, cAlacak))?.abs() ?? 0;
      if (borc > 0) {
        tutar = -borc;
      } else if (alacak > 0) {
        tutar = alacak;
      }
    }
    tutar ??= tutarOku(hucre(r, cTutar));
    if (tutar == null || tutar == 0) continue;
    ham.add((t, ac, tutar));
  }
  // Hesap hareketlerinde harcama eksi yazılır. Hiç eksi yoksa (kredi kartı
  // ekstresi) artılar harcamadır, "ödeme" satırları hariç.
  final eksiVar = ham.any((x) => x.$3 < 0);
  return [
    for (final (t, ac, v) in ham)
      EkstreSatir(
        tarih: t,
        aciklama: ac,
        tutar: v.abs(),
        harcama: eksiVar ? v < 0 : !_odemeMi(ac),
      )
  ];
}

bool _odemeMi(String ac) {
  final a = araMetni(ac);
  return a.contains('odeme') && !a.contains('fatura odeme') || a.contains('iade');
}

const _kategoriKelimeleri = <String, List<String>>{
  'Market': ['migros', 'bim ', 'bim-', 'a101', 'a-101', 'sok ', 'sok market', 'carrefour', 'file ',
    'market', 'bakkal', 'kasap', 'manav', 'firin', 'ekmek', 'getir', 'macro'],
  'Araba (yakıt)': ['opet', 'shell', 'petrol ofisi', ' po ', 'bp ', 'total', 'aytemiz', 'akaryakit',
    'benzin', 'lukoil', 'moil'],
  'Elektrik': ['enerjisa', 'meram elektrik', 'medas', 'elektrik', 'ck enerji', 'oedas'],
  'Su': ['koski', 'su idaresi', 'su faturasi', 'aski'],
  'Doğalgaz': ['gaz', 'igdas', 'aksa', 'selcukgaz'],
  'İnternet / Telefon': ['turkcell', 'vodafone', 'turk telekom', 'turktelekom', 'superonline',
    'internet', 'ttnet', 'netflix', 'youtube', 'spotify', 'digiturk'],
  'Sağlık': ['eczane', 'hastane', 'saglik', 'klinik', 'doktor', 'medical'],
  'Okul': ['okul', 'kirtasiye', 'dershane', 'kurs', 'egitim', 'kitap'],
  'Giyim': ['lcw', 'lc waikiki', 'defacto', 'koton', 'mavi', 'boyner', 'flo', 'giyim', 'ayakkabi'],
  'Araba (sigorta/kasko)': ['kasko', 'trafik sigorta', 'sigorta'],
  'Araba (bakım/tamir)': ['oto servis', 'otomotiv', 'yedek parca', 'oto tamir', 'lastik'],
  'Ev Kirası': ['kira'],
};

/// Tarlaya ait olabilecek harcamalar: kalem tahmini.
const _tarlaKelimeleri = <String, List<String>>{
  'Gübre': ['gubre', 'toros', 'igsas', 'gubretas'],
  'İlaç': ['zirai ilac', 'tarim ilac', 'zirai'],
  'Tohum': ['tohum', 'fide'],
  'Mazot': ['mazot', 'motorin'],
};

String evKategorisiTahmin(String aciklama) {
  final a = ' ${araMetni(aciklama)} ';
  for (final e in _kategoriKelimeleri.entries) {
    if (e.value.any(a.contains)) return e.key;
  }
  return 'Diğer';
}

/// Tarla gideri gibi görünüyorsa kalem adı, değilse null.
String? tarlaKalemiTahmin(String aciklama) {
  final a = ' ${araMetni(aciklama)} ';
  for (final e in _tarlaKelimeleri.entries) {
    if (e.value.any(a.contains)) return e.key;
  }
  if (a.contains('tarim kredi') || a.contains('ziraat') && a.contains('bayi')) return 'Diğer';
  return null;
}
