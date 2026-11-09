import 'package:flutter/material.dart';

import '../bicim.dart';
import '../hesap.dart';
import '../modeller.dart';
import '../sabitler.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'belge_arsiv.dart';
import 'belge_okut.dart';
import 'form.dart';
import 'kabuk.dart';
import 'satislar.dart';
import 'tarlalar.dart';

double _n(Object? v) => v is num ? v.toDouble() : 0;

/// Tarla ya da ev gideri, makine işçiliği, yevmiye.
Future<void> giderFormu(BuildContext context, Durum durum,
    {Kayit? gider,
    bool ev = false,
    bool iscilik = false,
    String? tarlaId,
    Map<String, dynamic>? hazir}) {
  final v = durum.v;
  final evMi = gider != null ? gider.s('alan') == 'ev' : ev;
  final simdi = DateTime.now();
  final yapanlar = <String>{
    for (final g in v.giderler) ...[
      if (g.s('yapan').isNotEmpty) g.s('yapan'),
      if (g.s('tedarikci').isNotEmpty) g.s('tedarikci'),
    ]
  }.toList();
  final sayacAdlari = {for (final s in v.sayaclar) s.s('ad'): s.id};

  if (evMi) {
    return formAc(
      context,
      baslik: gider == null ? 'Ev Gideri' : 'Ev Giderini Düzenle',
      v: v,
      baslangic: {
        'tarih': simdi.millisecondsSinceEpoch,
        'kalem': 'Market',
        ...?gider?.d,
      },
      alanlar: const [
        Alan('kalem', 'Kategori', tip: AlanTip.secim, secenekler: evKategorileri),
        Alan('tutar', 'Tutar', tip: AlanTip.sayi, birim: '₺', zorunlu: true),
        Alan('tarih', 'Tarih', tip: AlanTip.tarih),
        Alan('aciklama', 'Açıklama'),
        Alan('sabit', 'Her ay tekrarlanan gider',
            tip: AlanTip.anahtar, ipucu: 'Kira, fatura gibi. Ev Bütçesi ekranında aylık hatırlatılır.'),
      ],
      onKaydet: (d) async {
        d['alan'] = 'ev';
        d['yil'] = DateTime.fromMillisecondsSinceEpoch(_n(d['tarih']).toInt()).year;
        await durum.kaydet('giderler', d, id: gider?.id);
      },
      onSil: gider == null ? null : () => durum.sil('giderler', gider.id),
    );
  }

  final bas = <String, dynamic>{
    'tarih': simdi.millisecondsSinceEpoch,
    'yil': simdi.year,
    'kalem': iscilik ? 'Makine İşçiliği' : 'Gübre',
    'birim': iscilik ? 'dekar' : 'kg',
    'odendi': true,
    'tarlaIds': tarlaId == null ? <String>[] : [tarlaId],
    ...?gider?.d,
    ...?hazir,
  };
  if (gider != null && gider.s('sayacId').isNotEmpty) {
    for (final e in sayacAdlari.entries) {
      if (e.value == gider.s('sayacId')) bas['sayac'] = e.key;
    }
  }
  bool k(Map<String, dynamic> d, String kalem) => d['kalem'] == kalem;
  bool makine(Map<String, dynamic> d) => k(d, 'Makine İşçiliği');
  bool yevmiye(Map<String, dynamic> d) => k(d, 'İşçilik (Yevmiye)');
  bool sayacli(Map<String, dynamic> d) =>
      k(d, 'Elektrik') && (d['sayac'] ?? '').toString().isNotEmpty;
  Kayit? secilenSayac(Map<String, dynamic> d) =>
      sayacli(d) ? v.bul('sayaclar', sayacAdlari[d['sayac']] ?? '') : null;
  bool ortakSayac(Map<String, dynamic> d) => secilenSayac(d)?.b('ortak') ?? false;
  double benimKwh(Map<String, dynamic> d) {
    double fark(String a, String b) {
      final x = _n(d[b]) - _n(d[a]);
      return x > 0 ? x : 0;
    }
    return fark('ilkEndeks', 'sonEndeks') + fark('ilkEndeks2', 'sonEndeks2');
  }
  double kwhFiyati(Map<String, dynamic> d) =>
      _n(d['faturaKwh']) > 0 ? _n(d['faturaTutar']) / _n(d['faturaKwh']) : 0;

  return formAc(
    context,
    baslik: gider == null ? (iscilik ? 'İşçilik / Makine' : 'Tarla Gideri') : 'Gideri Düzenle',
    v: v,
    baslangic: bas,
    alanlar: [
      Alan('kalem', 'Gider kalemi', tip: AlanTip.secim,
          secenekler: giderKalemleri.keys.toList()),
      Alan('isTuru', 'Yapılan iş', tip: AlanTip.secim,
          secenekler: makineIsleri, gorunur: makine),
      Alan('yapan', 'İşi yapan', oneriler: yapanlar,
          gorunur: (d) => makine(d) || yevmiye(d),
          ipucu: 'Kişi ya da firma adı'),
      Alan('aciklama', 'Ürün / açıklama',
          ipucu: 'Örn. DAP 18-46, Üre, sertifikalı tohum',
          gorunur: (d) => !makine(d) && !yevmiye(d)),
      Alan('kisi', 'Kaç kişi', tip: AlanTip.sayi, gorunur: yevmiye),
      Alan('gun', 'Kaç gün', tip: AlanTip.sayi, gorunur: yevmiye),
      Alan('birim', 'Birim', tip: AlanTip.secim,
          secenekler: makineBirimleri, gorunur: makine),
      Alan('miktar', 'Miktar', tip: AlanTip.sayi,
          gorunur: (d) => !yevmiye(d),
          birim: null,
          aciklama: 'Dekar başı kullanım için girin (kg, lt, kWh, dekar...).'),
      Alan('birimFiyat', 'Birim fiyat', tip: AlanTip.sayi, birim: '₺',
          aciklama: 'Yevmiye, dekar ücreti ya da kg fiyatı. Toplam kendiliğinden hesaplanır.'),
      const Alan('tutar', 'Toplam tutar', tip: AlanTip.sayi, birim: '₺', zorunlu: true),
      const Alan('tarih', 'Tarih', tip: AlanTip.tarih),
      const Alan('yil', 'Hangi sezonun gideri', tip: AlanTip.yil),
      if (sayacAdlari.isNotEmpty)
        Alan('sayac', 'Elektrik sayacı', tip: AlanTip.secim,
            secenekler: ['', ...sayacAdlari.keys],
            gorunur: (d) => k(d, 'Elektrik'),
            aciklama: 'Seçerseniz fatura o sayacın suladığı ekili tarlalara dekara göre bölünür.'),
      Alan('faturaKwh', 'Faturadaki toplam tüketim', tip: AlanTip.sayi, birim: 'kWh',
          gorunur: ortakSayac,
          aciklama: 'Kuyu ortak: fatura, sizin sayaçta okuduğunuz kWh kadar size yazılır.'),
      Alan('faturaTutar', 'Faturanın toplam tutarı', tip: AlanTip.sayi, birim: '₺',
          gorunur: ortakSayac),
      Alan('ilkEndeks', 'Sulamaya başladığımda sayaç', tip: AlanTip.sayi, birim: 'kWh',
          gorunur: ortakSayac),
      Alan('sonEndeks', 'Sulamayı bitirdiğimde sayaç', tip: AlanTip.sayi, birim: 'kWh',
          gorunur: ortakSayac),
      Alan('ilkEndeks2', '2. dönem başlangıç (varsa)', tip: AlanTip.sayi, birim: 'kWh',
          gorunur: ortakSayac),
      Alan('sonEndeks2', '2. dönem bitiş (varsa)', tip: AlanTip.sayi, birim: 'kWh',
          gorunur: ortakSayac),
      Alan('odeme', 'Faturayı kim ödedi', tip: AlanTip.secim,
          secenekler: const ['Tamamını ben ödedim', 'Sadece kendi payımı ödedim', 'Henüz ödenmedi'],
          gorunur: ortakSayac),
      Alan('tarlaIds', 'Hangi tarlalar', tip: AlanTip.tarlalar,
          gorunur: (d) => !sayacli(d),
          aciklama: 'Birden fazla seçerseniz tutar ve miktar dekarlarına göre bölünür. '
              'Ziraat odası, bekçi gibi ücretler için "Hepsini seç".'),
      Alan('tedarikci', 'Nereden alındı / kime ödendi',
          oneriler: yapanlar, gorunur: (d) => !makine(d) && !yevmiye(d)),
      const Alan('odendi', 'Ödendi', tip: AlanTip.anahtar,
          ipucu: 'Kapatırsanız tutar, işi yapan / satıcı adına Borçlarım\'a yazılır.'),
    ],
    degisince: (key, d) {
      if (key == 'kalem') {
        final kalem = (d['kalem'] ?? '').toString();
        d['birim'] = giderKalemleri[kalem] ?? 'adet';
      }
      if (yevmiye(d) && (key == 'kisi' || key == 'gun')) {
        final m = _n(d['kisi']) * _n(d['gun']);
        if (m > 0) d['miktar'] = m;
      }
      if (ortakSayac(d) &&
          ['faturaKwh', 'faturaTutar', 'ilkEndeks', 'sonEndeks', 'ilkEndeks2', 'sonEndeks2', 'sayac']
              .contains(key)) {
        final kwh = benimKwh(d);
        final f = kwhFiyati(d);
        d['miktar'] = kwh;
        d['birim'] = 'kWh';
        if (kwh > 0 && f > 0) d['tutar'] = double.parse((kwh * f).toStringAsFixed(2));
        return;
      }
      if (['miktar', 'birimFiyat', 'kisi', 'gun'].contains(key)) {
        final miktar = yevmiye(d) ? _n(d['kisi']) * _n(d['gun']) : _n(d['miktar']);
        final bf = _n(d['birimFiyat']);
        if (miktar > 0 && bf > 0) d['tutar'] = double.parse((miktar * bf).toStringAsFixed(2));
      }
    },
    ozet: (d) {
      final tutar = _n(d['tutar']);
      final miktar = yevmiye(d) ? _n(d['kisi']) * _n(d['gun']) : _n(d['miktar']);
      List<String> ids;
      if (sayacli(d)) {
        final s = v.bul('sayaclar', sayacAdlari[d['sayac']] ?? '');
        ids = s?.l('tarlaIds') ?? const [];
      } else {
        ids = d['tarlaIds'] is List
            ? [for (final x in d['tarlaIds'] as List) x.toString()]
            : const [];
      }
      final dekar = ids.fold(0.0, (a, id) => a + (v.tarla(id)?.n('dekar') ?? 0));
      final kisiler = <String, double>{};
      for (final id in ids) {
        final s = v.tarlaSahibi(id);
        kisiler[s] = (kisiler[s] ?? 0) + (v.tarla(id)?.n('dekar') ?? 0);
      }
      final ortak = ortakSayac(d);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ortak) ...[
            Satir('Sizin kullanımınız', '${sayi(benimKwh(d))} kWh'),
            Satir('kWh fiyatı (fatura)', kwhFiyati(d) > 0 ? tl(kwhFiyati(d)) : '-'),
            Satir('Ortakların payı', tl((_n(d['faturaTutar']) - tutar).clamp(0, double.infinity))),
            const Divider(height: 14),
          ],
          Satir(ortak ? 'Sizin payınız' : 'Toplam', tl(tutar), kalin: true),
          if (dekar > 0) ...[
            Satir('Seçili alan', '${sayi(dekar)} da'),
            Satir('Dekar başı tutar', tl(tutar / dekar), renk: Renk.altin),
            if (miktar > 0)
              Satir('Dekar başı kullanım',
                  '${sayi(miktar / dekar)} ${(d['birim'] ?? '').toString()}'),
            if (kisiler.length > 1)
              for (final e in kisiler.entries)
                Satir('${e.key} payı', tl(tutar * e.value / dekar)),
          ] else
            const Text('Tarla seçilmezse genel işletme gideri sayılır.',
                style: yaziSoluk),
        ],
      );
    },
    onKaydet: (d) async {
      final kalem = (d['kalem'] ?? '').toString();
      if (yevmiye(d)) d['miktar'] = _n(d['kisi']) * _n(d['gun']);
      final sayacAd = (d.remove('sayac') ?? '').toString();
      if (kalem == 'Elektrik' && sayacAd.isNotEmpty) {
        d['sayacId'] = sayacAdlari[sayacAd] ?? '';
      } else {
        d['sayacId'] = '';
      }
      d['alan'] = 'tarla';
      final yeni = gider == null;
      final sayac = v.bul('sayaclar', (d['sayacId'] ?? '').toString());
      final ortakFatura = kalem == 'Elektrik' && (sayac?.b('ortak') ?? false);
      if (ortakFatura) {
        d['miktar'] = benimKwh(d);
        d['birim'] = 'kWh';
        if ((d['tedarikci'] ?? '').toString().isEmpty) d['tedarikci'] = sayac?.s('kurum') ?? 'MEDAŞ';
        d['odendi'] = d['odeme'] != 'Henüz ödenmedi';
      }
      await durum.kaydet('giderler', d, id: gider?.id);
      if (yeni && ortakFatura && d['odeme'] == 'Tamamını ben ödedim') {
        final digerPay = _n(d['faturaTutar']) - _n(d['tutar']);
        if (digerPay > 0) {
          await Veri.borcaYaz(durum.iid, v,
              kime: sayac!.s('ortaklar').isNotEmpty
                  ? sayac.s('ortaklar')
                  : 'Kuyu ortakları (${sayac.s('ad')})',
              tur: 'Kişi',
              tutar: digerPay,
              aciklama: 'Elektrik faturası ortak payı',
              tarih: _n(d['tarih']).toInt(),
              uid: durum.uid,
              yon: 'alacak');
        }
      }
      if (yeni && d['odendi'] != true) {
        final kime = (makine(d) || yevmiye(d))
            ? (d['yapan'] ?? '').toString()
            : (d['tedarikci'] ?? '').toString();
        if (kime.trim().isEmpty) return;
        final is_ = makine(d) ? (d['isTuru'] ?? 'Makine işi') : kalem;
        await Veri.borcaYaz(durum.iid, v,
            kime: kime,
            tur: (makine(d) || yevmiye(d)) ? 'Kişi' : 'Bayi',
            tutar: _n(d['tutar']),
            aciklama: '$is_ ${(d['aciklama'] ?? '').toString()}'.trim(),
            tarih: _n(d['tarih']).toInt(),
            uid: durum.uid);
      }
    },
    onSil: gider == null ? null : () => durum.sil('giderler', gider.id),
  );
}

