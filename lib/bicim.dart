import 'package:intl/intl.dart';

final _tl = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
final _tl0 = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);
final _sayi = NumberFormat.decimalPattern('tr_TR')..maximumFractionDigits = 2;
final _kisa = NumberFormat.compact(locale: 'tr_TR');

String tl(num n) => _tl.format(n);

/// Kuruşsuz tutar: ₺81.500
String tl0(num n) => _tl0.format(n);

String sayi(num n) => _sayi.format(n);

/// Üstteki sayaçlar için kısa gösterim: 2,3 Mn ₺
String kisaTl(num n) =>
    '${n.abs() >= 100000 ? _kisa.format(n) : _sayi.format(n.round())} ₺';

/// Yüzde: %12,5
String yuzde(num n) => '%${_sayi.format(n)}';

/// Formlardaki kutulara yazılacak sayı (binlik ayırıcısız, virgüllü).
String girdi(num? n) {
  if (n == null) return '';
  final s = n == n.roundToDouble() ? n.toInt().toString() : n.toString();
  return s.replaceAll('.', ',');
}

/// "1.234,5" / "3.125" / "12.5" / "1 234" gibi yazımları sayıya çevirir.
/// Virgül yoksa ve noktalar üçlü gruplar ayırıyorsa binlik ayırıcı sayılır.
double? sayiOku(String? v) {
  if (v == null) return null;
  var s = v.trim().replaceAll(' ', '').replaceAll('₺', '');
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^-?\d{1,3}(\.\d{3})+$').hasMatch(s)) {
    s = s.replaceAll('.', '');
  }
  return double.tryParse(s);
}

String tarih(int ms) => ms <= 0
    ? '-'
    : DateFormat('dd.MM.yyyy', 'tr_TR')
        .format(DateTime.fromMillisecondsSinceEpoch(ms));

String ayAdi(int ay) => DateFormat('MMMM', 'tr_TR').format(DateTime(2026, ay));

/// Arama için sadeleştirilmiş metin: "Ilıcalı Şükrü" → "ilicali sukru"
String araMetni(String s) {
  const harita = {
    'ı': 'i', 'ş': 's', 'ğ': 'g', 'ü': 'u', 'ö': 'o', 'ç': 'c',
    'â': 'a', 'î': 'i', 'û': 'u',
  };
  var k = s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
  harita.forEach((a, b) => k = k.replaceAll(a, b));
  return k.replaceAll('̇', '').trim();
}
