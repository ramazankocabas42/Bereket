/// Uygulamanın bütün hesapları: gider dağıtımı, dekar başı maliyet,
/// münavebe, satış kesintileri, depo, yıllık kârlılık. Ekranlardan bağımsız,
/// saf Dart; test/hesap_test.dart ile denenir.
library;

import 'modeller.dart';
import 'sabitler.dart';

/// Bir işletmenin o anki bütün verisi.
class Veriler {
  Veriler({this.isletme, Map<String, List<Kayit>>? koleksiyonlar})
      : k = koleksiyonlar ?? {};

  final Isletme? isletme;
  final Map<String, List<Kayit>> k;

  List<Kayit> get tarlalar => k['tarlalar'] ?? const [];
  List<Kayit> get ekimler => k['ekimler'] ?? const [];
  List<Kayit> get giderler => k['giderler'] ?? const [];
  List<Kayit> get sayaclar => k['sayaclar'] ?? const [];
  List<Kayit> get satislar => k['satislar'] ?? const [];
  List<Kayit> get hesaplar => k['hesaplar'] ?? const [];
  List<Kayit> get gelirler => k['gelirler'] ?? const [];
  List<Kayit> get isyerleri => k['isyerleri'] ?? const [];
  List<Kayit> get varliklar => k['varliklar'] ?? const [];
  List<Kayit> get fiyatlar => k['fiyatlar'] ?? const [];
  List<Kayit> get isler => k['isler'] ?? const [];
  List<Kayit> get kotalar => k['kotalar'] ?? const [];
  List<Kayit> get ekipmanlar => k['ekipmanlar'] ?? const [];
  List<Kayit> get aileHareketleri => k['aile_hareketler'] ?? const [];

  double ekipmanDegeri(Kayit e) =>
      e.n('guncelDeger') > 0 ? e.n('guncelDeger') : e.n('alisFiyati');

  double toplamEkipman({String? sahip}) => ekipmanlar
      .where((e) => sahip == null || (e.s('sahip').isEmpty ? ben : e.s('sahip')) == sahip)
      .fold(0.0, (a, e) => a + ekipmanDegeri(e));

  String kotaKullanan(Kayit kota) =>
      kota.s('kullanan').isEmpty ? ben : kota.s('kullanan');

  /// Kotadan teslim edilen ton (o kotaya bağlanan satışlar).
  double kotaKullanilan(Kayit kota) => satislar
      .where((s) => s.s('kotaId') == kota.id)
      .fold(0.0, (a, s) => a + s.n('kg') / 1000);

  Kayit? bul(String koleksiyon, String id) {
    for (final x in k[koleksiyon] ?? const <Kayit>[]) {
      if (x.id == id) return x;
    }
    return null;
  }

  Kayit? tarla(String id) => bul('tarlalar', id);

  String tarlaAdi(String id) {
    final t = tarla(id);
    if (t == null) return 'Silinmiş tarla';
    final ad = t.s('ad');
    return ad.isNotEmpty ? ad : '${t.s('ada')}/${t.s('parsel')}';
  }

  double get toplamDekar =>
      tarlalar.fold(0.0, (a, t) => a + t.n('dekar'));

  // ---------------------------------------------------------------------
  // Hesap sahipleri (Ben, Babam, Kardeşim...)
  // ---------------------------------------------------------------------

  static const ben = 'Ben';

  /// Ayarlarda tanımlı ve kayıtlarda geçen bütün hesap sahipleri.
  List<String> sahipler() {
    final s = <String>{ben};
    final a = isletme?.ayarlar['sahipler'];
    if (a is List) {
      for (final x in a) {
        if (x.toString().trim().isNotEmpty) s.add(x.toString().trim());
      }
    }
    for (final t in tarlalar) {
      if (t.s('sahip').isNotEmpty) s.add(t.s('sahip'));
      if (t.s('gelirSahibi').isNotEmpty) s.add(t.s('gelirSahibi'));
    }
    for (final e in ekimler) {
      if (e.s('sahip').isNotEmpty) s.add(e.s('sahip'));
    }
    for (final x in [...tarlalar, ...ekimler]) {
      s.addAll(x.m('ortaklar').keys);
    }
    for (final k in kotalar) {
      if (k.s('kullanan').isNotEmpty) s.add(k.s('kullanan'));
    }
    s.remove(baskasi);
    s.remove('');
    return s.toList();
  }

  String tarlaSahibi(String tarlaId) {
    final s = tarla(tarlaId)?.s('sahip') ?? '';
    return s.isEmpty ? ben : s;
  }

  /// Ekimin hesabı kime ait: ekimde seçilen, yoksa tarlanın sahibi.
  String ekimSahibi(Kayit ekim) {
    final p = ekimPaylari(ekim);
    var en = ben;
    var max = -1.0;
    p.forEach((k, v) {
      if (v > max) {
        max = v;
        en = k;
      }
    });
    return en;
  }

  /// Ortaklık payları (kişi → 0..1). [ortaklar] {Ben: 50, Babam: 50}.
  static Map<String, double> _ortakPaylari(Map<String, dynamic> ortaklar) {
    final m = <String, double>{};
    ortaklar.forEach((k, v) {
      final y = v is num ? v.toDouble() : 0.0;
      if (k.isNotEmpty && y > 0) m[k] = y;
    });
    final top = m.values.fold(0.0, (a, b) => a + b);
    if (top <= 0) return const {};
    return {for (final e in m.entries) e.key: e.value / top};
  }

  /// Tarlanın varsayılan payları: ortaklar girildiyse onlar, yoksa eken.
  Map<String, double> tarlaPaylari(String tarlaId) {
    final t = tarla(tarlaId);
    final o = t == null ? const <String, double>{} : _ortakPaylari(t.m('ortaklar'));
    if (o.isNotEmpty && t?.s('sahip') != baskasi) return o;
    return {tarlaSahibi(tarlaId): 1};
  }

  /// Ekimin payları: ekimde ortak girildiyse o, ekimde kişi seçildiyse o,
  /// yoksa tarlanınki.
  Map<String, double> ekimPaylari(Kayit ekim) {
    final o = _ortakPaylari(ekim.m('ortaklar'));
    if (o.isNotEmpty) return o;
    if (ekim.s('sahip').isNotEmpty) return {ekim.s('sahip'): 1};
    return tarlaPaylari(ekim.s('tarlaId'));
  }

