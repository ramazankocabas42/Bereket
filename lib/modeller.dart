/// Firestore belgelerini saran basit kayıt sınıfı ve işletme ayarları.
library;

/// Her koleksiyondaki belge için ortak sarmalayıcı. Alanlar türlerine göre
/// güvenle okunur; eksik ya da hatalı alan 0 / boş döner.
class Kayit {
  const Kayit(this.id, this.d);

  final String id;
  final Map<String, dynamic> d;

  String s(String k) => (d[k] ?? '').toString();

  double n(String k) {
    final v = d[k];
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.')) ?? 0;
    return 0;
  }

  int t(String k) {
    final v = d[k];
    if (v is num) return v.toInt();
    return 0;
  }

  bool b(String k) => d[k] == true;

  List<String> l(String k) {
    final v = d[k];
    if (v is List) return [for (final x in v) x.toString()];
    return const [];
  }

  Map<String, dynamic> m(String k) {
    final v = d[k];
    if (v is Map) return {for (final e in v.entries) e.key.toString(): e.value};
    return const {};
  }

  List<Map<String, dynamic>> liste(String k) {
    final v = d[k];
    if (v is! List) return const [];
    return [
      for (final x in v)
        if (x is Map) {for (final e in x.entries) e.key.toString(): e.value}
    ];
  }

  /// Kaydın ait olduğu yıl: 'yil' alanı, yoksa 'tarih' alanının yılı.
  int get yil {
    final y = t('yil');
    if (y > 0) return y;
    final ms = t('tarih');
    return ms > 0 ? DateTime.fromMillisecondsSinceEpoch(ms).year : 0;
  }
}

/// İşletme belgesi ve ayarları.
class Isletme {
  const Isletme({
    required this.id,
    required this.ad,
    required this.sahip,
    required this.uyeler,
    required this.yoneticiler,
    required this.ayarlar,
    this.aile = const {},
  });

  /// Aile üyeleri: kullanıcı kimliği → hesap sahibi adı (Babam, Kardeşim).
  final Map<String, String> aile;

  final String id;
  final String ad;
  final String sahip;
  final List<String> uyeler;
  final List<String> yoneticiler;
  final Map<String, dynamic> ayarlar;

  factory Isletme.fromMap(String id, Map<String, dynamic> d) {
    List<String> l(String k) =>
        (d[k] is List) ? [for (final x in d[k] as List) x.toString()] : <String>[];
    final a = d['ayarlar'];
    return Isletme(
      id: id,
      ad: (d['ad'] ?? '').toString(),
      sahip: (d['sahip'] ?? '').toString(),
      uyeler: l('uyeler'),
      yoneticiler: l('yoneticiler'),
      ayarlar: a is Map ? {for (final e in a.entries) e.key.toString(): e.value} : {},
      aile: d['aile'] is Map
          ? {for (final e in (d['aile'] as Map).entries) e.key.toString(): e.value.toString()}
          : const {},
    );
  }

  double _n(String k, double vars) {
    final v = ayarlar[k];
    return v is num ? v.toDouble() : vars;
  }

  /// Borsada tescilli satışta gelir vergisi stopajı (%).
  double get stopajBorsa => _n('stopajBorsa', 1);

  /// Borsa dışı satışta stopaj (%).
  double get stopajDisi => _n('stopajDisi', 2);

  /// SGK (Bağ-Kur) prim kesintisi (%).
  double get sgk => _n('sgk', 2);

  /// Borsa tescil ücreti (binde), tüm borsalar için varsayılan.
  double get tescilBinde => _n('tescilBinde', 2);

  /// Nakliye ücreti: ton başına, km başına (₺).
  double get nakliyeTonKm => _n('nakliyeTonKm', 4);

  /// Gram altın fiyatı (₺), altın borç ve birikimler için.
  double get altinGram => _n('altinGram', 0);

  /// Ürüne özel münavebe arası (yıl) değişiklikleri.
  Map<String, int> get munavebe {
    final v = ayarlar['munavebe'];
    if (v is! Map) return const {};
    return {
      for (final e in v.entries)
        if (e.value is num) e.key.toString(): (e.value as num).toInt()
    };
  }
}
