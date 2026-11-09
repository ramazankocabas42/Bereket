/// Kameradan okunan belge metnini (fiş, fatura, el yazısı hesap) çözer:
/// türü, firmayı, tarihi, toplamı, litreyi ve satır satır tutarları bulur.
/// Saf Dart; test/widget_test.dart ile denenir.
library;

import 'bicim.dart';
import 'ekstre.dart';

enum BelgeTuru { akaryakit, market, elektrik, faturaDiger, tarim, dekont, elYazisi, diger }

const belgeTuruAdi = {
  BelgeTuru.akaryakit: '⛽ Akaryakıt fişi',
  BelgeTuru.market: '🛒 Market fişi',
  BelgeTuru.elektrik: '⚡ Elektrik faturası',
  BelgeTuru.faturaDiger: '🧾 Fatura',
  BelgeTuru.tarim: '🌱 Tarım girdisi (gübre, ilaç, tohum)',
  BelgeTuru.dekont: '🏦 Dekont / POS slip (ödeme)',
  BelgeTuru.elYazisi: '✍️ El yazısı / hesap listesi',
  BelgeTuru.diger: '📄 Belge',
};

class BelgeSatiri {
  BelgeSatiri(this.ad, this.tutar, {this.miktar});
  String ad;
  double tutar;
  double? miktar;
}

class BelgeOzet {
  BelgeOzet({
    required this.tur,
    required this.firma,
    required this.tarih,
    required this.toplam,
    required this.satirlar,
    this.litre,
    this.kalem,
    this.aboneNo = '',
    this.kwh,
    this.odemeBelgesi = false,
  });

  /// Dekont ya da POS slip: bir ödemenin kanıtı (fatura değil).
  bool odemeBelgesi;

  /// Elektrik faturasında abone / tesisat numarası.
  String aboneNo;

  /// Elektrik faturasındaki toplam tüketim.
  double? kwh;

  BelgeTuru tur;
  String firma;
  int tarih; // ms, bulunamazsa bugün
  double toplam;
  double? litre;

  /// Tarla gideri ise önerilen kalem (Gübre, İlaç, Tohum, Mazot...).
  String? kalem;
  final List<BelgeSatiri> satirlar;
}

final _tutarRe = RegExp(r'(\d{1,3}(?:[.\s]\d{3})*,\d{2}|\d+,\d{2}|\d{1,3}(?:\.\d{3})+|\d+\.\d{2})');

final _tarihSaatRe = RegExp(r'\d{1,2}[./-]\d{1,2}[./-]\d{2,4}|\d{1,2}:\d{2}(:\d{2})?');

double? _sonTutar(String satir) {
  final temiz = satir.replaceAll('*', ' ').replaceAll(_tarihSaatRe, ' ');
  final m = _tutarRe.allMatches(temiz).toList();
  if (m.isEmpty) return null;
  return tutarOku(m.last.group(0)!.replaceAll(' ', ''));
}

bool _var(String metin, List<String> kelimeler) => kelimeler.any(metin.contains);

