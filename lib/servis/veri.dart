import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../hesap.dart';
import '../modeller.dart';

/// Firestore yolları ve yazma işlemleri.
///
/// tarlam_kullanicilar/{uid}              : {ad, isletmeId}
/// tarlam_kodlar/{kod}                    : {isletmeId}  (davet kodu)
/// tarlam_isletmeler/{iid}                : ad, sahip, uyeler, yoneticiler, ayarlar
/// tarlam_isletmeler/{iid}/{koleksiyon}   : tarlalar, ekimler, giderler...
class Veri {
  Veri._();

  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get kullanicilar =>
      _db.collection('tarlam_kullanicilar');
  static CollectionReference<Map<String, dynamic>> get kodlar =>
      _db.collection('tarlam_kodlar');
  static CollectionReference<Map<String, dynamic>> get isletmeler =>
      _db.collection('tarlam_isletmeler');
  static CollectionReference<Map<String, dynamic>> get aileKodlari =>
      _db.collection('tarlam_aile_kodlar');

  /// Aile üyesi (Babam, Kardeşim) için katılma kodu üretir.
  static Future<String> aileKoduOlustur(String iid, String ad) async {
    final kod = yeniKod();
    await aileKodlari.doc(kod).set({'isletmeId': iid, 'ad': ad, 'olusturma': simdi});
    return kod;
  }

  /// Aile üyesini işletmeden çıkarır (yönetici).
  static Future<void> aileUyesiCikar(String iid, String uid) =>
      isletmeler.doc(iid).update({'aile.$uid': FieldValue.delete()});

  static Future<void> aileOzetiYaz(String iid, String ad, Map<String, dynamic> ozet) =>
      isletmeler.doc(iid).collection('aile_ozet').doc(ad).set({...ozet, 'guncelleme': simdi});

  static const koleksiyonlar = [
    'tarlalar', 'ekimler', 'giderler', 'sayaclar', 'satislar', 'hesaplar',
    'gelirler', 'isyerleri', 'varliklar', 'fiyatlar', 'isler', 'kotalar', 'ekipmanlar', 'aile_hareketler',
  ];

  static CollectionReference<Map<String, dynamic>> kol(String iid, String ad) =>
      isletmeler.doc(iid).collection(ad);

  static DocumentReference<Map<String, dynamic>> gizli(String iid) =>
      isletmeler.doc(iid).collection('gizli').doc('kodlar');

  static int get simdi => DateTime.now().millisecondsSinceEpoch;

  static String yeniKod() {
    const harf = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(8, (_) => harf[r.nextInt(harf.length)]).join();
  }

  static Future<void> isletmeKur(String uid, String ad, String isletmeAdi) async {
    final i = isletmeler.doc();
    final kod = yeniKod();
    final b = _db.batch();
    b.set(i, {
      'ad': isletmeAdi.trim(),
      'sahip': uid,
      'uyeler': [uid],
      'yoneticiler': [uid],
      'ayarlar': {
        'sahipler': ['Babam', 'Kardeşim'],
      },
    });
    b.set(gizli(i.id), {'kod': kod});
    b.set(kodlar.doc(kod), {'isletmeId': i.id});
    b.set(kullanicilar.doc(uid), {'ad': ad.trim(), 'isletmeId': i.id},
        SetOptions(merge: true));
    await b.commit();
  }