  /// Ekim tek kişiye aitse o kişi; ortaksa "Ortak".
  String ekimSahipYazisi(Kayit ekim) {
    final p = ekimPaylari(ekim);
    if (p.length == 1) return p.keys.first;
    return 'Ortak (${p.entries.map((e) => '${e.key} %${(e.value * 100).round()}').join(', ')})';
  }

  /// Satışın payları.
  Map<String, double> satisPaylari(Kayit satis) {
    if (satis.s('ekimId').isNotEmpty) {
      final e = bul('ekimler', satis.s('ekimId'));
      if (e != null) return ekimPaylari(e);
    }
    if (satis.s('tarlaId').isNotEmpty) return tarlaPaylari(satis.s('tarlaId'));
    return {satis.s('sahip').isEmpty ? ben : satis.s('sahip'): 1};
  }

  /// Satış tek kişiye aitse o, ortaksa en büyük paylı kişi (listeleme için).
  String satisSahibi(Kayit satis) {
    final p = satisPaylari(satis);
    var en = ben;
    var max = -1.0;
    p.forEach((k, v) {
      if (v > max) {
        max = v;
        en = k;
      }
    });
    return en;
  }

  /// Bir tarlanın belli bir yıldaki payları (o yıl ekimi varsa ekimden;
  /// aynı yıl iki ekim varsa eşit bölünür).
  Map<String, double> tarlaYilPaylari(String tarlaId, int yil) {
    final l = ekimler.where((e) => e.s('tarlaId') == tarlaId && e.t('yil') == yil).toList();
    if (l.isEmpty) return tarlaPaylari(tarlaId);
    final out = <String, double>{};
    for (final e in l) {
      ekimPaylari(e).forEach((k, v) => out[k] = (out[k] ?? 0) + v / l.length);
    }
    return out;
  }

  /// Başkasına verilen tarlaların yıllık kira geliri (kişiye göre).
  double kiraGeliri(String sahip) {
    var t = 0.0;
    for (final x in tarlalar) {
      if (x.s('sahip') != baskasi) continue;
      final g = x.s('gelirSahibi').isEmpty ? ben : x.s('gelirSahibi');
      if (g == sahip) t += x.n('kiraGeliri');
    }
    return t;
  }

  /// Giderin ne kadarı bu kişiye düşüyor (0..1). Tarlaya bağlı olmayan
  /// genel giderler tamamen "Ben"e yazılır.
  double giderSahipPayi(Kayit g, String sahip) {
    if (g.s('alan') == 'ev') return sahip == ben ? 1 : 0;
    final paylar = giderPaylari(g);
    if (paylar.isEmpty) return sahip == ben ? 1 : 0;
    var p = 0.0;
    paylar.forEach((tarlaId, pay) {
      p += pay * (tarlaYilPaylari(tarlaId, g.yil)[sahip] ?? 0);
    });
    return p;
  }

  /// Kişinin (ör. Babam) tarlalarının özeti; yil verilmezse tüm yıllar.
  SahipOzet sahipOzet(String sahip, {int? yil}) {
    final o = SahipOzet(sahip);
    for (final t in tarlalar) {
      final p = tarlaPaylari(t.id)[sahip] ?? 0;
      if (p > 0) {
        o.tarlaSayisi++;
        o.dekar += t.n('dekar') * p;
      }
    }
    for (final e in ekimler) {
      final p = ekimPaylari(e)[sahip] ?? 0;
      if (p <= 0) continue;
      if (yil != null && e.t('yil') != yil) continue;
      final z = ekimOzet(e);
      o.ekimler.add(z);
      o.paylar.add(p);
      z.kalemler.forEach((k, v) {
        final x = o.kalemler.putIfAbsent(k, () => KalemToplam(v.birim));
        x.tutar += v.tutar * p;
        x.miktar += v.miktar * p;
      });
      o.hasatKg += z.hasatKg * p;
    }
    o.kiraGeliri = kiraGeliri(sahip);
    for (final h in aileHareketleri) {
      if (h.s('kisi') != sahip) continue;
      if (yil != null && h.yil != yil) continue;
      if (h.s('yon') == 'o_verdi') {
        o.onunVerdigi += h.n('tutar');
      } else {
        o.benimVerdigim += h.n('tutar');
      }
    }
    for (final g in destekler) {
      if (yil != null && g.yil != yil) continue;
      final paylar = destekSahipPaylari(g);
      final pay = paylar[sahip] ?? 0;
      o.destek += pay;
      final yatan = g.s('yatan').isEmpty ? ben : g.s('yatan');
      // Kişinin payı bana yattıysa ben borçluyum; benim payım ona yattıysa o.
      if (yatan == ben && sahip != ben) o.destekDuzeltme += pay;
      if (yatan == sahip && sahip != ben) o.destekDuzeltme -= paylar[ben] ?? 0;
    }
    for (final s in satislar) {
      if (s.s('tur') == 'diger') continue;
      final p = satisPaylari(s)[sahip] ?? 0;
      if (p <= 0) continue;
      if (yil != null && s.yil != yil) continue;
      o.satis += satisHesap(s).beklenen * p;
      o.tahsil += tahsilToplam(s) * p;
      o.satisKg += s.n('kg') * p;
    }
    return o;
  }

  /// Tarladaki ekimler (yeniden eskiye).
  List<Kayit> tarlaEkimleri(String tarlaId) =>
      ekimler.where((e) => e.s('tarlaId') == tarlaId).toList()
        ..sort((a, b) => b.t('yil').compareTo(a.t('yil')));

  // ---------------------------------------------------------------------
  // Münavebe
  // ---------------------------------------------------------------------

  /// Tarlanın yıllara göre ürün geçmişi: ÇKS'den/elle girilen geçmiş +
  /// uygulamadaki ekimler (aynı yılda ekim varsa o geçerlidir).
  Map<int, String> urunGecmisi(Kayit tarla) {
    final g = <int, String>{};
    tarla.m('gecmis').forEach((y, u) {
      final yil = int.tryParse(y);
      if (yil != null && u.toString().isNotEmpty) g[yil] = u.toString();
    });
    for (final e in ekimler) {
      if (e.s('tarlaId') == tarla.id && e.t('yil') > 0) {
        g[e.t('yil')] = e.s('urun');
      }
    }
    return g;
  }

  int araYil(String urun) =>
      isletme?.munavebe[urun] ?? urunBul(urun)?.araYil ?? 2;

  Munavebe munavebe(Kayit tarla, String urun, int yil) =>
      munavebeKontrol(urunGecmisi(tarla), urun, yil, araYil(urun));

