import 'dart:math';

import 'package:flutter/material.dart';

import '../bicim.dart';
import '../hesap.dart';
import '../sabitler.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'kabuk.dart';

class RaporlarSayfasi extends StatefulWidget {
  const RaporlarSayfasi({super.key, required this.durum});
  final Durum durum;

  @override
  State<RaporlarSayfasi> createState() => _RaporlarSayfasiState();
}

class _RaporlarSayfasiState extends State<RaporlarSayfasi> {
  int _yil = DateTime.now().year;
  String _kisi = Veriler.ben;

  Durum get durum => widget.durum;

  @override
  Widget build(BuildContext context) {
    return Sayfa(
      baslik: 'Yıllık Kârlılık',
      durum: durum,
      geri: false,
      builder: (context, v) {
        final yillar = v.yillar(DateTime.now().year);
        final kisiler = v.sahipler();
        final kisi = kisiler.contains(_kisi) ? _kisi : Veriler.ben;
        final o = v.yilOzet(_yil, sahip: kisi);
        final onceki = v.yilOzet(_yil - 1, sahip: kisi);
        final grafik = [
          for (final y in yillar.take(8).toList().reversed) (y, v.yilOzet(y, sahip: kisi)),
        ];
        final urunler_ = v.urunOzetleri(yil: _yil, sahip: kisi);
        String degisim(double simdi, double eski) {
          if (eski.abs() < 1) return '';
          final p = (simdi - eski) / eski.abs() * 100;
          return '${p >= 0 ? '▲' : '▼'} %${p.abs().toStringAsFixed(1)}';
        }

        Widget kutu(String baslik, double deger, double eski, {Color? renk}) => BilgiKutu(
              baslik: baslik,
              deger: '${tl0(deger)}  ${degisim(deger, eski)}',
              renk: renk,
            );
        return [
          SecimSatiri(
            secenekler: [for (final y in yillar) '$y'],
            secili: '$_yil',
            onSec: (s) => setState(() => _yil = int.parse(s)),
          ),
          const SizedBox(height: 6),
          SecimSatiri(
            secenekler: kisiler,
            secili: kisi,
            onSec: (s) => setState(() => _kisi = s),
          ),
          const SizedBox(height: 10),
          Panel(
            baslik: kisi == Veriler.ben ? 'Şirket Performansı' : '$kisi · tarım hesabı',
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.3,
              children: [
                kutu('Tarım satışı', o.tarimSatis, onceki.tarimSatis),
                kutu('Tarım gideri', o.tarimGider, onceki.tarimGider),
                kutu('Destekler', o.destek, onceki.destek, renk: Renk.turkuaz),
                kutu('Kira geliri', o.kiraGeliri, onceki.kiraGeliri),
                kutu('Tarım kârı', o.tarimKar, onceki.tarimKar,
                    renk: o.tarimKar >= 0 ? Renk.yesil : Renk.kirmizi),
                BilgiKutu(
                    baslik: 'Dekar başı kâr',
                    deger: o.ekiliDekar > 0 ? tl0(o.dekarKar) : '-',
                    renk: Renk.altin),
                if (kisi == Veriler.ben) ...[
                  kutu('Maaş', o.maas, onceki.maas),
                  kutu('Diğer gelir', o.digerGelir + o.digerSatis,
                      onceki.digerGelir + onceki.digerSatis),
                  kutu('Ev giderleri', o.evGider, onceki.evGider),
                  kutu('Yıl sonu net', o.net, onceki.net,
                      renk: o.net >= 0 ? Renk.yesil : Renk.kirmizi),
                ],
              ],
            ),
          ),
          if (kisi == Veriler.ben && o.toplamGelir > 0)
            Panel(
              baslik: 'Gelir dağılımı',
              child: Column(
                children: [
                  for (final (ad, x, renk) in [
                    ('Tarım (satış + destek + kira)', o.tarimSatis + o.destek + o.kiraGeliri, Renk.yesil),
                    ('Maaş', o.maas, Renk.mavi),
                    ('Diğer', o.digerGelir + o.digerSatis, Renk.mor),
                  ])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Satir(ad, '${tl0(x)} · %${(x / o.toplamGelir * 100).toStringAsFixed(0)}'),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (x / o.toplamGelir).clamp(0.0, 1.0).toDouble(),
                              minHeight: 8,
                              color: renk,
                              backgroundColor: Renk.zeminAlt,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          Panel(
            baslik: 'Yıllara göre kâr',
            child: SizedBox(
              height: 190,
              child: CustomPaint(
                painter: _Grafik([for (final (y, x) in grafik) (y, kisi == Veriler.ben ? x.net : x.tarimKar)]),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          Panel(
            baslik: 'Ürün bazında ($_yil)',
            child: urunler_.isEmpty
                ? const Text('Bu yıl ekim yok.', style: yaziSoluk)
                : Column(
                    children: [
                      for (final u in urunler_)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Text(urunSimge(u.urun), style: const TextStyle(fontSize: 26)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(u.urun,
                                        style: const TextStyle(
                                            color: Renk.yazi, fontWeight: FontWeight.w700)),
                                    Text(
                                        '${sayi(u.dekar)} da · maliyet ${tl0(u.dekarMaliyet)}/da'
                                        '${u.verim > 0 ? ' · ${sayi(u.verim)} kg/da' : ''}',
                                        style: yaziSoluk),
                                  ],
                                ),
                              ),
                              Text(
                                  u.satisKg > 0 ? '${tl0(u.dekarKar)}/da' : 'satış yok',
                                  style: TextStyle(
                                      color: u.satisKg == 0
                                          ? Renk.soluk
                                          : (u.dekarKar >= 0 ? Renk.yesil : Renk.kirmizi),
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ];
      },
    );
  }
}

class _Grafik extends CustomPainter {
  _Grafik(this.veri);
  final List<(int, double)> veri;

  @override
  void paint(Canvas canvas, Size size) {
    if (veri.isEmpty) return;
    const altBosluk = 22.0;
    final h = size.height - altBosluk;
    final enBuyuk = veri.map((e) => e.$2.abs()).fold(1.0, max);
    final negatifVar = veri.any((e) => e.$2 < 0);
    final sifir = negatifVar ? h / 2 : h;
    final olcek = (negatifVar ? h / 2 : h) * 0.9 / enBuyuk;
    final w = size.width / veri.length;
    final cizgi = Paint()
      ..color = Renk.cizgi
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, sifir), Offset(size.width, sifir), cizgi);
    for (var i = 0; i < veri.length; i++) {
      final (yil, deger) = veri[i];
      final boy = deger.abs() * olcek;
      final x = i * w + w * 0.2;
      final r = Rect.fromLTWH(x, deger >= 0 ? sifir - boy : sifir, w * 0.6, boy);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(4)),
        Paint()..color = deger >= 0 ? Renk.yesil : Renk.kirmizi,
      );
      final tp = TextPainter(
        text: TextSpan(text: '$yil', style: const TextStyle(color: Renk.soluk, fontSize: 11)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(i * w + (w - tp.width) / 2, size.height - 16));
      final dp = TextPainter(
        text: TextSpan(text: kisaTl(deger), style: const TextStyle(color: Renk.yazi, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: w);
      final dy = deger >= 0 ? sifir - boy - 13 : sifir + boy + 1;
      dp.paint(canvas, Offset(i * w + (w - dp.width) / 2, dy.clamp(0.0, size.height - 30).toDouble()));
    }
  }

  @override
  bool shouldRepaint(covariant _Grafik old) => old.veri != veri;
}
