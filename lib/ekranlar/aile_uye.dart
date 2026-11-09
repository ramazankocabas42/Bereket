import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../bicim.dart';
import '../modeller.dart';
import '../sabitler.dart';
import '../servis/guncelleme.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'form.dart';

double _n(Object? v) => v is num ? v.toDouble() : 0;

/// Aile ile alacak/verecek kaydı. [aileGorunum] true ise aile üyesinin
/// bakış açısıyla ("Ben verdim" = kişi verdi) gösterilir.
Future<void> aileHareketFormu(BuildContext context, Durum durum,
    {required String kisi, Kayit? hareket, bool aileGorunum = false}) {
  final sahipAd = durum.isim(durum.isletme?.sahip ?? '');
  final secenekler = aileGorunum
      ? {'o_verdi': 'Ben verdim ($sahipAd aldı)', 'ben_verdim': 'Ben aldım ($sahipAd verdi)'}
      : {'ben_verdim': 'Ben verdim ($kisi aldı)', 'o_verdi': 'Ben aldım ($kisi verdi)'};
  final ters = {for (final e in secenekler.entries) e.value: e.key};
  return formAc(
    context,
    baslik: hareket == null ? 'Alacak / Verecek' : 'Kaydı Düzenle',
    v: durum.v,
    baslangic: {
      'tarih': DateTime.now().millisecondsSinceEpoch,
      ...?hareket?.d,
      'yonYazi': secenekler[hareket?.s('yon') ?? secenekler.keys.first],
    },
    alanlar: [
      Alan('yonYazi', 'Ne oldu', tip: AlanTip.secim, secenekler: secenekler.values.toList()),
      const Alan('tutar', 'Tutar', tip: AlanTip.sayi, birim: '₺', zorunlu: true),
      const Alan('aciklama', 'Açıklama',
          oneriler: ['Nakit', 'Havale', 'Gübre', 'Mazot', 'Tohum', 'İlaç', 'Pancar parası', 'Destek parası']),
      const Alan('tarih', 'Tarih', tip: AlanTip.tarih),
    ],
    onKaydet: (d) async {
      final yon = ters[d.remove('yonYazi')] ?? 'ben_verdim';
      final t = _n(d['tarih']).toInt();
      final veri = <String, dynamic>{
        'kisi': kisi,
        'yon': yon,
        'tutar': _n(d['tutar']),
        'aciklama': (d['aciklama'] ?? '').toString(),
        'tarih': t,
        'yil': DateTime.fromMillisecondsSinceEpoch(t).year,
        'ekleyen': hareket?.s('ekleyen').isNotEmpty == true ? hareket!.s('ekleyen') : durum.uid,
        'ekleyenAd': hareket?.s('ekleyenAd').isNotEmpty == true
            ? hareket!.s('ekleyenAd')
            : durum.isim(durum.uid),
      };
      if (hareket == null) {
        await Veri.kol(durum.iid, 'aile_hareketler').add({...veri, 'olusturma': Veri.simdi});
      } else {
        await Veri.kol(durum.iid, 'aile_hareketler').doc(hareket.id).update(veri);
      }
    },
    onSil: hareket == null
        ? null
        : () => Veri.kol(durum.iid, 'aile_hareketler').doc(hareket.id).delete(),
  );
}

/// Babam / Kardeşim gibi aile üyelerinin tek ekranı: kendi tarla hesabı.
class AileUyeEkrani extends StatefulWidget {
  const AileUyeEkrani({super.key, required this.durum});
  final Durum durum;

  @override
  State<AileUyeEkrani> createState() => _AileUyeEkraniState();
}

class _AileUyeEkraniState extends State<AileUyeEkrani> {
  String _yil = 'Tümü';