  /// "Ne ekeyim?" önerileri: münavebeye uygunluk, sonra geçmiş dekar kârı.
  List<Oneri> neEkeyim(Kayit tarla, int yil) {
    final gecmis = urunGecmisi(tarla);
    final karlar = urunDekarKarlari();
    final out = <Oneri>[];
    for (final u in urunler) {
      final m = munavebeKontrol(gecmis, u.ad, yil, araYil(u.ad));
      out.add(Oneri(u.ad, m, karlar[u.ad]));
    }
    out.sort((a, b) {
      final s = a.munavebe.seviye.compareTo(b.munavebe.seviye);
      if (s != 0) return s;
      final ak = a.dekarKar, bk = b.dekarKar;
      if (ak != null && bk != null) return bk.compareTo(ak);
      if (ak != null) return -1;
      if (bk != null) return 1;
      return a.urun.compareTo(b.urun);
    });
    return out;
  }

  // ---------------------------------------------------------------------
  // Giderler ve dekar başı maliyet
  // ---------------------------------------------------------------------

  /// Bir giderin tarlalara payı (tarlaId → 0..1). Elektrik gibi sayaca
  /// bağlı giderler, o sayacın suladığı ve o yıl ekili olan tarlalara
  /// dekarlarına göre bölünür.
  Map<String, double> giderPaylari(Kayit g) {
    var ids = g.l('tarlaIds');
    final sayacId = g.s('sayacId');
    if (sayacId.isNotEmpty) {
      final s = bul('sayaclar', sayacId);
      if (s != null) {
        ids = s.l('tarlaIds');
        final yil = g.yil;
        final ekili = ids
            .where((id) => ekimler.any((e) => e.s('tarlaId') == id && e.t('yil') == yil))
            .toList();
        if (ekili.isNotEmpty) ids = ekili;
      }
    }
    return dekaraGorePay(ids, (id) => tarla(id)?.n('dekar') ?? 0);
  }

  /// Ekimin maliyeti, hasadı ve satışı.
  EkimOzet ekimOzet(Kayit ekim) {
    final tarlaId = ekim.s('tarlaId');
    final yil = ekim.t('yil');
    final t = tarla(tarlaId);
    final ayniYil = ekimler
        .where((e) => e.s('tarlaId') == tarlaId && e.t('yil') == yil)
        .length;
    final bolen = ayniYil < 1 ? 1 : ayniYil;
    final kalemler = <String, KalemToplam>{};
    var kiraGiderVar = false;
    for (final g in giderler) {
      if (g.s('alan') == 'ev' || g.yil != yil) continue;
      final pay = giderPaylari(g)[tarlaId] ?? 0;
      if (pay <= 0) continue;
      final oran = pay / bolen;
      final kalem = g.s('kalem').isEmpty ? 'Diğer' : g.s('kalem');
      if (kalem == 'Arazi Kirası' || kalem == 'Ecrimisil') kiraGiderVar = true;
      final k = kalemler.putIfAbsent(kalem, () => KalemToplam(g.s('birim')));
      k.tutar += g.n('tutar') * oran;
      k.miktar += g.n('miktar') * oran;
    }
    // Kiralanan pancar kotası: kullananın o yılki pancar ekimlerine dekara göre.
    if (ekim.s('urun') == 'Şeker Pancarı') {
      final paylarE = ekimPaylari(ekim);
      for (final k in kotalar) {
        if (k.t('yil') != yil || k.n('kiraBedeli') <= 0) continue;
        final kul = kotaKullanan(k);
        final p = paylarE[kul] ?? 0;
        if (p <= 0) continue;
        final pancarlar = ekimler.where((e) =>
            e.t('yil') == yil &&
            e.s('urun') == 'Şeker Pancarı' &&
            (ekimPaylari(e)[kul] ?? 0) > 0);
        final top = pancarlar.fold(0.0,
            (a, e) => a + (tarla(e.s('tarlaId'))?.n('dekar') ?? 0) * (ekimPaylari(e)[kul] ?? 0));
        if (top <= 0) continue;
        final buDekar = (t?.n('dekar') ?? 0) * p;
        final kk = kalemler.putIfAbsent('Kota Kirası', () => KalemToplam('ton'));
        kk.tutar += k.n('kiraBedeli') * buDekar / top;
        kk.miktar += k.n('ton') * buDekar / top;
      }
    }
    // Kiralık tarlanın yıllık kirası, ayrıca gider girilmediyse eklenir.
    if (t != null && !kiraGiderVar && t.n('kira') > 0) {
      final k = kalemler.putIfAbsent(
          kiraKalemi(t.s('mulkiyet')), () => KalemToplam('dekar'));
      k.tutar += t.n('kira') / bolen;
      k.miktar += t.n('dekar') / bolen;
    }
    var destek = 0.0;
    final ortaklar = ekimPaylari(ekim).keys.toSet();
    for (final g in destekler) {
      if (g.yil != yil) continue;
      final hak = destekHakPaylari(g, tarlaId);
      var oran = 0.0;
      hak.forEach((k, v) {
        if (ortaklar.contains(k)) oran += v;
      });
      destek += (destekTarlaPaylari(g)[tarlaId] ?? 0) * oran / bolen;
    }
    var satisNet = 0.0, satisKg = 0.0;
    for (final s in satislar) {
      if (s.s('ekimId') == ekim.id) {
        final h = satisHesap(s);
        satisNet += h.beklenen;
        satisKg += s.n('kg');
      }
    }
    return EkimOzet(
      ekim: ekim,
      dekar: (t?.n('dekar') ?? 0) / bolen,
      kalemler: kalemler,
      hasatKg: ekim.n('hasatKg'),
      satisNet: satisNet,
      satisKg: satisKg,
      destek: destek,
    );
  }

  /// Ürün → ortalama dekar başı kâr (hasadı ve satışı olan ekimlerden).
  Map<String, double> urunDekarKarlari() {
    final top = <String, List<double>>{};
    for (final e in ekimler) {
      final o = ekimOzet(e);
      if (o.dekar <= 0 || o.satisNet <= 0) continue;
      top.putIfAbsent(e.s('urun'), () => []).add(o.dekarKar);
    }
    return {
      for (final e in top.entries)
        e.key: e.value.reduce((a, b) => a + b) / e.value.length
    };
  }

