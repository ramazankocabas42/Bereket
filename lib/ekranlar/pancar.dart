import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bicim.dart';
import '../hesap.dart';
import '../modeller.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'form.dart';
import 'hesaplar.dart';
import 'kabuk.dart';
import 'satislar.dart';

const _pancar = 'Şeker Pancarı';

Future<void> kotaFormu(BuildContext context, Durum durum, {Kayit? kota}) {
  final v = durum.v;
  final sahipler = v.sahipler();
  return formAc(
    context,
    baslik: kota == null ? 'Pancar Kotası' : 'Kotayı Düzenle',
    v: v,
    baslangic: {
      'yil': DateTime.now().year,
      'sahibi': 'Babam',
      'kullanan': Veriler.ben,
      ...?kota?.d,
    },
    alanlar: [
      const Alan('yil', 'Yıl', tip: AlanTip.yil),
      Alan('sahibi', 'Kota kimin adına', zorunlu: true, oneriler: sahipler),
      const Alan('ton', 'Kota', tip: AlanTip.sayi, birim: 'ton', zorunlu: true),
      Alan('kullanan', 'Kotayı kim kullanıyor (pancarı kim ekiyor)',
          tip: AlanTip.secim, secenekler: sahipler,
          aciklama: 'Pancar hesabı bu kişinin adına işler; kota başkasının olsa da.'),
      const Alan('kiralik', 'Kiralık kota', tip: AlanTip.anahtar),
      Alan('kimden', 'Kimden kiralandı', gorunur: (d) => d['kiralik'] == true),
      Alan('kiraBedeli', 'Kota kira bedeli (toplam)', tip: AlanTip.sayi, birim: '₺',
          gorunur: (d) => d['kiralik'] == true,
          aciklama: 'Kullananın o yılki pancar tarlalarına dekara göre maliyet olarak yazılır.'),
      const Alan('not', 'Not', tip: AlanTip.uzun),
    ],
    onKaydet: (d) async {
      if (d['kiralik'] != true) {
        d['kimden'] = null;
        d['kiraBedeli'] = null;
      }
      await durum.kaydet('kotalar', d, id: kota?.id);
    },
    onSil: kota == null ? null : () => durum.sil('kotalar', kota.id),
  );
}

class PancarSayfasi extends StatefulWidget {
  const PancarSayfasi({super.key, required this.durum});
  final Durum durum;

  @override
  State<PancarSayfasi> createState() => _PancarSayfasiState();
}

class _PancarSayfasiState extends State<PancarSayfasi> {
  int _yil = DateTime.now().year;

  Durum get durum => widget.durum;

  Future<void> _turkseker() async {
    final ok = await launchUrl(Uri.parse('https://www.turkseker.gov.tr/'),
        mode: LaunchMode.externalApplication);
    if (!ok && mounted) bildir(context, 'Tarayıcı açılamadı.');
  }

