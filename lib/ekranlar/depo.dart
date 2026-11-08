import 'package:flutter/material.dart';

import '../bicim.dart';
import '../sabitler.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'kabuk.dart';
import 'piyasa.dart';

class DepoSayfasi extends StatelessWidget {
  const DepoSayfasi({super.key, required this.durum});
  final Durum durum;

  @override
  Widget build(BuildContext context) {
    return Sayfa(
      baslik: 'Depo',
      durum: durum,
      builder: (context, v) {
        final l = v.depo();
        final deger = l.fold(0.0, (a, d) => a + d.deger);
        final ton = l.fold(0.0, (a, d) => a + d.kalan) / 1000;
        return [
          Panel(
            child: Column(
              children: [
                const Text('🏭', style: TextStyle(fontSize: 52)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: BilgiKutu(baslik: 'Depodaki ürün', deger: '${sayi(ton)} ton')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: BilgiKutu(
                            baslik: 'Bugünkü değeri', deger: tl0(deger), renk: Renk.yesil)),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Hasat girildikçe depo artar, satış girildikçe (Keleş Satış\'tan alınanlar dahil) azalır. '
                  'Değer, Piyasa ekranındaki en iyi fiyatla hesaplanır.',
                  textAlign: TextAlign.center,
                  style: yaziSoluk,
                ),
              ],
            ),
          ),
          if (l.isEmpty)
            const BosDurum(
                simge: '📦', yazi: 'Depo boş. Ekimlere hasat miktarı girildiğinde burada görünür.'),
          for (final d in l)
            Panel(
              padding: const EdgeInsets.all(14),
              onTap: () => git(context, PiyasaSayfasi(durum: durum, urun: d.urun)),
              child: Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: Renk.zeminAlt,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Renk.cizgi, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(urunSimge(d.urun), style: const TextStyle(fontSize: 32)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(d.urun, style: yaziKalin),
                        Satir('Giren', '${sayi(d.giren)} kg'),
                        Satir('Satılan', '${sayi(d.cikan)} kg'),
                        Satir('Kalan', '${sayi(d.kalan)} kg', kalin: true),
                        if (d.enIyiFiyat > 0)
                          Satir('${d.enIyiYer} · ${tl(d.enIyiFiyat)}/kg', tl0(d.deger),
                              renk: Renk.yesil),
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