  /// Ürün bazında özet (tüm ekimlerin toplamı, istenirse tek yıl).
  List<UrunOzet> urunOzetleri({int? yil, String? sahip}) {
    final m = <String, UrunOzet>{};
    for (final e in ekimler) {
      if (yil != null && e.t('yil') != yil) continue;
      final p = sahip == null ? 1.0 : (ekimPaylari(e)[sahip] ?? 0);
      if (p <= 0) continue;
      final o = ekimOzet(e);
      final u = m.putIfAbsent(e.s('urun'), () => UrunOzet(e.s('urun')));
      u.ekimSayisi++;
      u.dekar += o.dekar * p;
      u.maliyet += o.toplam * p;
      u.hasatKg += o.hasatKg * p;
      u.satisNet += o.satisNet * p;
      u.satisKg += o.satisKg * p;
      u.destek += o.destek * p;
    }
    final l = m.values.toList()..sort((a, b) => b.dekar.compareTo(a.dekar));
    return l;
  }

  // ---------------------------------------------------------------------
  // Destekler
  // ---------------------------------------------------------------------

  List<Kayit> get destekler =>
      gelirler.where((g) => g.s('tur') == 'Destek').toList();

  /// Desteğin tarlalara payı (tarlaId → ₺).
  Map<String, double> destekTarlaPaylari(Kayit g) {
    final p = dekaraGorePay(g.l('tarlaIds'), (id) => tarla(id)?.n('dekar') ?? 0);
    return {for (final e in p.entries) e.key: e.value * g.n('tutar')};
  }

  /// Destek bu tarlada kime ait: alan bazlı destekler (mazot-gübre...)
  /// arazi ailenin kendi mülküyse arazi sahibine (ÇKS sahibi ya da tarlada
  /// seçilen), diğerleri o yıl ekene.
  Map<String, double> destekHakPaylari(Kayit g, String tarlaId) {
    final t = tarla(tarlaId);
    final eken = tarlaYilPaylari(tarlaId, g.yil);
    if (t == null || !alanBazliDestekler.contains(g.s('destekTuru'))) return eken;
    final m = t.s('mulkiyet');
    if (m.isNotEmpty && m != 'Kendi') return eken;
    final secilen = t.s('destekSahibi');
    if (secilen.isNotEmpty) return {secilen: 1};
    final cks = t.s('cks');
    if (cks.isEmpty || cks == cksBizdeDegil) return eken;
    return {cks: 1};
  }

  /// Desteğin kişilere payı. Tarla seçilmediyse tamamı yattığı kişiye.
  Map<String, double> destekSahipPaylari(Kayit g) {
    final out = <String, double>{};
    final p = destekTarlaPaylari(g);
    if (p.isEmpty) {
      final y = g.s('yatan').isEmpty ? ben : g.s('yatan');
      return {y: g.n('tutar')};
    }
    p.forEach((tarlaId, tutar) {
      destekHakPaylari(g, tarlaId).forEach((s, oran) {
        out[s] = (out[s] ?? 0) + tutar * oran;
      });
    });
    return out;
  }

  // ---------------------------------------------------------------------
  // Satış
  // ---------------------------------------------------------------------

  SatisHesap satisHesap(Kayit s) => satisHesapla(
        kg: s.n('kg'),
        fiyat: s.n('fiyat'),
        stopajYuzde: s.n('stopaj'),
        tescilBinde: s.n('tescil'),
        sgkYuzde: s.n('sgk'),
        nakliye: s.n('nakliye'),
        tutarElle: s.n('tutar'),
      );

  /// Piyasa ekranı: belli bir yere satılırsa ele geçecek tutar.
  SatisHesap pazarHesap({
    required String yer,
    required double fiyatKg,
    required double kg,
    required double km,
  }) {
    final i = isletme;
    final borsa = borsalar.contains(yer);
    final tmo = yer == 'TMO';
    return satisHesapla(
      kg: kg,
      fiyat: fiyatKg,
      stopajYuzde: (borsa || tmo) ? (i?.stopajBorsa ?? 1) : (i?.stopajDisi ?? 2),
      tescilBinde: borsa ? (i?.tescilBinde ?? 2) : 0,
      sgkYuzde: i?.sgk ?? 2,
      nakliye: kg / 1000 * km * (i?.nakliyeTonKm ?? 4),
    );
  }

  /// Son girilen fiyat: yer + ürün için en yeni kayıt.
  Kayit? sonFiyat(String yer, String urun) {
    Kayit? son;
    for (final f in fiyatlar) {
      if (f.s('yer') != yer || f.s('urun') != urun) continue;
      if (son == null || f.t('tarih') > son.t('tarih')) son = f;
    }
    return son;
  }

  // ---------------------------------------------------------------------
  // Depo
  // ---------------------------------------------------------------------

  List<DepoSatir> depo() {
    final m = <String, DepoSatir>{};
    for (final e in ekimler) {
      final kg = e.n('hasatKg');
      if (kg <= 0) continue;
      m.putIfAbsent(e.s('urun'), () => DepoSatir(e.s('urun'))).giren += kg;
    }
    for (final s in satislar) {
      if (s.s('tur') == 'diger') continue;
      final u = s.s('urun');
      if (u.isEmpty) continue;
      m.putIfAbsent(u, () => DepoSatir(u)).cikan += s.n('kg');
    }
    for (final d in m.values) {
      for (final yer in satisYerleri) {
        final f = sonFiyat(yer, d.urun);
        if (f != null && f.n('fiyat') > d.enIyiFiyat) {
          d.enIyiFiyat = f.n('fiyat');
          d.enIyiYer = yer;
        }
      }
    }
    final l = m.values.toList()..sort((a, b) => b.kalan.compareTo(a.kalan));
    return l;
  }

  // ---------------------------------------------------------------------
  // Borç / alacak hesapları
  // ---------------------------------------------------------------------

  /// Hesabın kalan bakiyesi (hesabın biriminde: ₺ ya da gram).
  double bakiye(Kayit h) => hesapBakiye(h.liste('hareketler'));

  /// Bakiye ₺ karşılığı (altın hesaplarında gram × altın fiyatı).
  double bakiyeTl(Kayit h) {
    final b = bakiye(h);
    if (h.s('birim') == 'gram') return b * (isletme?.altinGram ?? 0);
    return b;
  }

  double toplamBorc() => hesaplar
      .where((h) => h.s('yon') != 'alacak')
      .fold(0.0, (a, h) => a + bakiyeTl(h).clamp(0, double.infinity).toDouble());

