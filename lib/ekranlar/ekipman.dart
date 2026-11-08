import 'package:flutter/material.dart';

import '../bicim.dart';
import '../hesap.dart';
import '../modeller.dart';
import '../sabitler.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'form.dart';
import 'kabuk.dart';

Future<void> ekipmanFormu(BuildContext context, Durum durum, {Kayit? ekipman}) {
  final v = durum.v;
  return formAc(
    context,
    baslik: ekipman == null ? 'Malzeme / Ekipman' : 'Düzenle',
    v: v,
    baslangic: {'tur': 'Sulama', 'sahip': Veriler.ben, 'birim': 'adet', 'miktar': 1, ...?ekipman?.d},
    alanlar: [
      const Alan('ad', 'Ne', zorunlu: true, oneriler: ekipmanOnerileri),
      Alan('tur', 'Türü', tip: AlanTip.secim, secenekler: ekipmanTurleri.keys.toList()),
      const Alan('marka', 'Marka / model', ipucu: 'Örn. New Holland TD75, 90\'lık PE boru'),
      const Alan('miktar', 'Miktar', tip: AlanTip.sayi),
      const Alan('birim', 'Birim', oneriler: ['adet', 'metre', 'takım', 'rulo']),
      const Alan('yil', 'Alış yılı', tip: AlanTip.yil),
      const Alan('alisFiyati', 'Alış fiyatı', tip: AlanTip.sayi, birim: '₺'),
      const Alan('guncelDeger', 'Bugünkü değeri', tip: AlanTip.sayi, birim: '₺'),
      Alan('sahip', 'Kime ait', tip: AlanTip.secim, secenekler: v.sahipler()),
      const Alan('tarlaId', 'Nerede (tarla)', tip: AlanTip.tarla),
      Alan('plaka', 'Plaka', gorunur: (d) => d['tur'] == 'Şahsi Araç' || d['tur'] == 'Traktör'),
      Alan('muayene', 'Muayene / sigorta bitişi', tip: AlanTip.tarih,
          gorunur: (d) => d['tur'] == 'Şahsi Araç' || d['tur'] == 'Traktör'),
      const Alan('not', 'Not', tip: AlanTip.uzun),
    ],
    onKaydet: (d) => durum.kaydet('ekipmanlar', d, id: ekipman?.id),
    onSil: ekipman == null ? null : () => durum.sil('ekipmanlar', ekipman.id),
  );
}

class EkipmanSayfasi extends StatefulWidget {
  const EkipmanSayfasi({super.key, required this.durum});
  final Durum durum;

  @override
  State<EkipmanSayfasi> createState() => _EkipmanSayfasiState();
}

class _EkipmanSayfasiState extends State<EkipmanSayfasi> {
  String _tur = 'Hepsi';

  @override
  Widget build(BuildContext context) {
    final durum = widget.durum;
    return Sayfa(
      baslik: 'Malzeme & Ekipman',
      durum: durum,
      fab: ekleButonu('Ekle', () => ekipmanFormu(context, durum)),
      builder: (context, v) {
        final simdi = DateTime.now().millisecondsSinceEpoch;
        final turler = ['Hepsi', ...ekipmanTurleri.keys.where((t) => v.ekipmanlar.any((e) => e.s('tur') == t))];
        final l = v.ekipmanlar.where((e) => _tur == 'Hepsi' || e.s('tur') == _tur).toList()
          ..sort((a, b) => v.ekipmanDegeri(b).compareTo(v.ekipmanDegeri(a)));
        final araba = v.giderler.where((g) => g.s('alan') == 'ev' && arabaKategorisi(g.s('kalem')));
        final yil = DateTime.now().year;
        final arabaYil = araba.where((g) => g.yil == yil).fold(0.0, (a, g) => a + g.n('tutar'));
        return [
          Panel(
            child: Row(
              children: [
                const Text('🧰', style: TextStyle(fontSize: 46)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tl0(v.toplamEkipman()),
                          style: const TextStyle(
                              color: Renk.altin, fontSize: 24, fontWeight: FontWeight.w900)),
                      Text('${v.ekipmanlar.length} kalem · toplam değer', style: yaziSoluk),
                      Text('Size ait: ${tl0(v.toplamEkipman(sahip: Veriler.ben))}', style: yaziSoluk),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SecimSatiri(secenekler: turler, secili: turler.contains(_tur) ? _tur : 'Hepsi',
              onSec: (s) => setState(() => _tur = s)),
          const SizedBox(height: 8),
          if (l.isEmpty)
            BosDurum(
              simge: '🚜',
              yazi: 'Traktör, yağmurlama takımı, ana boru, damlama hattı, pompa, şahsi araba gibi '
                  'malzemelerinizi ekleyin.',
              butonYazi: 'Ekle',
              onTap: () => ekipmanFormu(context, durum),
            ),
          for (final e in l)
            Panel(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              kenarRengi: e.t('muayene') > 0 && e.t('muayene') < simdi + 30 * 86400000
                  ? Renk.turuncu
                  : null,
              onTap: () => ekipmanFormu(context, durum, ekipman: e),
              child: Row(
                children: [
                  Text(ekipmanTurleri[e.s('tur')] ?? '🧰', style: const TextStyle(fontSize: 30)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${e.s('ad')}${e.n('miktar') > 1 ? ' · ${sayi(e.n('miktar'))} ${e.s('birim')}' : ''}',
                            style: yaziKalin),
                        Text(
                            [
                              if (e.s('marka').isNotEmpty) e.s('marka'),
                              if (e.t('yil') > 0) '${e.t('yil')}',
                              if (e.s('sahip').isNotEmpty) e.s('sahip'),
                              if (e.s('tarlaId').isNotEmpty) v.tarlaAdi(e.s('tarlaId')),
                              if (e.s('plaka').isNotEmpty) e.s('plaka'),
                            ].join(' · '),
                            style: yaziSoluk),
                        if (e.t('muayene') > 0)
                          Text('Muayene/sigorta: ${tarih(e.t('muayene'))}',
                              style: TextStyle(
                                  color: e.t('muayene') < simdi + 30 * 86400000
                                      ? Renk.turuncu
                                      : Renk.soluk,
                                  fontSize: 12.5)),
                      ],
                    ),
                  ),
                  Text(tl0(v.ekipmanDegeri(e)),
                      style: const TextStyle(color: Renk.altin, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          Panel(
            baslik: '🚗 Arabam ($yil)',
            child: Column(
              children: [
                if (arabaYil <= 0)
                  const Text('Ev Bütçem\'de "Araba (...)" kategorisindeki harcamalar burada toplanır.',
                      style: yaziSoluk),
                for (final k in evKategorileri.where(arabaKategorisi))
                  if (araba.where((g) => g.yil == yil && g.s('kalem') == k).isNotEmpty)
                    Satir(k.replaceFirst('Araba ', ''),
                        tl0(araba.where((g) => g.yil == yil && g.s('kalem') == k).fold(0.0, (a, g) => a + g.n('tutar')))),
                if (arabaYil > 0) ...[
                  const Divider(height: 14),
                  Satir('Toplam', tl0(arabaYil), kalin: true),
                  Satir('Aylık ortalama', tl0(arabaYil / DateTime.now().month)),
                ],
              ],
            ),
          ),
        ];
      },
    );
  }
}