Future<void> sayacFormu(BuildContext context, Durum durum, {Kayit? sayac}) {
  return formAc(
    context,
    baslik: sayac == null ? 'Elektrik Sayacı' : 'Sayacı Düzenle',
    v: durum.v,
    baslangic: {'kurum': 'MEDAŞ', ...?sayac?.d},
    alanlar: [
      const Alan('ad', 'Sayaç adı', ipucu: 'Örn. Aşağı kuyu', zorunlu: true),
      const Alan('aboneNo', 'Abone / tesisat no',
          aciklama: 'Faturayı okuttuğunuzda bu numarayla sayaç kendiliğinden bulunur.'),
      const Alan('kurum', 'Elektrik şirketi', oneriler: ['MEDAŞ']),
      const Alan('tarlaIds', 'Suladığınız tarlalar', tip: AlanTip.tarlalar, zorunlu: true),
      const Alan('ortak', 'Kuyu başkalarıyla ortak', tip: AlanTip.anahtar,
          ipucu: 'Açarsanız faturalar, sayaçta okuduğunuz başlangıç-bitiş kWh farkına göre size yazılır.'),
      Alan('ortaklar', 'Ortaklar', gorunur: (d) => d['ortak'] == true, ipucu: 'Örn. Hasan, Mehmet'),
    ],
    onKaydet: (d) => durum.kaydet('sayaclar', d, id: sayac?.id),
    onSil: sayac == null ? null : () => durum.sil('sayaclar', sayac.id),
  );
}