  /// Alacaklar: alacak hesapları + tahsil edilmemiş satışlar.
  double toplamAlacak() {
    final hs = hesaplar
        .where((h) => h.s('yon') == 'alacak')
        .fold(0.0, (a, h) => a + bakiyeTl(h).clamp(0, double.infinity).toDouble());
    final st = satislar.fold(0.0, (a, s) => a + satisHesap(s).kalan(tahsilToplam(s)));
    return hs + st;
  }

  /// Vadesi geçmiş borç toplamı.
  double gecikmisBorc(int simdi) => hesaplar
      .where((h) => h.s('yon') != 'alacak' && h.t('vade') > 0 && h.t('vade') < simdi)
      .fold(0.0, (a, h) => a + bakiyeTl(h).clamp(0, double.infinity).toDouble());

  // ---------------------------------------------------------------------
  // Varlıklar
  // ---------------------------------------------------------------------

  double varlikDegeri(Kayit v) {
    var birim = v.n('birimFiyat');
    if (birim <= 0 && v.s('tur') == 'Altın') birim = isletme?.altinGram ?? 0;
    if (birim <= 0) return v.n('alisTutar');
    return v.n('miktar') * birim;
  }

  double toplamVarlik() => varliklar.fold(0.0, (a, v) => a + varlikDegeri(v));

  // ---------------------------------------------------------------------
  // Maaş
  // ---------------------------------------------------------------------

  /// Bu ayın maaşı yattı mı? (iş yeri için o ay kayıtlı maaş geliri)
  MaasDurum maasDurum(Kayit isyeri, DateTime bugun) {
    final yatti = gelirler.any((g) {
      if (g.s('isyeriId') != isyeri.id || g.s('tur') != 'Maaş') return false;
      final d = DateTime.fromMillisecondsSinceEpoch(g.t('tarih'));
      return d.year == bugun.year && d.month == bugun.month;
    });
    if (yatti) return MaasDurum.yatti;
    final gun = isyeri.t('gun') <= 0 ? 1 : isyeri.t('gun');
    if (bugun.day > gun + 3) return MaasDurum.gecikti;
    return MaasDurum.bekleniyor;
  }

  // ---------------------------------------------------------------------
  // Yıllık kârlılık
  // ---------------------------------------------------------------------

  /// Yılın özeti. Tarım rakamları yalnızca [sahip] (varsayılan: Ben)
  /// hesabına ait tarlalardan; maaş, ev ve diğer gelirler hep "Ben"e aittir.
  YilOzet yilOzet(int yil, {String sahip = ben}) {
    final o = YilOzet(yil);
    for (final s in satislar) {
      if (s.yil != yil) continue;
      final h = satisHesap(s);
      if (s.s('tur') == 'diger') {
        if (sahip == ben) o.digerSatis += h.beklenen;
      } else {
        o.tarimSatis += h.beklenen * (satisPaylari(s)[sahip] ?? 0);
      }
    }
    for (final g in giderler) {
      if (g.yil != yil) continue;
      if (g.s('alan') == 'ev') {
        if (sahip == ben) o.evGider += g.n('tutar');
      } else {
        o.tarimGider += g.n('tutar') * giderSahipPayi(g, sahip);
      }
    }
    // Ayrıca gider girilmemiş kiralık tarla kiraları.
    for (final t in tarlalar) {
      final kp = tarlaYilPaylari(t.id, yil)[sahip] ?? 0;
      if (t.n('kira') <= 0 || kp <= 0) continue;
      final ekili = ekimler.any((e) => e.s('tarlaId') == t.id && e.t('yil') == yil);
      final kiraVar = giderler.any((g) =>
          g.yil == yil &&
          (g.s('kalem') == 'Arazi Kirası' || g.s('kalem') == 'Ecrimisil') &&
          g.l('tarlaIds').contains(t.id));
      if (ekili && !kiraVar) o.tarimGider += t.n('kira') * kp;
    }
    for (final g in gelirler) {
      if (g.yil != yil) continue;
      if (g.s('tur') == 'Destek') {
        o.destek += destekSahipPaylari(g)[sahip] ?? 0;
        continue;
      }
      if (sahip != ben) continue;
      if (g.s('tur') == 'Maaş' || g.s('tur') == 'Prim / İkramiye') {
        o.maas += g.n('tutar');
      } else {
        o.digerGelir += g.n('tutar');
      }
    }
    o.kiraGeliri = kiraGeliri(sahip);
    o.ekiliDekar = ekimler.where((e) => e.t('yil') == yil).fold(
        0.0,
        (a, e) =>
            a + (tarla(e.s('tarlaId'))?.n('dekar') ?? 0) * (ekimPaylari(e)[sahip] ?? 0));
    // Kiralanan pancar kotası bedeli.
    for (final k in kotalar) {
      if (k.t('yil') == yil && kotaKullanan(k) == sahip) o.tarimGider += k.n('kiraBedeli');
    }
    return o;
  }

  /// Kayıtlarda geçen yıllar (yeniden eskiye), en az bu yıl.
  List<int> yillar(int buYil) {
    final s = <int>{buYil};
    for (final e in ekimler) {
      if (e.t('yil') > 0) s.add(e.t('yil'));
    }
    for (final l in [giderler, satislar, gelirler]) {
      for (final x in l) {
        if (x.yil > 0) s.add(x.yil);
      }
    }
    return s.toList()..sort((a, b) => b.compareTo(a));
  }

  /// Aile üyesinin göreceği bütün özet: yıllara göre ve tüm yıllar, tarlalar.
  Map<String, dynamic> aileOzeti(String ad) {
    final yillarSet = <int>{};
    for (final e in ekimler) {
      if ((ekimPaylari(e)[ad] ?? 0) > 0) yillarSet.add(e.t('yil'));
    }
    for (final h in aileHareketleri) {
      if (h.s('kisi') == ad) yillarSet.add(h.yil);
    }
    final tarlaListesi = <Map<String, dynamic>>[];
    for (final t in tarlalar) {
      final p = tarlaPaylari(t.id)[ad] ?? 0;
      final eskiden = ekimler.any((e) => e.s('tarlaId') == t.id && (ekimPaylari(e)[ad] ?? 0) > 0);
      if (p <= 0 && !eskiden) continue;
      tarlaListesi.add({
        'ad': tarlaAdi(t.id),
        'mahalle': t.s('mahalle'),
        'ada': t.s('ada'),
        'parsel': t.s('parsel'),
        'dekar': t.n('dekar'),
        'pay': p,
        'mulkiyet': t.s('mulkiyet'),
        'gecmis': {for (final e in urunGecmisi(t).entries) '${e.key}': e.value},
      });
    }
    return {
      'ad': ad,
      'tumu': sahipOzet(ad).harita(this),
      'yillar': {for (final y in yillarSet) '$y': sahipOzet(ad, yil: y).harita(this)},
      'tarlalar': tarlaListesi,
    };
  }