  static Future<void> kodlaKatil(String uid, String ad, String kodYazi) async {
    final kod = kodYazi.trim().toUpperCase().replaceAll(' ', '');
    final k = await kodlar.doc(kod).get();
    final iid = k.data()?['isletmeId'] as String?;
    if (!k.exists || iid == null) {
      // Aile kodu mu?
      final a = await aileKodlari.doc(kod).get();
      final aiid = a.data()?['isletmeId'] as String?;
      final aad = a.data()?['ad'] as String?;
      if (!a.exists || aiid == null || aad == null) {
        throw 'Bu davet kodu bulunamadı. Kodu işletme sahibinden tekrar isteyin.';
      }
      final b = _db.batch();
      b.set(isletmeler.doc(aiid).collection('aileKatilim').doc(uid), {'kod': kod});
      b.update(isletmeler.doc(aiid), {'aile.$uid': aad});
      try {
        await b.commit();
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          throw 'Bu kod artık geçerli değil. Yeni kodu isteyin.';
        }
        rethrow;
      }
      await kullanicilar
          .doc(uid)
          .set({'ad': ad.trim(), 'isletmeId': aiid}, SetOptions(merge: true));
      return;
    }
    var zatenVar = false;
    try {
      final i = await isletmeler.doc(iid).get(const GetOptions(source: Source.server));
      zatenVar = ((i.data()?['uyeler'] as List?)?.contains(uid) ?? false);
    } catch (_) {}
    if (!zatenVar) {
      final b = _db.batch();
      b.set(isletmeler.doc(iid).collection('katilim').doc(uid), {'kod': kod});
      b.update(isletmeler.doc(iid), {
        'uyeler': FieldValue.arrayUnion([uid]),
      });
      try {
        await b.commit();
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          throw 'Bu kod artık geçerli değil. Yeni kodu isteyin.';
        }
        rethrow;
      }
    }
    await kullanicilar
        .doc(uid)
        .set({'ad': ad.trim(), 'isletmeId': iid}, SetOptions(merge: true));
  }

  static Future<void> kodYenile(String iid, String eskiKod) async {
    final kod = yeniKod();
    final b = _db.batch();
    b.set(gizli(iid), {'kod': kod});
    b.set(kodlar.doc(kod), {'isletmeId': iid});
    if (eskiKod.isNotEmpty) b.delete(kodlar.doc(eskiKod));
    await b.commit();
  }

  static Future<void> isletmedenAyril(String uid) =>
      kullanicilar.doc(uid).set({'isletmeId': ''}, SetOptions(merge: true));

  static Future<void> isletmeGuncelle(String iid, Map<String, dynamic> veri) =>
      isletmeler.doc(iid).update(veri);

  /// Ayarlardan tek bir alanı değiştirir (ör. 'stopajBorsa').
  static Future<void> ayarYaz(String iid, String alan, Object? deger) =>
      isletmeler.doc(iid).update({'ayarlar.$alan': deger});

  /// Kaydı ekler ya da (id verilirse) günceller. Oluşturma bilgisi eklenir.
  static Future<String> kaydet(String iid, String koleksiyon,
      Map<String, dynamic> veri, {String? id, String? uid}) async {
    if (id == null || id.isEmpty) {
      final temiz = <String, dynamic>{
        for (final e in veri.entries)
          if (e.value != null) e.key: e.value
      };
      final ref = kol(iid, koleksiyon).doc();
      await ref.set({...temiz, 'olusturma': simdi, 'olusturan': uid ?? ''});
      return ref.id;
    }
    // update: verilen alanların tamamı (iç içe haritalar dahil) değişir,
    // null olan alanlar silinir.
    await kol(iid, koleksiyon).doc(id).update({
      for (final e in veri.entries)
        e.key: e.value ?? FieldValue.delete(),
    });
    return id;
  }

  /// Çok sayıda kaydı toplu ekler (ekstre aktarımı gibi), 400'lük gruplarla.
  static Future<void> topluEkle(String iid, String koleksiyon,
      List<Map<String, dynamic>> kayitlar, {String? uid}) async {
    for (var i = 0; i < kayitlar.length; i += 400) {
      final b = _db.batch();
      for (final k in kayitlar.skip(i).take(400)) {
        b.set(kol(iid, koleksiyon).doc(), {
          for (final e in k.entries)
            if (e.value != null) e.key: e.value,
          'olusturma': simdi,
          'olusturan': uid ?? '',
        });
      }
      await b.commit();
    }
  }

  static Future<void> sil(String iid, String koleksiyon, String id) =>
      kol(iid, koleksiyon).doc(id).delete();

  /// Borç/alacak hesabına hareket ekler.
  static Future<void> hareketEkle(String iid, String hesapId,
      {required String tip,
      required double tutar,
      String aciklama = '',
      int? tarih,
      String? anahtar}) {
    return kol(iid, 'hesaplar').doc(hesapId).update({
      'hareketler': FieldValue.arrayUnion([
        {
          'tip': tip,
          'tutar': tutar,
          'ac': aciklama,
          't': tarih ?? simdi,
          'k': anahtar ?? yeniKod(), // aynı tutarlı iki hareket birleşmesin
        }
      ]),
    });
  }

  /// Hesaba işlenmiş bir SMS'i işaretler (aynı mesaj ikinci kez eklenmesin).
  static Future<void> smsIsaretle(String iid, String hesapId, String anahtar) =>
      kol(iid, 'hesaplar').doc(hesapId).update({
        'smsAnahtarlar': FieldValue.arrayUnion([anahtar]),
      });

  static Future<void> hareketSil(
          String iid, String hesapId, Map<String, dynamic> hareket) =>
      kol(iid, 'hesaplar').doc(hesapId).update({
        'hareketler': FieldValue.arrayRemove([hareket]),
      });

  /// Ödenmemiş bir gider/işçilik için, adı verilen kişinin borç hesabına
  /// yazar; hesap yoksa açar.
  static Future<void> borcaYaz(String iid, Veriler v,
      {required String kime,
      required String tur,
      required double tutar,
      required String aciklama,
      required int tarih,
      String? uid,
      String yon = 'borc'}) async {
    final ad = kime.trim();
    if (ad.isEmpty || tutar <= 0) return;
    final alacak = yon == 'alacak';
    Kayit? hesap;
    for (final h in v.hesaplar) {
      if ((h.s('yon') == 'alacak') == alacak && h.s('ad').toLowerCase() == ad.toLowerCase()) {
        hesap = h;
      }
    }
    final id = hesap?.id ??
        await kaydet(iid, 'hesaplar', {
          'ad': ad,
          'yon': alacak ? 'alacak' : 'borc',
          'tur': tur,
          'birim': 'TL',
          'hareketler': <Map<String, dynamic>>[],
        }, uid: uid);
    await hareketEkle(iid, id,
        tip: 'artis', tutar: tutar, aciklama: aciklama, tarih: tarih);
  }
}