class UretimSayfasi extends StatefulWidget {
  const UretimSayfasi({super.key, required this.durum});
  final Durum durum;

  @override
  State<UretimSayfasi> createState() => _UretimSayfasiState();
}

class _UretimSayfasiState extends State<UretimSayfasi> {
  int _yil = DateTime.now().year;
  String _kisi = 'Hepsi';
  String _sekme = 'Ekimler';
  String _ara = '';

  Durum get durum => widget.durum;

  @override
  Widget build(BuildContext context) {
    return Sayfa(
      baslik: 'Üretim Merkezi',
      durum: durum,
      fab: ekleButonu('Maliyet Ekle', () => giderFormu(context, durum)),
      builder: (context, v) {
        final yillar = v.yillar(DateTime.now().year);
        final kisiler = ['Hepsi', ...v.sahipler()];
        final ekimler = v.ekimler
            .where((e) => e.t('yil') == _yil)
            .where((e) => _kisi == 'Hepsi' || (v.ekimPaylari(e)[_kisi] ?? 0) > 0)
            .map(v.ekimOzet)
            .toList()
          ..sort((a, b) => b.dekar.compareTo(a.dekar));
        final dekar = ekimler.fold(0.0, (a, o) => a + o.dekar);
        final maliyet = ekimler.fold(0.0, (a, o) => a + o.toplam);
        return [
          Panel(
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('🚜', style: TextStyle(fontSize: 44)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$_yil Sezonu', style: yaziKalin),
                          Text('${ekimler.length} ekim · ${sayi(dekar)} dekar',
                              style: yaziSoluk),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: Buton(
                            yazi: 'Yeni Ekim',
                            renk: ButonRenk.yesil,
                            onTap: () => ekimFormu(context, durum))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Buton(
                            yazi: 'İşçilik / Makine',
                            onTap: () => giderFormu(context, durum, iscilik: true))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                        child: Buton(
                            yazi: 'Gider Ekle',
                            renk: ButonRenk.mor,
                            onTap: () => giderFormu(context, durum))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Buton(
                            yazi: 'Fiş / Fatura Çek',
                            ikon: Icons.photo_camera,
                            renk: ButonRenk.turuncu,
                            onTap: () => git(context, BelgeOkut(durum: durum)))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: BilgiKutu(baslik: 'Toplam maliyet', deger: tl0(maliyet))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: BilgiKutu(
                            baslik: 'Dekar başı',
                            deger: dekar > 0 ? tl0(maliyet / dekar) : '-',
                            renk: Renk.altin)),
                  ],
                ),
              ],
            ),
          ),
          SecimSatiri(
            secenekler: [for (final y in yillar) '$y'],
            secili: '$_yil',
            onSec: (s) => setState(() => _yil = int.parse(s)),
          ),
          const SizedBox(height: 6),
          SecimSatiri(
            secenekler: kisiler,
            secili: kisiler.contains(_kisi) ? _kisi : 'Hepsi',
            onSec: (s) => setState(() => _kisi = s),
          ),
          const SizedBox(height: 6),
          SecimSatiri(
            secenekler: const ['Ekimler', 'Ürünler', 'Giderler'],
            secili: _sekme,
            onSec: (s) => setState(() => _sekme = s),
          ),
          const SizedBox(height: 10),
          if (_sekme == 'Ekimler') ...[
            if (ekimler.isEmpty)
              BosDurum(
                simge: '🌱',
                yazi: '$_yil için ekim yok. Ekimi girin, giderler tarlaya göre kendiliğinden dağıtılır.',
                butonYazi: 'Ekim Gir',
                onTap: () => ekimFormu(context, durum),
              ),
            for (final o in ekimler) _ekimKarti(context, v, o),
          ],
          if (_sekme == 'Ürünler') ..._urunler(v),
          if (_sekme == 'Giderler') ..._giderler(context, v),
        ];
      },
    );
  }

  Widget _ekimKarti(BuildContext context, Veriler v, EkimOzet o) {
    final e = o.ekim;
    final hasat = e.s('durum') == 'Hasat edildi';
    final kalemler = o.kalemler.entries.toList()
      ..sort((a, b) => b.value.tutar.compareTo(a.value.tutar));
    return Panel(
      padding: const EdgeInsets.all(14),
      onTap: () => git(context, EkimDetay(durum: durum, ekimId: e.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${e.s('urun')} · ${v.tarlaAdi(e.s('tarlaId'))}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Renk.yazi, fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              Text('${sayi(o.dekar)} da', style: const TextStyle(color: Renk.yazi)),
            ],
          ),
          const Divider(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Renk.zeminAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Renk.yesil, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(urunSimge(e.s('urun')), style: const TextStyle(fontSize: 34)),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: 70,
                    child: Text(v.ekimSahipYazisi(e),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Renk.soluk, fontSize: 11.5)),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Satir('Toplam maliyet', tl0(o.toplam)),
                    Satir('Dekar başı', tl0(o.dekarMaliyet), renk: Renk.altin),
                    if (hasat && o.hasatKg > 0) ...[
                      Satir('Verim', '${sayi(o.verim)} kg/da'),
                      Satir('Kg maliyeti', tl(o.kgMaliyet)),
                    ],
                    if (o.destek > 0) Satir('Destek', tl0(o.destek), renk: Renk.turkuaz),
                    if (o.satisNet > 0 || o.destek > 0)
                      Satir('Kâr', tl0(o.kar),
                          kalin: true, renk: o.kar >= 0 ? Renk.yesil : Renk.kirmizi),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Etiket(e.s('durum').isEmpty ? 'Ekildi' : e.s('durum'),
                  renk: hasat ? Renk.yesil : Renk.mavi),
              for (final k in kalemler.take(6))
                Etiket('${kisaTl(k.value.tutar)}',
                    renk: Renk.kartAcik, simge: giderSimge[k.key] ?? '📦'),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _urunler(Veriler v) {
    final a = araMetni(_ara);
    final l = v
        .urunOzetleri(yil: _yil, sahip: _kisi == 'Hepsi' ? null : _kisi)
        .where((u) => a.isEmpty || araMetni(u.urun).contains(a))
        .toList();
    return [
      TextField(
        decoration: const InputDecoration(hintText: 'Ara...', prefixIcon: Icon(Icons.search)),
        onChanged: (s) => setState(() => _ara = s),
      ),
      const SizedBox(height: 10),
      if (l.isEmpty) const BosDurum(simge: '🌾', yazi: 'Bu yıl için ürün yok.'),
      for (final u in l)
        Panel(
          baslik: '${urunSimge(u.urun)} ${u.urun}',
          eylem: Text('${u.ekimSayisi} tarla · ${sayi(u.dekar)} da', style: yaziSoluk),
          child: Column(
            children: [
              Satir('Toplam maliyet', tl0(u.maliyet)),
              Satir('Dekar başı maliyet', tl0(u.dekarMaliyet), renk: Renk.altin),
              if (u.hasatKg > 0) ...[
                Satir('Hasat', '${sayi(u.hasatKg)} kg'),
                Satir('Verim', '${sayi(u.verim)} kg/da'),
                Satir('Kg maliyeti', tl(u.kgMaliyet)),
              ],
              if (u.satisKg > 0) ...[
                Satir('Ort. satış fiyatı', '${tl(u.ortFiyat)}/kg'),
                Satir('Dekar başı kâr', tl0(u.dekarKar),
                    kalin: true, renk: u.dekarKar >= 0 ? Renk.yesil : Renk.kirmizi),
              ],
            ],
          ),
        ),
    ];
  }

  List<Widget> _giderler(BuildContext context, Veriler v) {
    final l = v.giderler
        .where((g) => g.s('alan') != 'ev' && g.yil == _yil)
        .where((g) => _kisi == 'Hepsi' || v.giderSahipPayi(g, _kisi) > 0)
        .toList()
      ..sort((a, b) => b.t('tarih').compareTo(a.t('tarih')));
    final toplam = <String, double>{};
    for (final g in l) {
      final pay = _kisi == 'Hepsi' ? 1.0 : v.giderSahipPayi(g, _kisi);
      toplam[g.s('kalem')] = (toplam[g.s('kalem')] ?? 0) + g.n('tutar') * pay;
    }
    final sirali = toplam.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [
      if (sirali.isNotEmpty)
        Panel(
          baslik: 'Kalemlere göre',
          child: Column(
            children: [
              for (final e in sirali)
                Satir('${giderSimge[e.key] ?? '📦'} ${e.key}', tl0(e.value)),
            ],
          ),
        ),
      Panel(
        baslik: 'Elektrik sayaçları',
        eylem: TextButton(
            onPressed: () => sayacFormu(context, durum), child: const Text('+ Ekle')),
        child: v.sayaclar.isEmpty
            ? const Text(
                'Kuyu/pompa sayaçlarını ekleyin; elektrik faturası suladığı tarlalara dekara göre bölünür.',
                style: yaziSoluk)
            : Column(
                children: [
                  for (final s in v.sayaclar)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Text('⚡', style: TextStyle(fontSize: 24)),
                      title: Text(s.s('ad'), style: const TextStyle(color: Renk.yazi)),
                      subtitle: Text(
                          s.l('tarlaIds').map(v.tarlaAdi).join(', '),
                          style: yaziSoluk),
                      onTap: () => sayacFormu(context, durum, sayac: s),
                    ),
                ],
              ),
      ),
      if (l.isEmpty) const BosDurum(simge: '🧾', yazi: 'Bu yıl gider yok.'),
      for (final g in l)
        Panel(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          onTap: () => giderFormu(context, durum, gider: g),
          child: Row(
            children: [
              Text(giderSimge[g.s('kalem')] ?? '📦', style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        [
                          g.s('kalem'),
                          if (g.s('isTuru').isNotEmpty) g.s('isTuru'),
                          if (g.s('aciklama').isNotEmpty) g.s('aciklama'),
                        ].join(' · '),
                        style: const TextStyle(color: Renk.yazi, fontWeight: FontWeight.w700)),
                    Text(
                        [
                          tarih(g.t('tarih')),
                          if (g.n('miktar') > 0) '${sayi(g.n('miktar'))} ${g.s('birim')}',
                          if (g.s('sayacId').isNotEmpty)
                            '⚡ ${v.bul('sayaclar', g.s('sayacId'))?.s('ad') ?? ''}'
                          else if (g.l('tarlaIds').isNotEmpty)
                            '${g.l('tarlaIds').length} tarla',
                          if (g.s('yapan').isNotEmpty) g.s('yapan'),
                          if (g.d['odendi'] == false) 'ödenmedi',
                        ].join(' · '),
                        style: yaziSoluk),
                  ],
                ),
              ),
              if (g.s('belgeId').isNotEmpty || g.s('odemeBelgeId').isNotEmpty)
                IconButton(
                  tooltip: 'Belgeyi aç',
                  icon: const Icon(Icons.attach_file, color: Renk.altin),
                  onPressed: () => belgeGoster(context, durum,
                      g.s('belgeId').isNotEmpty ? g.s('belgeId') : g.s('odemeBelgeId')),
                ),
              Text(tl0(g.n('tutar')),
                  style: const TextStyle(color: Renk.yazi, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
    ];
  }
}

/// Tek ekimin ayrıntısı: kalem kalem maliyet, dekar başı kullanım, satışlar.
class EkimDetay extends StatelessWidget {
  const EkimDetay({super.key, required this.durum, required this.ekimId});
  final Durum durum;
  final String ekimId;

  @override
  Widget build(BuildContext context) {
    return Sayfa(
      baslik: 'Tarla Hesabı',
      durum: durum,
      builder: (context, v) {
        final e = v.bul('ekimler', ekimId);
        if (e == null) {
          return [const BosDurum(simge: '🗑️', yazi: 'Bu ekim silinmiş.')];
        }
        final o = v.ekimOzet(e);
        final t = v.tarla(e.s('tarlaId'));
        final kalemler = o.kalemler.entries.toList()
          ..sort((a, b) => b.value.tutar.compareTo(a.value.tutar));
        final satislar = v.satislar.where((s) => s.s('ekimId') == e.id).toList();
        return [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(urunSimge(e.s('urun')), style: const TextStyle(fontSize: 44)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${e.s('urun')} · ${e.t('yil')}', style: yaziKalin),
                          Text(
                              '${v.tarlaAdi(e.s('tarlaId'))} · ${sayi(o.dekar)} da · ${v.ekimSahipYazisi(e)}',
                              style: yaziSoluk),
                        ],
                      ),
                    ),
                  ],
                ),
                if (t != null) ...[
                  const SizedBox(height: 10),
                  MunavebeSatiri(v.munavebe(t, e.s('urun'), e.t('yil'))),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: Buton(
                            yazi: 'Düzenle / Hasat',
                            yukseklik: 44,
                            onTap: () => ekimFormu(context, durum, ekim: e))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Buton(
                            yazi: 'Maliyet',
                            renk: ButonRenk.turuncu,
                            yukseklik: 44,
                            onTap: () =>
                                giderFormu(context, durum, tarlaId: e.s('tarlaId')))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Buton(
                            yazi: 'Satış',
                            renk: ButonRenk.yesil,
                            yukseklik: 44,
                            onTap: () => satisFormu(context, durum, ekimId: e.id))),
                  ],
                ),
              ],
            ),
          ),
          Panel(
            baslik: 'Maliyet (dekar başı)',
            child: kalemler.isEmpty
                ? const Text(
                    'Bu tarlaya bu yıl gider girilmemiş. "Maliyet" ile ekleyin; birden fazla tarlaya ait faturalar dekarlarına göre bölünür.',
                    style: yaziSoluk)
                : Column(
                    children: [
                      for (final k in kalemler)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Text(giderSimge[k.key] ?? '📦',
                                  style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(k.key,
                                        style: const TextStyle(
                                            color: Renk.yazi, fontWeight: FontWeight.w700)),
                                    if (k.value.miktar > 0 && o.dekar > 0)
                                      Text(
                                          '${sayi(k.value.miktar)} ${k.value.birim} · dekara ${sayi(k.value.miktar / o.dekar)} ${k.value.birim}',
                                          style: yaziSoluk),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(tl0(k.value.tutar),
                                      style: const TextStyle(
                                          color: Renk.yazi, fontWeight: FontWeight.w800)),
                                  if (o.dekar > 0)
                                    Text('${tl0(k.value.tutar / o.dekar)}/da',
                                        style: const TextStyle(color: Renk.altin)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      const Divider(height: 18),
                      Satir('Toplam', tl0(o.toplam), kalin: true),
                      Satir('Dekar başı', tl0(o.dekarMaliyet), kalin: true, renk: Renk.altin),
                    ],
                  ),
          ),
          Panel(
            baslik: 'Hasat ve kâr',
            child: Column(
              children: [
                Satir('Hasat', o.hasatKg > 0 ? '${sayi(o.hasatKg)} kg' : 'Girilmedi'),
                if (o.hasatKg > 0) ...[
                  Satir('Verim', '${sayi(o.verim)} kg/da'),
                  Satir('Kg maliyeti', tl(o.kgMaliyet)),
                ],
                Satir('Satılan', '${sayi(o.satisKg)} kg'),
                Satir('Satış (kesintiler düşülmüş)', tl0(o.satisNet)),
                if (o.destek > 0) Satir('Destekler', tl0(o.destek), renk: Renk.turkuaz),
                if (o.satisKg > 0 && o.satisKg < o.hasatKg)
                  Satir('Kalanın tahmini değeri', tl0(o.gelirTahmini - o.satisNet)),
                const Divider(height: 18),
                Satir('Kâr', tl0(o.kar),
                    kalin: true, renk: o.kar >= 0 ? Renk.yesil : Renk.kirmizi),
                Satir('Dekar başı kâr', tl0(o.dekarKar),
                    renk: o.dekarKar >= 0 ? Renk.yesil : Renk.kirmizi),
              ],
            ),
          ),
          if (satislar.isNotEmpty)
            Panel(
              baslik: 'Satışlar',
              child: Column(
                children: [
                  for (final s in satislar)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.s('alici'), style: const TextStyle(color: Renk.yazi)),
                      subtitle: Text(
                          '${tarih(s.t('tarih'))} · ${sayi(s.n('kg'))} kg × ${tl(s.n('fiyat'))}',
                          style: yaziSoluk),
                      trailing: Text(tl0(v.satisHesap(s).beklenen),
                          style: const TextStyle(color: Renk.yazi, fontWeight: FontWeight.w800)),
                      onTap: () => satisFormu(context, durum, satis: s),
                    ),
                ],
              ),
            ),
        ];
      },
    );
  }
}