  // ---------------------------------------------------------------------
  // Gelir-gider defteri ve ev hedefi
  // ---------------------------------------------------------------------

  /// Bütün gelir ve giderler tek listede (yeniden eskiye).
  List<DefterSatir> defter() {
    final l = <DefterSatir>[];
    for (final s in satislar) {
      final h = satisHesap(s);
      final diger = s.s('tur') == 'diger';
      l.add(DefterSatir(
        tarih: s.t('tarih'),
        tur: diger ? 'Diğer satış' : 'Ürün satışı',
        baslik: diger ? s.s('aciklama') : '${s.s('urun')} · ${s.s('alici')}',
        tutar: h.beklenen,
        kayit: s,
        koleksiyon: 'satislar',
      ));
    }
    for (final g in gelirler) {
      final tur = switch (g.s('tur')) {
        'Maaş' || 'Prim / İkramiye' => 'Maaş',
        'Destek' => 'Destek',
        _ => 'Diğer gelir',
      };
      l.add(DefterSatir(
        tarih: g.t('tarih'),
        tur: tur,
        baslik: g.s('tur') == 'Destek'
            ? g.s('destekTuru')
            : (g.s('kaynak').isNotEmpty ? g.s('kaynak') : (bul('isyerleri', g.s('isyeriId'))?.s('ad') ?? g.s('tur'))),
        tutar: g.n('tutar'),
        kayit: g,
        koleksiyon: 'gelirler',
      ));
    }
    for (final g in giderler) {
      final ev = g.s('alan') == 'ev';
      final tur = ev ? (arabaKategorisi(g.s('kalem')) ? 'Araba' : 'Ev') : 'Tarla gideri';
      l.add(DefterSatir(
        tarih: g.t('tarih'),
        tur: tur,
        baslik: [g.s('kalem'), if (g.s('aciklama').isNotEmpty) g.s('aciklama')].join(' · '),
        tutar: -g.n('tutar'),
        kayit: g,
        koleksiyon: 'giderler',
      ));
    }
    for (final h in hesaplar) {
      if (h.s('yon') == 'alacak') continue;
      for (final x in h.liste('hareketler')) {
        if (x['tip'] != 'odeme') continue;
        final t = x['tutar'];
        var v = t is num ? t.toDouble() : 0.0;
        if (h.s('birim') == 'gram') v *= isletme?.altinGram ?? 0;
        final ms = x['t'];
        l.add(DefterSatir(
          tarih: ms is num ? ms.toInt() : 0,
          tur: 'Borç ödemesi',
          baslik: h.s('ad'),
          tutar: -v,
          kayit: h,
          koleksiyon: 'hesaplar',
        ));
      }
    }
    l.sort((a, b) => b.tarih.compareTo(a.tarih));
    return l;
  }

  /// Bir ayın nakit özeti (borç ödemeleri dahil).
  ({double gelir, double gider}) ayOzeti(int yil, int ay) {
    var gelir = 0.0, gider = 0.0;
    for (final d in defter()) {
      final t = DateTime.fromMillisecondsSinceEpoch(d.tarih);
      if (t.year != yil || t.month != ay) continue;
      if (d.tutar >= 0) {
        gelir += d.tutar;
      } else {
        gider += -d.tutar;
      }
    }
    return (gelir: gelir, gider: gider);
  }

  /// Son [n] tam ayın ortalama aylık fazlası (gelir − gider).
  double ortalamaFazla(DateTime bugun, {int n = 3}) {
    var top = 0.0;
    for (var i = 1; i <= n; i++) {
      final a = DateTime(bugun.year, bugun.month - i);
      final o = ayOzeti(a.year, a.month);
      top += o.gelir - o.gider;
    }
    return top / n;
  }

  /// Ev alma hedefi hesabı.
  EvHedefi? evHedefi(DateTime bugun) {
    final h = isletme?.ayarlar['evHedefi'];
    if (h is! Map) return null;
    double n(String k) => h[k] is num ? (h[k] as num).toDouble() : 0;
    final fiyat = n('fiyat');
    if (fiyat <= 0) return null;
    final pesinat = n('pesinatYuzde') <= 0 ? 100.0 : n('pesinatYuzde');
    final hedefMs = n('tarih').toInt();
    final hedef = hedefMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(hedefMs)
        : DateTime(bugun.year + 3, bugun.month);
    final kalanAy = ((hedef.year - bugun.year) * 12 + hedef.month - bugun.month).clamp(1, 600).toInt();
    final biriken = n('biriken') > 0 ? n('biriken') : toplamVarlik();
    return EvHedefi(
      fiyat: fiyat,
      pesinatYuzde: pesinat,
      hedef: hedef,
      kalanAy: kalanAy,
      biriken: biriken,
      ortalamaFazla: ortalamaFazla(bugun),
    );
  }

  // ---------------------------------------------------------------------
  // Ar-Ge: verimlilik ve girdi fiyatları
  // ---------------------------------------------------------------------

  /// Yıl → dekar başı kullanılan miktar (ekili toplam dekara göre).
  Map<int, double> dekarBasiKullanim(String kalem) {
    final miktar = <int, double>{};
    for (final g in giderler) {
      if (g.s('alan') == 'ev' || g.s('kalem') != kalem || g.n('miktar') <= 0) continue;
      miktar[g.yil] = (miktar[g.yil] ?? 0) + g.n('miktar');
    }
    final out = <int, double>{};
    miktar.forEach((yil, m) {
      final dekar = ekimler
          .where((e) => e.t('yil') == yil)
          .fold(0.0, (a, e) => a + (tarla(e.s('tarlaId'))?.n('dekar') ?? 0));
      if (dekar > 0) out[yil] = m / dekar;
    });
    return out;
  }

  /// Yıl → ortalama verim (kg/dekar) bir ürün için.
  Map<int, double> verim(String urun) {
    final kg = <int, double>{}, da = <int, double>{};
    for (final e in ekimler) {
      if (e.s('urun') != urun || e.n('hasatKg') <= 0) continue;
      final d = tarla(e.s('tarlaId'))?.n('dekar') ?? 0;
      if (d <= 0) continue;
      kg[e.t('yil')] = (kg[e.t('yil')] ?? 0) + e.n('hasatKg');
      da[e.t('yil')] = (da[e.t('yil')] ?? 0) + d;
    }
    return {for (final y in kg.keys) y: kg[y]! / da[y]!};
  }