/// Bir işletmenin canlı verisi: işletme belgesi ve bütün koleksiyonlar.
class Durum extends ChangeNotifier {
  Durum({required this.iid, required this.uid}) {
    _dinle();
  }

  final String iid;
  final String uid;

  Isletme? isletme;
  bool isletmeYok = false;
  Object? hata;
  String davetKodu = '';
  final Map<String, List<Kayit>> _k = {};
  final Set<String> _yuklenen = {};
  final Map<String, String> isimler = {};

  StreamSubscription? _iAbone, _gAbone;
  final List<StreamSubscription> _aboneler = [];
  bool _kapandi = false;
  int _deneme = 0;

  bool get uye => isletme?.uyeler.contains(uid) ?? false;

  /// Aile üyesiyse hesap sahibi adı (Babam, Kardeşim); değilse boş.
  String get aileAdi => isletme?.aile[uid] ?? '';
  bool get aileUyesi => !uye && aileAdi.isNotEmpty;

  // Aile üyesi görünümü
  Map<String, dynamic>? aileOzet;
  List<Kayit> aileHareketler = const [];
  bool aileYuklendi = false;
  StreamSubscription? _aoAbone, _ahAbone;
  Timer? _ozetZamanlayici;
  final Map<String, String> _yazilanOzet = {};
  bool get yonetici => isletme?.yoneticiler.contains(uid) ?? false;
  bool get yuklendi => _yuklenen.length == Veri.koleksiyonlar.length;

  Veriler _v = Veriler();
  Veriler get v => _v;

  void _yenile() {
    _v = Veriler(isletme: isletme, koleksiyonlar: Map.of(_k));
    notifyListeners();
    if (uye && yuklendi && (isletme?.aile.isNotEmpty ?? false)) {
      _ozetZamanlayici?.cancel();
      _ozetZamanlayici = Timer(const Duration(seconds: 3), _aileOzetleriniYaz);
    }
  }

  /// Aile üyelerinin ekranındaki özetleri günceller (değiştiyse).
  Future<void> _aileOzetleriniYaz() async {
    if (_kapandi) return;
    final adlar = {...?isletme?.aile.values};
    for (final ad in adlar) {
      try {
        final o = _v.aileOzeti(ad);
        final j = jsonEncode(o);
        if (_yazilanOzet[ad] == j) continue;
        await Veri.aileOzetiYaz(iid, ad, o);
        _yazilanOzet[ad] = j;
      } catch (e) {
        debugPrint('Aile özeti yazılamadı ($ad): $e');
      }
    }
  }