  @override
  Widget build(BuildContext context) {
    return Sayfa(
      baslik: 'Pancar & Kooperatif',
      durum: durum,
      fab: ekleButonu('Kota Ekle', () => kotaFormu(context, durum)),
      builder: (context, v) {
        final yillar = {
          ...v.yillar(DateTime.now().year),
          for (final k in v.kotalar) k.t('yil'),
        }.toList()
          ..sort((a, b) => b.compareTo(a));
        final kotalar = v.kotalar.where((k) => k.t('yil') == _yil).toList();
        final toplamKota = kotalar.fold(0.0, (a, k) => a + k.n('ton'));
        final teslim = v.satislar
            .where((s) => s.s('urun') == _pancar && s.yil == _yil && !s.b('sozlesmeli'))
            .fold(0.0, (a, s) => a + s.n('kg') / 1000);
        final satislar = v.satislar
            .where((s) => s.s('urun') == _pancar && s.yil == _yil)
            .toList();
        final koop = v.hesaplar
            .where((h) =>
                h.s('tur') == 'Kooperatif' ||
                araMetni(h.s('ad')).contains('seker') ||
                araMetni(h.s('ad')).contains('koop'))
            .toList();
        return [
          Panel(
            child: Column(
              children: [
                const Text('🟣', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                        child: Buton(
                            yazi: 'Teslimat / Sözleşme',
                            renk: ButonRenk.yesil,
                            onTap: () => satisFormu(context, durum,
                                urun: _pancar, yer: 'Şeker Fabrikası'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Buton(
                            yazi: 'Türkşeker Sorgu', onTap: _turkseker)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: BilgiKutu(baslik: '$_yil kota', deger: '${sayi(toplamKota)} ton')),
                    const SizedBox(width: 8),
                    Expanded(child: BilgiKutu(baslik: 'Teslim', deger: '${sayi(teslim)} ton')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: BilgiKutu(
                            baslik: 'Kalan',
                            deger: '${sayi(toplamKota - teslim)} ton',
                            renk: toplamKota - teslim >= 0 ? Renk.yesil : Renk.kirmizi)),
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
          const SizedBox(height: 10),
          Panel(
            baslik: 'Kotalar',
            child: kotalar.isEmpty
                ? const Text('Bu yıl için kota girilmedi.', style: yaziSoluk)
                : Column(
                    children: [
                      for (final k in kotalar)
                        InkWell(
                          onTap: () => kotaFormu(context, durum, kota: k),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                          '${k.s('sahibi')} adına${k.b('kiralik') ? ' · kiralık (${k.s('kimden')})' : ''}',
                                          style: const TextStyle(
                                              color: Renk.yazi, fontWeight: FontWeight.w700)),
                                    ),
                                    Text('${sayi(k.n('ton'))} ton',
                                        style: const TextStyle(
                                            color: Renk.altin, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                                Text(
                                    'Kullanan: ${v.kotaKullanan(k)} · teslim ${sayi(v.kotaKullanilan(k))} ton'
                                    '${k.n('kiraBedeli') > 0 ? ' · kira ${tl0(k.n('kiraBedeli'))}' : ''}',
                                    style: yaziSoluk),
                                const SizedBox(height: 4),
                                Cubuk(
                                  oran: k.n('ton') > 0 ? v.kotaKullanilan(k) / k.n('ton') : 0,
                                  yazi: '${sayi(v.kotaKullanilan(k))}/${sayi(k.n('ton'))} ton',
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          _tahmin(v),
          Panel(
            baslik: 'Kooperatif ve fabrika hesapları',
            eylem: TextButton(
              onPressed: () => git(context,
                  HesaplarSayfasi(durum: durum, yon: 'borc', tur: 'Kooperatif')),
              child: const Text('Tümü'),
            ),
            child: koop.isEmpty
                ? const Text(
                    'Ereğli Pancar Ekicileri Kooperatifi\'nden aldığınız tohum, gübre, ilaç ve avansları '
                    'Borçlarım\'da "Kooperatif" türünde bir hesap açarak girin.',
                    style: yaziSoluk)
                : Column(
                    children: [
                      for (final h in koop)
                        Satir(h.s('ad'), tl0(v.bakiyeTl(h)),
                            renk: v.bakiye(h) > 0 ? Renk.kirmizi : Renk.yesil),
                    ],
                  ),
          ),
          if (satislar.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8, left: 4),
              child: Text('Teslimat ve ödemeler', style: yaziKalin),
            ),
          for (final s in satislar) SatisKarti(durum: durum, v: v, satis: s),
        ];
      },
    );
  }

  /// Gelecek yıl kota ihtiyacı tahmini.
  Widget _tahmin(Veriler v) {
    final gelecek = DateTime.now().year + 1;
    final verimler = v.verim(_pancar).values.toList();
    final ortVerim = verimler.isEmpty
        ? 0.0
        : verimler.reduce((a, b) => a + b) / verimler.length; // kg/da
    final uygun = v.tarlalar.where((t) {
      final p = v.tarlaPaylari(t.id)[Veriler.ben] ?? 0;
      return p > 0 && v.munavebe(t, _pancar, gelecek).seviye < 2;
    }).toList();
    final dekar = uygun.fold(
        0.0, (a, t) => a + t.n('dekar') * (v.tarlaPaylari(t.id)[Veriler.ben] ?? 0));
    final tahminTon = dekar * ortVerim / 1000;
    final buYilKota = v.kotalar
        .where((k) => k.t('yil') == DateTime.now().year && v.kotaKullanan(k) == Veriler.ben)
        .fold(0.0, (a, k) => a + k.n('ton'));
    return Panel(
      baslik: '$gelecek kota tahmini',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Satir('Münavebeye uygun tarlalarınız', '${uygun.length} · ${sayi(dekar)} da'),
          Satir('Ortalama pancar veriminiz',
              ortVerim > 0 ? '${sayi(ortVerim / 1000)} ton/da' : 'hasat kaydı yok'),
          if (ortVerim > 0) ...[
            Satir('Tahmini üretim (hepsine ekilirse)', '${sayi(tahminTon)} ton', kalin: true),
            Satir('Bu yılki kotanız', '${sayi(buYilKota)} ton'),
            Satir(
                tahminTon > buYilKota ? 'Ek kota ihtiyacı' : 'Kota fazlası',
                '${sayi((tahminTon - buYilKota).abs())} ton',
                renk: tahminTon > buYilKota ? Renk.turuncu : Renk.yesil),
          ],
          const SizedBox(height: 6),
          const Text(
            'Bu bir tahmindir; kesin kotayı fabrika belirler. Hesap, geçmiş hasat verilerinize '
            've tarlaların münavebe durumuna göre yapılır.',
            style: yaziSoluk,
          ),
        ],
      ),
    );
  }
}