BelgeOzet belgeCoz(String hamMetin, {DateTime? bugun}) {
  final satirlar = hamMetin
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  final a = ' ${araMetni(hamMetin)} ';

  // Tür
  BelgeTuru tur;
  // Faturalarda da "IBAN / havale ile ödeyebilirsiniz" yazar; onları dekont saymamak için.
  final havale = _var(a, ['dekont', 'virman', 'para transferi', 'hesaptan hesaba']) ||
      (_var(a, ['havale', ' eft', 'fast ']) && !_var(a, ['fatura', 'e-arsiv'])) ||
      (a.contains('gonderen') && a.contains('alici'));
  final slip = _var(a, ['slip', ' pos ', 'onay kodu', 'provizyon', 'musteri nushasi',
    'satis tutari', 'islem tutari', 'kart no', 'temassiz']);
  if (havale) {
    tur = BelgeTuru.dekont;
  } else if (_var(a, ['motorin', 'benzin', 'kursunsuz', 'dizel', 'diesel', 'akaryakit', 'opet', 'shell',
    'petrol ofisi', 'aytemiz', ' lpg', 'pompa'])) {
    tur = BelgeTuru.akaryakit;
  } else if (_var(a, ['gubre', 'zirai ilac', 'tohum', ' dap ', ' ure ', 'amonyum', 'herbisit',
    'fungisit', 'insektisit', 'tarim kredi'])) {
    tur = BelgeTuru.tarim;
  } else if (_var(a, ['kwh', 'enerjisa', 'medas', 'elektrik', 'tuketim bedeli', 'aktif enerji'])) {
    tur = BelgeTuru.elektrik;
  } else if (_var(a, ['migros', ' bim ', 'a101', ' sok ', 'carrefour', 'market', 'file '])) {
    tur = BelgeTuru.market;
  } else if (slip) {
    tur = BelgeTuru.dekont;
  } else if (_var(a, ['fatura', 'e-arsiv', 'vergi no', 'vkn', 'kdv'])) {
    tur = BelgeTuru.faturaDiger;
  } else {
    tur = BelgeTuru.diger;
  }

  // Tarih
  var tarih = 0;
  for (final s in satirlar) {
    final m = RegExp(r'(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})').firstMatch(s);
    if (m != null) {
      var y = int.parse(m.group(3)!);
      if (y < 100) y += 2000;
      final ay = int.parse(m.group(2)!), gun = int.parse(m.group(1)!);
      if (ay >= 1 && ay <= 12 && gun >= 1 && gun <= 31 && y > 2000 && y < 2100) {
        tarih = DateTime(y, ay, gun, 12).millisecondsSinceEpoch;
        break;
      }
    }
  }
  if (tarih == 0) tarih = (bugun ?? DateTime.now()).millisecondsSinceEpoch;

  // Firma: ilk anlamlı (harf içeren, çok kısa olmayan) satır
  var firma = '';
  for (final s in satirlar.take(5)) {
    if (RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]{3,}').hasMatch(s) && !araMetni(s).contains('fis')) {
      firma = s;
      break;
    }
  }

  // Dekont: parayı alan firma / kişi
  if (havale) {
    for (var i = 0; i < satirlar.length; i++) {
      final k = araMetni(satirlar[i]);
      if (!k.contains('alici') || (k.contains('iban') && !k.contains('ad'))) continue;
      var ad = satirlar[i].contains(':')
          ? satirlar[i].substring(satirlar[i].indexOf(':') + 1).trim()
          : satirlar[i].replaceAll(RegExp(r'^[^ ]*ALICI[^ ]*\s*(ADI|UNVANI|ÜNVANI)?\s*(SOYADI)?', caseSensitive: false), '').trim();
      if (ad.length < 3 && i + 1 < satirlar.length) ad = satirlar[i + 1];
      if (RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]{3,}').hasMatch(ad) && !araMetni(ad).startsWith('tr')) {
        firma = ad;
        break;
      }
    }
  }

  // Toplam: "TOPLAM / GENEL TOPLAM / ÖDENECEK" satırındaki tutar; yoksa en büyük tutar
  double? toplam;
  for (final s in satirlar.reversed) {
    final k = araMetni(s);
    if ((k.contains('toplam') || k.contains('odenecek') || k.contains('tutar')) &&
        !k.contains('kdv') &&
        !k.contains('ara toplam')) {
      final v = _sonTutar(s);
      if (v != null && v > 0) {
        toplam = v;
        break;
      }
    }
  }
  final tumTutarlar = [for (final s in satirlar) _sonTutar(s)].whereType<double>().toList();
  toplam ??= tumTutarlar.isEmpty ? 0 : tumTutarlar.reduce((x, y) => x > y ? x : y);

  // Litre
  double? litre;
  final lm = RegExp(r'(\d+[.,]\d+)\s*(lt|litre|l\b)', caseSensitive: false).firstMatch(hamMetin);
  if (lm != null) litre = sayiOku(lm.group(1)!.replaceAll('.', ','));

  // Satırlar: "ad ... tutar" biçimindekiler
  final kalemSatirlari = <BelgeSatiri>[];
  for (final s in satirlar) {
    final k = araMetni(s);
    if (k.contains('toplam') || k.contains('kdv') || k.contains('nakit') || k.contains('kart')) {
      continue;
    }
    final v = _sonTutar(s);
    if (v == null || v <= 0) continue;
    final ad = s.replaceAll(_tarihSaatRe, ' ').replaceAll(_tutarRe, '').replaceAll(RegExp(r'[*#:=₺]|\bTL\b|\sx\s'), ' ').trim();
    if (ad.length < 2) continue;
    final mm = RegExp(r'(\d+[.,]?\d*)\s*(kg|lt|ton|adet|torba|cuval|çuval)', caseSensitive: false)
        .firstMatch(s);
    kalemSatirlari.add(BelgeSatiri(ad.replaceAll(RegExp(r'\s+'), ' '), v,
        miktar: mm == null ? null : sayiOku(mm.group(1)!)));
  }

  // El yazısı listesi: belge türü bulunamadı, birden çok "isim tutar" satırı var
  if (tur == BelgeTuru.diger && kalemSatirlari.length >= 2) tur = BelgeTuru.elYazisi;
  if (tur == BelgeTuru.elYazisi) {
    toplam = kalemSatirlari.fold<double>(0, (x, s) => x + s.tutar);
  }

  // Elektrik: abone/tesisat no ve toplam kWh
  var aboneNo = '';
  final am = RegExp(
          r'(abone|tesisat|sozlesme hesap|tekil kod|musteri)\s*(no|numarasi|kodu)?\s*[:.]?\s*(\d{5,16})')
      .firstMatch(araMetni(hamMetin));
  if (am != null) aboneNo = am.group(3)!;
  double? kwh;
  if (tur == BelgeTuru.elektrik) {
    for (final s in satirlar) {
      final k = araMetni(s);
      if (!k.contains('kwh')) continue;
      final m = RegExp(r'(\d{1,3}(?:\.\d{3})+(?:,\d+)?|\d+(?:,\d+)?)\s*kwh').firstMatch(k);
      if (m == null) continue;
      final x = sayiOku(m.group(1)!);
      if (x == null) continue;
      if (k.contains('toplam') || k.contains('tuketim')) {
        kwh = x;
        break;
      }
      if (kwh == null || x > kwh) kwh = x;
    }
  }

  String? kalem;
  if (tur == BelgeTuru.akaryakit) kalem = 'Mazot';
  if (tur == BelgeTuru.tarim) kalem = tarlaKalemiTahmin(hamMetin) ?? 'Gübre';
  if (tur == BelgeTuru.elektrik) kalem = 'Elektrik';
  if (tur == BelgeTuru.dekont) kalem = tarlaKalemiTahmin(hamMetin);

  return BelgeOzet(
    tur: tur,
    firma: firma,
    tarih: tarih,
    toplam: toplam ?? 0,
    satirlar: kalemSatirlari,
    litre: litre,
    kalem: kalem,
    aboneNo: aboneNo,
    kwh: kwh,
    odemeBelgesi: tur == BelgeTuru.dekont,
  );
}
