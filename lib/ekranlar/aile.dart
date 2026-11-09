import 'package:flutter/material.dart';

import '../bicim.dart';
import '../hesap.dart';
import '../sabitler.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'aile_uye.dart';
import 'kabuk.dart';
import 'uretim.dart';

class AileSayfasi extends StatefulWidget {
  const AileSayfasi({super.key, required this.durum});
  final Durum durum;

  @override
  State<AileSayfasi> createState() => _AileSayfasiState();
}

class _AileSayfasiState extends State<AileSayfasi> {
  String _yil = '${DateTime.now().year}';

  @override
  Widget build(BuildContext context) {
    final durum = widget.durum;
    return Sayfa(
      baslik: 'Aile Hesapları',
      durum: durum,
      builder: (context, v) {
        final yillar = ['Tüm yıllar', for (final y in v.yillar(DateTime.now().year)) '$y'];
        final yil = int.tryParse(_yil);
        final kisiler = v.sahipler();
        return [
          SecimSatiri(
            secenekler: yillar,
            secili: yillar.contains(_yil) ? _yil : yillar[1],
            onSec: (s) => setState(() => _yil = s),
          ),
          const SizedBox(height: 10),
          for (final k in kisiler)
            _kisiKarti(context, v, v.sahipOzet(k, yil: yil)),
          const Panel(
            child: Text(
              'Kişiler Profil → Ayarlar → Hesap sahipleri bölümünden eklenir. '
              'Her tarlada "Kim ekiyor" ya da ortaklık payları seçilir; giderler, satışlar ve '
              'destekler buna göre kişilere bölünür.',
              style: yaziSoluk,
            ),
          ),
        ];
      },
    );
  }

  Widget _kisiKarti(BuildContext context, Veriler v, SahipOzet o) {
    final ben = o.sahip == Veriler.ben;
    final kalemler = o.kalemler.entries.toList()
      ..sort((a, b) => b.value.tutar.compareTo(a.value.tutar));
    final h = o.hesaplasma;
    return Panel(
      baslik: '${ben ? '🧑‍🌾' : '👤'} ${o.sahip}',
      eylem: Text('${o.tarlaSayisi} tarla · ${sayi(o.dekar)} da', style: yaziSoluk),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Satir('Masraf', tl0(o.masraf)),
          if (o.dekar > 0 && o.masraf > 0)
            Satir('Dekar başı masraf', tl0(o.masraf / o.dekar), renk: Renk.altin),
          Satir('Hasat', '${sayi(o.hasatKg)} kg'),
          Satir('Satış', tl0(o.satis)),
          if (o.destek > 0) Satir('Destekler', tl0(o.destek), renk: Renk.turkuaz),
          if (o.kiraGeliri > 0) Satir('Kira geliri', tl0(o.kiraGeliri)),
          Satir('Kâr', tl0(o.kar), kalin: true, renk: o.kar >= 0 ? Renk.yesil : Renk.kirmizi),
          if (kalemler.isNotEmpty) ...[
            const Divider(height: 18),
            const Text('Kullanılan malzeme ve masraflar', style: yaziSoluk),
            const SizedBox(height: 4),
            for (final k in kalemler)
              Satir(
                  '${giderSimge[k.key] ?? '📦'} ${k.key}'
                  '${k.value.miktar > 0 ? ' · ${sayi(k.value.miktar)} ${k.value.birim}' : ''}',
                  tl0(k.value.tutar)),
          ],
          if (o.ekimler.isNotEmpty) ...[
            const Divider(height: 18),
            for (var i = 0; i < o.ekimler.length; i++)
              InkWell(
                onTap: () => git(context, EkimDetay(durum: widget.durum, ekimId: o.ekimler[i].ekim.id)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(urunSimge(o.ekimler[i].ekim.s('urun')),
                          style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            '${o.ekimler[i].ekim.t('yil')} · ${o.ekimler[i].ekim.s('urun')} · '
                            '${v.tarlaAdi(o.ekimler[i].ekim.s('tarlaId'))}'
                            '${o.paylar[i] < 0.999 ? ' (%${(o.paylar[i] * 100).round()})' : ''}',
                            style: const TextStyle(color: Renk.yazi)),
                      ),
                      Text(tl0(o.ekimler[i].kar * o.paylar[i]),
                          style: TextStyle(
                              color: o.ekimler[i].kar >= 0 ? Renk.yesil : Renk.kirmizi)),
                    ],
                  ),
                ),
              ),
          ],
          if (!ben) ...[
            const Divider(height: 18),
            Row(
              children: [
                const Expanded(child: Text('Alacak / verecek', style: yaziSoluk)),
                TextButton(
                  onPressed: () => aileHareketFormu(context, widget.durum, kisi: o.sahip),
                  child: const Text('+ Ekle'),
                ),
              ],
            ),
            for (final h in v.aileHareketleri.where((h) => h.s('kisi') == o.sahip).take(8))
              InkWell(
                onTap: () => aileHareketFormu(context, widget.durum, kisi: o.sahip, hareket: h),
                child: Satir(
                    '${tarih(h.t('tarih'))} · ${h.s('yon') == 'o_verdi' ? '${o.sahip} verdi' : 'Ben verdim'}'
                    '${h.s('aciklama').isEmpty ? '' : ' · ${h.s('aciklama')}'}',
                    tl0(h.n('tutar')),
                    renk: h.s('yon') == 'o_verdi' ? Renk.turuncu : Renk.yesil),
              ),
          ],
          if (!ben && (o.masraf > 0 || o.tahsil > 0 || o.destekDuzeltme != 0 || o.onunVerdigi > 0 || o.benimVerdigim > 0)) ...[
            const Divider(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Renk.zeminAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: h >= 0 ? Renk.turuncu : Renk.yesil, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Hesaplaşma', style: yaziKalin),
                  const SizedBox(height: 4),
                  Satir('Sizin yaptığınız masraf', tl0(o.masraf)),
                  Satir('Satıştan sizin aldığınız', tl0(o.tahsil)),
                  if (o.onunVerdigi > 0) Satir('${o.sahip} size verdi', tl0(o.onunVerdigi)),
                  if (o.benimVerdigim > 0) Satir('Siz ${o.sahip} için verdiniz', tl0(o.benimVerdigim)),
                  if (o.destekDuzeltme != 0)
                    Satir(
                        o.destekDuzeltme > 0
                            ? 'Size yatan, ona ait destek'
                            : 'Ona yatan, size ait destek',
                        tl0(o.destekDuzeltme.abs())),
                  const SizedBox(height: 6),
                  Text(
                    h.abs() < 1
                        ? 'Hesap denk.'
                        : (h > 0
                            ? 'Sizden alacağı: ${tl0(h)} (${o.sahip} hesabına ödenecek)'
                            : 'Size borcu: ${tl0(-h)} (${o.sahip} hesabından alınacak)'),
                    style: TextStyle(
                        color: h > 0 ? Renk.turuncu : Renk.yesil,
                        fontSize: 16,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