  void _aileDinle() {
    final ad = aileAdi;
    _aoAbone = Veri.isletmeler.doc(iid).collection('aile_ozet').doc(ad).snapshots().listen((s) {
      aileOzet = s.data();
      aileYuklendi = true;
      notifyListeners();
    }, onError: (Object e) {
      hata = e;
      aileYuklendi = true;
      notifyListeners();
    });
    _ahAbone = Veri.kol(iid, 'aile_hareketler')
        .where('kisi', isEqualTo: ad)
        .snapshots()
        .listen((s) {
      aileHareketler = [for (final d in s.docs) Kayit(d.id, d.data())]
        ..sort((a, b) => b.t('tarih').compareTo(a.t('tarih')));
      notifyListeners();
    }, onError: (Object e) {
      hata = e;
      notifyListeners();
    });
  }

  void _dinle() {
    _iAbone?.cancel();
    _iAbone = Veri.isletmeler.doc(iid).snapshots().listen((s) {
      _deneme = 0;
      isletmeYok = !s.exists;
      isletme = s.exists ? Isletme.fromMap(s.id, s.data()!) : null;
      hata = null;
      if (uye && _aboneler.isEmpty) _koleksiyonlariDinle();
      if (aileUyesi && _aoAbone == null) _aileDinle();
      if (yonetici && _gAbone == null) {
        _gAbone = Veri.gizli(iid).snapshots().listen((g) {
          davetKodu = (g.data()?['kod'] as String?) ?? '';
          notifyListeners();
        }, onError: (_) {});
      }
      _isimleriGetir();
      _yenile();
    }, onError: (Object e) {
      // Katıldıktan hemen sonra üyelik sunucuya henüz yansımamış olabilir.
      if (_deneme < 4 && !_kapandi) {
        _deneme++;
        Future.delayed(Duration(seconds: 2 * _deneme), () {
          if (!_kapandi) _dinle();
        });
        return;
      }
      hata = e;
      notifyListeners();
    });
  }

  void _koleksiyonlariDinle() {
    for (final ad in Veri.koleksiyonlar) {
      _aboneler.add(Veri.kol(iid, ad).limit(5000).snapshots().listen((s) {
        _k[ad] = [for (final d in s.docs) Kayit(d.id, d.data())];
        _yuklenen.add(ad);
        _yenile();
      }, onError: (Object e) {
        debugPrint('$ad okunamadı: $e');
        _yuklenen.add(ad);
        hata ??= e;
        _yenile();
      }));
    }
  }

  Future<void> _isimleriGetir() async {
    final i = isletme;
    if (i == null) return;
    for (final u in {...i.uyeler, ...i.aile.keys, i.sahip}) {
      if (u.isEmpty || isimler.containsKey(u)) continue;
      isimler[u] = '';
      try {
        final d = await Veri.kullanicilar.doc(u).get();
        isimler[u] = (d.data()?['ad'] as String?) ?? '';
        if (!_kapandi) notifyListeners();
      } catch (_) {}
    }
  }

  String isim(String u) {
    final a = isimler[u] ?? '';
    return a.isEmpty ? 'Kullanıcı' : a;
  }

  // Kısayollar
  Future<String> kaydet(String koleksiyon, Map<String, dynamic> veri, {String? id}) =>
      Veri.kaydet(iid, koleksiyon, veri, id: id, uid: uid);
  Future<void> sil(String koleksiyon, String id) => Veri.sil(iid, koleksiyon, id);
  Future<void> ayarYaz(String alan, Object? deger) => Veri.ayarYaz(iid, alan, deger);

  @override
  void dispose() {
    _kapandi = true;
    _ozetZamanlayici?.cancel();
    _aoAbone?.cancel();
    _ahAbone?.cancel();
    _iAbone?.cancel();
    _gAbone?.cancel();
    for (final a in _aboneler) {
      a.cancel();
    }
    super.dispose();
  }
}

String hataYazisi(Object e) {
  if (e is String) return e;
  if (e is FirebaseException) {
    switch (e.code) {
      case 'permission-denied':
        return 'Bu işlem için yetkiniz yok. (Firestore kuralları güncellendi mi?)';
      case 'unavailable':
        return 'İnternet bağlantısı yok gibi görünüyor. Biraz sonra tekrar deneyin.';
      case 'invalid-email':
        return 'E-posta adresi geçersiz.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'email-already-in-use':
        return 'Bu e-posta ile zaten bir hesap var. Giriş yapın.';
      case 'weak-password':
        return 'Şifre çok zayıf, en az 6 karakter olmalı.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Biraz bekleyip tekrar deneyin.';
      case 'network-request-failed':
        return 'İnternet bağlantınızı kontrol edin.';
    }
    return e.message ?? e.code;
  }
  return '$e';
}