  /// Girdi fiyatları: her kalem + açıklama için son iki alışın birim fiyatı.
  List<GirdiFiyat> girdiFiyatlari() {
    final m = <String, List<Kayit>>{};
    for (final g in giderler) {
      if (g.s('alan') == 'ev' || g.n('miktar') <= 0 || g.n('tutar') <= 0) continue;
      final ac = g.s('aciklama').trim();
      final ad = ac.isEmpty ? g.s('kalem') : '${g.s('kalem')} · $ac';
      m.putIfAbsent(ad, () => []).add(g);
    }
    final out = <GirdiFiyat>[];
    m.forEach((ad, l) {
      l.sort((a, b) => b.t('tarih').compareTo(a.t('tarih')));
      final son = l.first.n('tutar') / l.first.n('miktar');
      final once = l.length > 1 ? l[1].n('tutar') / l[1].n('miktar') : null;
      out.add(GirdiFiyat(ad, l.first.s('kalem'), l.first.s('birim'), son, once,
          l.first.t('tarih')));
    });
    out.sort((a, b) => b.tarih.compareTo(a.tarih));
    return out;
  }
}

// -----------------------------------------------------------------------
// Saf hesap fonksiyonları
// -----------------------------------------------------------------------

/// Kimliklere dekarlarına göre pay verir (toplam 1). Dekar yoksa eşit böler.
Map<String, double> dekaraGorePay(
    List<String> ids, double Function(String id) dekar) {
  if (ids.isEmpty) return const {};
  final toplam = ids.fold(0.0, (a, id) => a + dekar(id));
  if (toplam <= 0) return {for (final id in ids) id: 1 / ids.length};
  return {for (final id in ids) id: dekar(id) / toplam};
}

class Munavebe {
  const Munavebe(this.seviye, this.mesaj);

  /// 0: uygun, 1: dikkat, 2: uygun değil
  final int seviye;
  final String mesaj;
}

Munavebe munavebeKontrol(
    Map<int, String> gecmis, String urun, int yil, int araYil) {
  int? son;
  gecmis.forEach((y, u) {
    if (u == urun && y < yil && (son == null || y > son!)) son = y;
  });
  final s = son;
  if (s != null && yil - s < araYil) {
    return Munavebe(
        2,
        '$urun en son $s yılında ekildi. En erken ${s + araYil} '
        'yılında tekrar ekilmeli.');
  }
  final onceki = gecmis[yil - 1];
  final ua = urunBul(urun)?.aile ?? '';
  if (onceki != null && onceki.isNotEmpty) {
    final oa = urunBul(onceki)?.aile ?? '';
    if (oa == 'tahıl' && ua == 'baklagil') {
      return const Munavebe(0, 'İyi münavebe: tahıldan sonra baklagil toprağı dinlendirir.');
    }
    if (oa.isNotEmpty && oa == ua && ua != 'yem' && onceki != urun) {
      return Munavebe(1, 'Geçen yıl da aynı aileden $onceki vardı ($ua).');
    }
    if (onceki == urun) {
      return Munavebe(1, 'Geçen yıl da $urun ekildi.');
    }
  }
  return const Munavebe(0, 'Münavebeye uygun.');
}

class Oneri {
  const Oneri(this.urun, this.munavebe, this.dekarKar);
  final String urun;
  final Munavebe munavebe;
  final double? dekarKar;
}

class KalemToplam {
  KalemToplam(this.birim);
  final String birim;
  double tutar = 0;
  double miktar = 0;
}

class EkimOzet {
  EkimOzet({
    required this.ekim,
    required this.dekar,
    required this.kalemler,
    required this.hasatKg,
    required this.satisNet,
    required this.satisKg,
    this.destek = 0,
  });

  final Kayit ekim;
  final double destek;
  final double dekar;
  final Map<String, KalemToplam> kalemler;
  final double hasatKg;
  final double satisNet;
  final double satisKg;

  double get toplam => kalemler.values.fold(0.0, (a, k) => a + k.tutar);
  double get dekarMaliyet => dekar > 0 ? toplam / dekar : 0;
  double get kgMaliyet => hasatKg > 0 ? toplam / hasatKg : 0;
  double get verim => dekar > 0 ? hasatKg / dekar : 0;

  /// Satılan kısmın ortalama fiyatıyla tüm hasadın değeri.
  double get gelirTahmini {
    if (satisKg <= 0) return satisNet;
    final kalanKg = (hasatKg - satisKg).clamp(0, double.infinity).toDouble();
    return satisNet + kalanKg * (satisNet / satisKg);
  }

  double get kar => gelirTahmini + destek - toplam;
  double get dekarKar => dekar > 0 ? kar / dekar : 0;
}

class UrunOzet {
  UrunOzet(this.urun);
  final String urun;
  int ekimSayisi = 0;
  double dekar = 0, maliyet = 0, hasatKg = 0, satisNet = 0, satisKg = 0;
  double destek = 0;

  double get dekarMaliyet => dekar > 0 ? maliyet / dekar : 0;
  double get kgMaliyet => hasatKg > 0 ? maliyet / hasatKg : 0;
  double get verim => dekar > 0 ? hasatKg / dekar : 0;
  double get ortFiyat => satisKg > 0 ? satisNet / satisKg : 0;
  double get dekarKar => dekar > 0 && satisKg > 0
      ? (verim * ortFiyat) + destek / dekar - dekarMaliyet
      : 0;
}

class SatisHesap {
  const SatisHesap({
    required this.tutar,
    required this.stopaj,
    required this.tescil,
    required this.sgk,
    required this.nakliye,
  });

  final double tutar, stopaj, tescil, sgk, nakliye;

  double get kesinti => stopaj + tescil + sgk;

  /// Alıcıdan beklenen ödeme (kesintiler düşülmüş).
  double get beklenen => tutar - kesinti;

  /// Nakliye de düşülünce cebe kalan.
  double get net => beklenen - nakliye;

  double kalan(double tahsil) =>
      (beklenen - tahsil).clamp(0, double.infinity).toDouble();
}

SatisHesap satisHesapla({
  required double kg,
  required double fiyat,
  double stopajYuzde = 0,
  double tescilBinde = 0,
  double sgkYuzde = 0,
  double nakliye = 0,
  double tutarElle = 0,
}) {
  final tutar = kg > 0 && fiyat > 0 ? kg * fiyat : tutarElle;
  return SatisHesap(
    tutar: tutar,
    stopaj: tutar * stopajYuzde / 100,
    tescil: tutar * tescilBinde / 1000,
    sgk: tutar * sgkYuzde / 100,
    nakliye: nakliye,
  );
}

