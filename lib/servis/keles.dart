import 'package:cloud_firestore/cloud_firestore.dart';

/// Keleş Satış'taki satışları okur (aynı Firebase projesi, aynı hesap).
/// Bereket bu verileri yalnızca okur, hiçbir şeyi değiştirmez.
class KelesSiparis {
  const KelesSiparis({
    required this.id,
    required this.no,
    required this.musteri,
    required this.urun,
    required this.miktar,
    required this.birim,
    required this.fiyat,
    required this.tahsil,
    required this.teslim,
    required this.tarih,
  });

  final String id;
  final int no;
  final String musteri, urun, birim;
  final double miktar, fiyat, tahsil;
  final bool teslim;
  final int tarih;

  double get tutar => miktar * fiyat;

  /// Miktar kg cinsinden (ton yazıldıysa çevrilir).
  double get kg {
    final b = birim.toLowerCase();
    if (b.startsWith('ton')) return miktar * 1000;
    return miktar;
  }

  /// Kg başı fiyat.
  double get kgFiyat {
    final b = birim.toLowerCase();
    if (b.startsWith('ton')) return fiyat / 1000;
    return fiyat;
  }
}

class Keles {
  Keles._();

  static final _db = FirebaseFirestore.instance;

  /// Kullanıcının Keleş Satış'taki firma kimliği; yoksa boş.
  static Future<String> firmaId(String uid) async {
    final d = await _db.collection('satis_kullanicilar').doc(uid).get();
    return (d.data()?['firmaId'] as String?) ?? '';
  }

  static Future<List<KelesSiparis>> siparisler(String uid) async {
    final fid = await firmaId(uid);
    if (fid.isEmpty) {
      throw 'Bu hesap Keleş Satış\'ta bir firmaya bağlı değil. '
          'Keleş Satış\'a hangi e-postayla giriyorsanız Bereket\'e de onunla girin.';
    }
    final s = await _db
        .collection('satis_firmalar')
        .doc(fid)
        .collection('siparisler')
        .orderBy('olusturma', descending: true)
        .limit(500)
        .get();
    double n(Object? v) => v is num ? v.toDouble() : 0;
    return [
      for (final d in s.docs)
        KelesSiparis(
          id: d.id,
          no: (d.data()['no'] as num?)?.toInt() ?? 0,
          musteri: (d.data()['musteri'] ?? '').toString(),
          urun: (d.data()['urun'] ?? '').toString(),
          miktar: n(d.data()['miktar']),
          birim: (d.data()['birim'] ?? 'kg').toString(),
          fiyat: n(d.data()['fiyat']),
          tahsil: (d.data()['tahsilatlar'] is List)
              ? (d.data()['tahsilatlar'] as List)
                  .fold(0.0, (a, t) => a + (t is Map ? n(t['tutar']) : 0.0))
              : 0.0,
          teslim: d.data()['teslim'] == true,
          tarih: (d.data()['olusturma'] as num?)?.toInt() ?? 0,
        )
    ];
  }
}