  Durum get durum => widget.durum;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Guncelleme.kontrolEt(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: durum,
          builder: (context, _) {
            final ad = durum.aileAdi;
            final sahip = durum.isim(durum.isletme?.sahip ?? '');
            final ozet = durum.aileOzet;
            if (!durum.aileYuklendi) {
              return const Center(child: CircularProgressIndicator());
            }
            final yillarMap = ozet?['yillar'] is Map ? ozet!['yillar'] as Map : const {};
            final yillar = ['Tümü', ...(yillarMap.keys.map((k) => k.toString()).toList()..sort((a, b) => b.compareTo(a)))];
            final secili = yillar.contains(_yil) ? _yil : 'Tümü';
            final o = secili == 'Tümü'
                ? (ozet?['tumu'] is Map ? ozet!['tumu'] as Map : const {})
                : (yillarMap[secili] is Map ? yillarMap[secili] as Map : const {});
            final hesap = _n(o['hesaplasma']);
            final kalemler = o['kalemler'] is Map ? (o['kalemler'] as Map).entries.toList() : <MapEntry>[];
            kalemler.sort((a, b) => _n((b.value as Map)['tutar']).compareTo(_n((a.value as Map)['tutar'])));
            final ekimler = o['ekimler'] is List ? o['ekimler'] as List : const [];
            final tarlalar = ozet?['tarlalar'] is List ? ozet!['tarlalar'] as List : const [];
            final hareketler = durum.aileHareketler
                .where((h) => secili == 'Tümü' || '${h.yil}' == secili)
                .toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 30),
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(colors: [Renk.yesil, Renk.yesilKoyu]),
                      border: Border.all(color: Renk.altin, width: 2.5),
                    ),
                    child: const Text('BEREKET',
                        style: TextStyle(
                            color: Renk.altin,
                            fontSize: 24,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 12),
                Panel(
                  child: Row(
                    children: [
                      const Text('👨‍🌾', style: TextStyle(fontSize: 44)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$ad · Benim Tarla Hesabım', style: yaziKalin),
                            Text('${durum.isim(durum.uid)} · ${durum.isletme?.ad ?? ''}', style: yaziSoluk),
                            if (ozet?['guncelleme'] is num)
                              Text('Son güncelleme: ${tarih((ozet!['guncelleme'] as num).toInt())}',
                                  style: yaziSoluk),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (ozet == null)
                  const Panel(
                    child: Text(
                      'Hesabınız henüz hazırlanmadı. İşletme sahibinin uygulaması açıldığında '
                      'tarlalarınız ve hesaplarınız burada görünecek.',
                      style: yaziSoluk,
                    ),
                  ),
                SecimSatiri(secenekler: yillar, secili: secili, onSec: (s) => setState(() => _yil = s)),
                const SizedBox(height: 10),
                Panel(
                  kenarRengi: hesap.abs() < 1 ? Renk.cizgi : (hesap > 0 ? Renk.yesil : Renk.turuncu),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Hesaplaşma', style: yaziKalin),
                      const SizedBox(height: 6),
                      Text(
                        hesap.abs() < 1
                            ? 'Hesap denk.'
                            : (hesap > 0
                                ? 'Alacağınız: ${tl0(hesap)}'
                                : 'Borcunuz: ${tl0(-hesap)}'),
                        style: TextStyle(
                            color: hesap > 0 ? Renk.yesil : (hesap < 0 ? Renk.turuncu : Renk.yazi),
                            fontSize: 20,
                            fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Satir('Masrafınızı ödeyen: $sahip', tl0(_n(o['masraf']))),
                      Satir('Satış parasını alan: $sahip', tl0(_n(o['tahsil']))),
                      if (_n(o['destekDuzeltme']) != 0)
                        Satir('Destek farkı', tl0(_n(o['destekDuzeltme']))),
                      if (_n(o['onunVerdigi']) > 0) Satir('Sizin verdikleriniz', tl0(_n(o['onunVerdigi']))),
                      if (_n(o['benimVerdigim']) > 0) Satir('Sizin aldıklarınız', tl0(_n(o['benimVerdigim']))),
                    ],
                  ),
                ),
                Panel(
                  baslik: 'Özet',
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.3,
                    children: [
                      BilgiKutu(baslik: 'Tarla', deger: '${_n(o['tarlaSayisi']).toInt()} · ${sayi(_n(o['dekar']))} da'),
                      BilgiKutu(baslik: 'Hasat', deger: '${sayi(_n(o['hasatKg']))} kg'),
                      BilgiKutu(baslik: 'Masraf', deger: tl0(_n(o['masraf'])), renk: Renk.turuncu),
                      BilgiKutu(baslik: 'Satış', deger: tl0(_n(o['satis']))),
                      BilgiKutu(baslik: 'Destek', deger: tl0(_n(o['destek'])), renk: Renk.turkuaz),
                      BilgiKutu(
                          baslik: 'Kâr',
                          deger: tl0(_n(o['kar'])),
                          renk: _n(o['kar']) >= 0 ? Renk.yesil : Renk.kirmizi),
                    ],
                  ),
                ),
                Panel(
                  baslik: 'Alacak / Verecek',
                  eylem: TextButton(
                    onPressed: () => aileHareketFormu(context, durum, kisi: ad, aileGorunum: true),
                    child: const Text('+ Ekle'),
                  ),
                  child: hareketler.isEmpty
                      ? Text('$sahip ile aranızdaki para ve malzeme alışverişini buraya ekleyin.',
                          style: yaziSoluk)
                      : Column(
                          children: [
                            for (final h in hareketler)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Text(h.s('yon') == 'o_verdi' ? '⬆️' : '⬇️',
                                    style: const TextStyle(fontSize: 22)),
                                title: Text(
                                    '${h.s('yon') == 'o_verdi' ? 'Verdim' : 'Aldım'}'
                                    '${h.s('aciklama').isEmpty ? '' : ' · ${h.s('aciklama')}'}',
                                    style: const TextStyle(color: Renk.yazi)),
                                subtitle: Text('${tarih(h.t('tarih'))} · ekleyen: ${h.s('ekleyenAd')}',
                                    style: yaziSoluk),
                                trailing: Text(tl0(h.n('tutar')),
                                    style: TextStyle(
                                        color: h.s('yon') == 'o_verdi' ? Renk.yesil : Renk.turuncu,
                                        fontWeight: FontWeight.w800)),
                                onTap: h.s('ekleyen') == durum.uid
                                    ? () => aileHareketFormu(context, durum,
                                        kisi: ad, hareket: h, aileGorunum: true)
                                    : null,
                              ),
                          ],
                        ),
                ),
                if (kalemler.isNotEmpty)
                  Panel(
                    baslik: 'Kullanılan malzeme ve masraflar',
                    child: Column(
                      children: [
                        for (final e in kalemler)
                          Satir(
                              '${giderSimge[e.key] ?? '📦'} ${e.key}'
                              '${_n((e.value as Map)['miktar']) > 0 ? ' · ${sayi(_n((e.value as Map)['miktar']))} ${(e.value as Map)['birim'] ?? ''}' : ''}',
                              tl0(_n((e.value as Map)['tutar']))),
                      ],
                    ),
                  ),
                if (ekimler.isNotEmpty)
                  Panel(
                    baslik: 'Ekimler',
                    child: Column(
                      children: [
                        for (final x in ekimler.whereType<Map>())
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Text(urunSimge('${x['urun']}'), style: const TextStyle(fontSize: 22)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${x['yil']} · ${x['urun']} · ${x['tarla']}',
                                          style: const TextStyle(color: Renk.yazi)),
                                      Text(
                                          '${sayi(_n(x['dekar']))} da · masraf ${tl0(_n(x['masraf']))}'
                                          '${_n(x['hasatKg']) > 0 ? ' · ${sayi(_n(x['hasatKg']))} kg' : ''}'
                                          '${_n(x['pay']) < 0.999 ? ' · pay %${(_n(x['pay']) * 100).round()}' : ''}',
                                          style: yaziSoluk),
                                    ],
                                  ),
                                ),
                                Text(tl0(_n(x['kar'])),
                                    style: TextStyle(
                                        color: _n(x['kar']) >= 0 ? Renk.yesil : Renk.kirmizi,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                if (tarlalar.isNotEmpty)
                  Panel(
                    baslik: 'Tarlalarım',
                    child: Column(
                      children: [
                        for (final t in tarlalar.whereType<Map>())
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Satir('${t['ad']}', '${sayi(_n(t['dekar']))} da', kalin: true),
                                Text(
                                    [
                                      if ('${t['mahalle'] ?? ''}'.isNotEmpty) '${t['mahalle']}',
                                      if ('${t['ada'] ?? ''}'.isNotEmpty) 'Ada ${t['ada']}/${t['parsel']}',
                                      if ('${t['mulkiyet'] ?? ''}'.isNotEmpty) '${t['mulkiyet']}',
                                    ].join(' · '),
                                    style: yaziSoluk),
                                if (t['gecmis'] is Map)
                                  Text(
                                      ((t['gecmis'] as Map).entries.toList()
                                            ..sort((a, b) => '${b.key}'.compareTo('${a.key}')))
                                          .take(5)
                                          .map((e) => '${e.key}: ${e.value}')
                                          .join('  ·  '),
                                      style: const TextStyle(color: Renk.soluk, fontSize: 12.5)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                if (durum.hata != null)
                  Panel(
                    kenarRengi: Renk.kirmizi,
                    child: Text(hataYazisi(durum.hata!), style: const TextStyle(color: Renk.kirmizi)),
                  ),
                Buton(
                  yazi: 'Çıkış Yap',
                  renk: ButonRenk.gri,
                  onTap: () => FirebaseAuth.instance.signOut(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