/// Hareketlerden bakiye: 'artis' borcu/alacağı artırır, 'odeme' azaltır.
double hesapBakiye(List<Map<String, dynamic>> hareketler) {
  var b = 0.0;
  for (final h in hareketler) {
    final t = h['tutar'];
    final v = t is num ? t.toDouble() : 0.0;
    b += h['tip'] == 'odeme' ? -v : v;
  }
  return b;
}

class DepoSatir {
  DepoSatir(this.urun);
  final String urun;
  double giren = 0, cikan = 0;
  double enIyiFiyat = 0;
  String enIyiYer = '';
  double get kalan => (giren - cikan).clamp(0, double.infinity).toDouble();
  double get deger => kalan * enIyiFiyat;
}

enum MaasDurum { yatti, bekleniyor, gecikti }

class YilOzet {
  YilOzet(this.yil);
  final int yil;
  double tarimSatis = 0, digerSatis = 0, tarimGider = 0, evGider = 0;
  double maas = 0, digerGelir = 0, ekiliDekar = 0, kiraGeliri = 0, destek = 0;

  double get tarimKar => tarimSatis + kiraGeliri + destek - tarimGider;
  double get dekarKar => ekiliDekar > 0 ? tarimKar / ekiliDekar : 0;
  double get toplamGelir =>
      tarimSatis + kiraGeliri + destek + digerSatis + maas + digerGelir;
  double get toplamGider => tarimGider + evGider;
  double get net => toplamGelir - toplamGider;
}

class GirdiFiyat {
  const GirdiFiyat(
      this.ad, this.kalem, this.birim, this.son, this.once, this.tarih);
  final String ad, kalem, birim;
  final double son;
  final double? once;
  final int tarih;

  double? get degisim {
    final o = once;
    if (o == null || o <= 0) return null;
    return (son - o) / o * 100;
  }
}

class SahipOzet {
  SahipOzet(this.sahip);
  final String sahip;
  int tarlaSayisi = 0;
  double dekar = 0, hasatKg = 0, satis = 0, tahsil = 0, satisKg = 0;
  final ekimler = <EkimOzet>[];

  /// [ekimler] ile aynı sırada, kişinin o ekimdeki payı (0..1).
  final paylar = <double>[];
  final kalemler = <String, KalemToplam>{};

  double kiraGeliri = 0, destek = 0;

  /// Desteklerden doğan aile içi alacak/borç (bkz. hesaplasma).
  double destekDuzeltme = 0;

  /// Aile hareketleri: kişinin bana verdiği / benim kişiye verdiğim.
  double onunVerdigi = 0, benimVerdigim = 0;

  double get masraf => kalemler.values.fold(0.0, (a, k) => a + k.tutar);
  double get kar => satis + kiraGeliri + destek - masraf;

  /// Hesaplaşma: + ise bende kişiye ait para var (ona ödenecek);
  /// − ise kişi bana borçlu. Satıştan tahsil edilen − yaptığım masraf ±
  /// yanlış hesaba yatan destekler.
  double get hesaplasma =>
      tahsil - masraf + destekDuzeltme + onunVerdigi - benimVerdigim;

  /// Aile üyesinin ekranı için özet (Firestore'a yazılır).
  Map<String, dynamic> harita(Veriler v) => {
        'masraf': masraf,
        'satis': satis,
        'tahsil': tahsil,
        'destek': destek,
        'kiraGeliri': kiraGeliri,
        'kar': kar,
        'hasatKg': hasatKg,
        'satisKg': satisKg,
        'dekar': dekar,
        'tarlaSayisi': tarlaSayisi,
        'destekDuzeltme': destekDuzeltme,
        'onunVerdigi': onunVerdigi,
        'benimVerdigim': benimVerdigim,
        'hesaplasma': hesaplasma,
        'kalemler': {
          for (final e in kalemler.entries)
            e.key: {'tutar': e.value.tutar, 'miktar': e.value.miktar, 'birim': e.value.birim}
        },
        'ekimler': [
          for (var i = 0; i < ekimler.length; i++)
            {
              'yil': ekimler[i].ekim.t('yil'),
              'urun': ekimler[i].ekim.s('urun'),
              'tarla': v.tarlaAdi(ekimler[i].ekim.s('tarlaId')),
              'dekar': ekimler[i].dekar * paylar[i],
              'pay': paylar[i],
              'masraf': ekimler[i].toplam * paylar[i],
              'hasatKg': ekimler[i].hasatKg * paylar[i],
              'kar': ekimler[i].kar * paylar[i],
              'durum': ekimler[i].ekim.s('durum'),
            }
        ],
      };
}

/// Satışa yapılan ödemelerin toplamı (avans, ürün bedeli...).
double tahsilToplam(Kayit s) {
  var t = s.n('tahsil');
  for (final o in s.liste('tahsilatlar')) {
    final v = o['tutar'];
    if (v is num) t += v.toDouble();
  }
  return t;
}

class DefterSatir {
  const DefterSatir({
    required this.tarih,
    required this.tur,
    required this.baslik,
    required this.tutar,
    required this.kayit,
    required this.koleksiyon,
  });
  final int tarih;
  final String tur, baslik, koleksiyon;
  final double tutar; // + gelir, − gider
  final Kayit kayit;
}

class EvHedefi {
  const EvHedefi({
    required this.fiyat,
    required this.pesinatYuzde,
    required this.hedef,
    required this.kalanAy,
    required this.biriken,
    required this.ortalamaFazla,
  });
  final double fiyat, pesinatYuzde, biriken, ortalamaFazla;
  final DateTime hedef;
  final int kalanAy;

  double get gereken => fiyat * pesinatYuzde / 100;
  double get eksik => (gereken - biriken).clamp(0, double.infinity).toDouble();
  double get aylik => eksik / kalanAy;
  double get kredi => fiyat - gereken;
  double get oran => gereken > 0 ? (biriken / gereken).clamp(0, 1).toDouble() : 0;

  /// Ortalama fazla bu hızla kaç ayda hedefe ulaştırır (yetmiyorsa null).
  int? get tahminiAy => ortalamaFazla > 0 ? (eksik / ortalamaFazla).ceil() : null;
  bool get yetisir => ortalamaFazla >= aylik;
}
