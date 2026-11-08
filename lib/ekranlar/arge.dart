import 'package:flutter/material.dart';

import '../bicim.dart';
import '../sabitler.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'kabuk.dart';

class ArgeSayfasi extends StatefulWidget {
  const ArgeSayfasi({super.key, required this.durum});
  final Durum durum;

  @override
  State<ArgeSayfasi> createState() => _ArgeSayfasiState();
}

class _ArgeSayfasiState extends State<ArgeSayfasi> {
  String _ara = '';

  @override
  Widget build(BuildContext context) {
    return Sayfa(
      baslik: 'Ar-Ge · Verimlilik',
      durum: widget.durum,
      builder: (context, v) {
        Widget karsilastirma(String simge, String baslik, Map<int, double> m, String birim,
            {bool azIyi = true}) {
          final yillar = m.keys.toList()..sort();
          if (yillar.isEmpty) return const SizedBox.shrink();
          final yeni = yillar.last;
          final eski = yillar.length > 1 ? yillar[yillar.length - 2] : null;
          final yd = m[yeni]!;
          final ed = eski == null ? null : m[eski]!;
          final iyi = ed == null ? null : (azIyi ? yd <= ed : yd >= ed);
          return Container(
            width: 160,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Renk.zeminAlt,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: iyi == null ? Renk.cizgi : (iyi ? Renk.yesil : Renk.kirmizi), width: 2),
            ),
            child: Column(
              children: [
                Text(simge, style: const TextStyle(fontSize: 34)),
                Text(baslik,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Renk.yazi, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(
                      ed == null
                          ? '$yeni: ${sayi(yd)} $birim'
                          : '${sayi(ed)} ≫ ${sayi(yd)} $birim',
                      style: const TextStyle(color: Renk.soluk, fontSize: 13)),
                ),
                if (ed != null && ed > 0)
                  Text(
                      '${yd >= ed ? '▲' : '▼'} %${((yd - ed).abs() / ed * 100).toStringAsFixed(1)}',
                      style: TextStyle(
                          color: iyi! ? Renk.yesil : Renk.kirmizi,
                          fontWeight: FontWeight.w800)),
                Text(eski == null ? '$yeni' : '$eski → $yeni', style: yaziSoluk),
              ],
            ),
          );
        }

        final kullanim = [
          karsilastirma('⛽', 'Mazot', v.dekarBasiKullanim('Mazot'), 'lt/da'),
          karsilastirma('⚡', 'Elektrik', v.dekarBasiKullanim('Elektrik'), 'kWh/da'),
          karsilastirma('🧪', 'Gübre', v.dekarBasiKullanim('Gübre'), 'kg/da'),
          karsilastirma('🌱', 'Tohum', v.dekarBasiKullanim('Tohum'), 'kg/da'),
          karsilastirma('💧', 'İlaç', v.dekarBasiKullanim('İlaç'), 'lt/da'),
        ];
        final ekilenler = {for (final e in v.ekimler) e.s('urun')};
        final verimler = [
          for (final u in ekilenler)
            karsilastirma(urunSimge(u), u, v.verim(u), 'kg/da', azIyi: false),
        ];
        final a = araMetni(_ara);
        final fiyatlar = v
            .girdiFiyatlari()
            .where((g) => a.isEmpty || araMetni(g.ad).contains(a))
            .toList();
        return [
          Panel(
            baslik: 'Dekar başı kullanım (tüm ekili alan)',
            child: SizedBox(
              height: 180,
              child: kullanim.every((w) => w is SizedBox)
                  ? const Center(
                      child: Text('Gider girerken miktar (lt, kWh, kg) yazınca burada yıllara göre karşılaştırılır.',
                          textAlign: TextAlign.center, style: yaziSoluk))
                  : ListView(scrollDirection: Axis.horizontal, children: kullanim),
            ),
          ),
          Panel(
            baslik: 'Verim',
            child: SizedBox(
              height: 180,
              child: verimler.every((w) => w is SizedBox)
                  ? const Center(
                      child: Text('Hasat miktarı girildikçe ürün verimleri yıllara göre karşılaştırılır.',
                          textAlign: TextAlign.center, style: yaziSoluk))
                  : ListView(scrollDirection: Axis.horizontal, children: verimler),
            ),
          ),
          Panel(
            baslik: 'Girdi fiyatları',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  decoration: const InputDecoration(hintText: 'Ara...', prefixIcon: Icon(Icons.search)),
                  onChanged: (s) => setState(() => _ara = s),
                ),
                const SizedBox(height: 8),
                if (fiyatlar.isEmpty)
                  const Text('Faturalardan (miktar + tutar) son alış fiyatları burada listelenir.',
                      style: yaziSoluk),
                for (final g in fiyatlar)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Text(giderSimge[g.kalem] ?? '📦', style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.ad,
                                  style: const TextStyle(
                                      color: Renk.yazi, fontWeight: FontWeight.w700)),
                              Text(tarih(g.tarih), style: yaziSoluk),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${tl(g.son)}/${g.birim}',
                                style: const TextStyle(
                                    color: Renk.yazi, fontWeight: FontWeight.w800)),
                            if (g.degisim != null)
                              Text(
                                  '${g.degisim! >= 0 ? '▲' : '▼'} %${g.degisim!.abs().toStringAsFixed(1)}',
                                  style: TextStyle(
                                      color: g.degisim! > 15
                                          ? Renk.kirmizi
                                          : (g.degisim! > 0 ? Renk.turuncu : Renk.yesil),
                                      fontWeight: FontWeight.w700)),
                          ],
                        ),
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
