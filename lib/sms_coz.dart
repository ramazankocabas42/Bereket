/// Banka SMS'lerini çözer: kart ekstre borcu, kredi taksiti, ödeme alındı,
/// gelen para, kartla harcama. Saf Dart.
library;

import 'bicim.dart';
import 'ekstre.dart';

enum SmsTuru { kartBorcu, krediTaksit, odemeAlindi, gelen, harcama }

const smsTuruAdi = {
  SmsTuru.kartBorcu: '💳 Kart ekstre borcu',
  SmsTuru.krediTaksit: '📄 Kredi taksiti',
  SmsTuru.odemeAlindi: '✅ Ödeme alındı',
  SmsTuru.gelen: '📥 Gelen para',
  SmsTuru.harcama: '🛒 Kart harcaması',
};

class BankaMesaji {
  BankaMesaji({
    required this.banka,
    required this.tur,
    required this.tutar,
    required this.tarih,
    required this.metin,
    this.sonOdeme = 0,
  });

  final String banka;
  final SmsTuru tur;
  final double tutar;
  final int tarih; // SMS'in geldiği an (ms)
  final int sonOdeme; // ms, yoksa 0
  final String metin;

  String get anahtar {
    final d = DateTime.fromMillisecondsSinceEpoch(tarih);
    return 'sms|$banka|${tur.name}|${tutar.toStringAsFixed(2)}|${d.year}-${d.month}-${d.day}';
  }

  /// Hesap adı (kart / kredi).
  String get hesapAdi => switch (tur) {
        SmsTuru.krediTaksit => '$banka Kredi',
        SmsTuru.odemeAlindi =>
          araMetni(metin).contains('kart') ? '$banka Kredi Kartı' : '$banka Kredi',
        _ => '$banka Kredi Kartı',
      };
}

String? bankaBul(String adres, String metin) {
  final a = araMetni('$adres $metin');
  final ad = araMetni(adres);
  if (a.contains('garanti')) return 'Garanti BBVA';
  if (a.contains('vakif')) return 'Vakıfbank';
  if (a.contains('ziraat')) return 'Ziraat Bankası';
  if (a.contains('yapi kredi') || a.contains('yapikredi') || ad.contains('ykb') || ad.contains('world')) {
    return 'Yapı Kredi';
  }
  if (a.contains('kuveyt')) return 'Kuveyt Türk';
  if (ad.contains('ing') || a.contains('ing bank') || a.contains('ingbank')) return 'ING';
  return null;
}

final _tlRe = RegExp(r'(\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?|\d+(?:,\d{1,2})?)\s*(TL|TRY|₺)', caseSensitive: false);

double? _tutar(String metin, {String? sonra}) {
  var bas = 0;
  if (sonra != null) {
    final i = araMetni(metin).indexOf(sonra);
    if (i >= 0) bas = i;
  }
  final m = _tlRe.firstMatch(metin.substring(bas)) ?? _tlRe.firstMatch(metin);
  if (m == null) return null;
  return sayiOku(m.group(1)!);
}

int _sonOdeme(String metin) {
  // "son ödeme" ifadesinden sonraki tarihi al; yoksa mesajdaki son tarihi.
  final tarihRe = RegExp(r'(\d{1,2})[./](\d{1,2})[./](\d{2,4})');
  final so = RegExp(r'son\s*(ö|o|Ö|O)deme', caseSensitive: false).firstMatch(metin);
  final hepsi = tarihRe.allMatches(metin).toList();
  if (hepsi.isEmpty) return 0;
  final m = so == null
      ? hepsi.last
      : hepsi.firstWhere((x) => x.start > so.start, orElse: () => hepsi.last);
  if (m == null) return 0;
  var y = int.parse(m.group(3)!);
  if (y < 100) y += 2000;
  final ay = int.parse(m.group(2)!), gun = int.parse(m.group(1)!);
  if (ay < 1 || ay > 12 || gun < 1 || gun > 31) return 0;
  return DateTime(y, ay, gun, 12).millisecondsSinceEpoch;
}

bool _herhangi(String a, List<String> l) => l.any(a.contains);

/// Banka SMS'i değilse ya da tanınmayan bir mesajsa null.
BankaMesaji? smsCoz(String adres, String metin, int tarih) {
  final banka = bankaBul(adres, metin);
  if (banka == null) return null;
  final a = araMetni(metin);
  if (_herhangi(a, ['sifre', 'dogrulama kodu', 'onay kodu', 'tek kullanimlik', 'kampanya', 'firsat'])) {
    return null;
  }
  SmsTuru? tur;
  String? sonra;
  if (_herhangi(a, ['odemeniz', 'odeme']) &&
      _herhangi(a, ['alinmis', 'alindi', 'tahsil edil', 'yapilmis', 'gerceklesti']) &&
      _herhangi(a, ['kart', 'kredi', 'taksit'])) {
    tur = SmsTuru.odemeAlindi;
  } else if (_herhangi(a, ['ekstre', 'donem borc', 'hesap kesim']) ||
      (a.contains('kart') && a.contains('son odeme'))) {
    tur = SmsTuru.kartBorcu;
    sonra = 'borc';
  } else if (a.contains('taksit') && _herhangi(a, ['kredi', 'son odeme', 'vade', 'odeme tarihi'])) {
    tur = SmsTuru.krediTaksit;
    sonra = 'taksit';
  } else if (a.contains('hesabiniza') &&
      _herhangi(a, ['yatiril', 'gelmis', 'aktaril', 'gonderil', 'eft', 'havale', 'fast', 'maas']) &&
      !a.contains('cekil')) {
    tur = SmsTuru.gelen;
  } else if (_herhangi(a, ['harcama', 'alisveris', 'islem yapil', 'odeme yapil']) && a.contains('kart')) {
    tur = SmsTuru.harcama;
  }
  if (tur == null) return null;
  final tutar = _tutar(metin, sonra: sonra);
  if (tutar == null || tutar <= 0) return null;
  return BankaMesaji(
    banka: banka,
    tur: tur,
    tutar: tutar,
    tarih: tarih,
    metin: metin,
    sonOdeme: (tur == SmsTuru.kartBorcu || tur == SmsTuru.krediTaksit) ? _sonOdeme(metin) : 0,
  );
}

/// Harcama mesajında işyeri adı (yoksa boş).
String harcamaYeri(String metin) {
  final m = RegExp(r'([A-ZÇĞİÖŞÜ0-9][A-ZÇĞİÖŞÜ0-9 .&\-]{3,40})\s+(isyerinde|işyerinde|firmasinda|firmasında)',
          caseSensitive: false)
      .firstMatch(metin);
  if (m != null) return m.group(1)!.trim();
  return '';
}

String smsKategori(BankaMesaji m) => evKategorisiTahmin(m.metin);
