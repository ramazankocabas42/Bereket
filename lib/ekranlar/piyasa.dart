import 'package:flutter/material.dart';

import '../bicim.dart';
import '../hesap.dart';
import '../modeller.dart';
import '../sabitler.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'form.dart';
import 'kabuk.dart';

double _n(Object? v) => v is num ? v.toDouble() : 0;

/// Borsa / TMO / fabrika fiyatı girişi.
Future<void> fiyatFormu(BuildContext context, Durum durum,
    {Kayit? fiyat, String? urun, String? yer}) {
  return formAc(
    context,
    baslik: fiyat == null ? 'Fiyat Gir' : 'Fiyatı Düzenle',
    v: durum.v,
    baslangic: {
      'tarih': DateTime.now().millisecondsSinceEpoch,
      'yer': yer ?? borsalar.first,
      if (urun != null) 'urun': urun,
      ...?fiyat?.d,
    },
    alanlar: [
      const Alan('yer', 'Nerede', tip: AlanTip.secim, secenekler: satisYerleri),
      Alan('urun', 'Ürün', tip: AlanTip.secim,
          secenekler: [for (final u in urunler) u.ad], zorunlu: true),
      const Alan('fiyat', 'Fiyat', tip: AlanTip.sayi, birim: '₺/kg', zorunlu: true,
          aciklama: 'Borsada ortalama ya da en yüksek fiyat; TMO için ton fiyatı ÷ 1000.'),
      const Alan('enDusuk', 'En düşük', tip: AlanTip.sayi, birim: '₺/kg'),
      const Alan('enYuksek', 'En yüksek', tip: AlanTip.sayi, birim: '₺/kg'),
      const Alan('tarih', 'Tarih', tip: AlanTip.tarih),
    ],
    onKaydet: (d) => durum.kaydet('fiyatlar', d, id: fiyat?.id),
    onSil: fiyat == null ? null : () => durum.sil('fiyatlar', fiyat.id),
  );
}

class PiyasaSayfasi extends StatefulWidget {
  const PiyasaSayfasi({super.key, required this.durum, this.urun});
  final Durum durum;
  final String? urun;

  @override
  State<PiyasaSayfasi> createState() => _PiyasaSayfasiState();
}

class _PiyasaSayfasiState extends State<PiyasaSayfasi> {
  late String _urun = widget.urun ?? 'Buğday';
  String _tarlaId = '';
  double? _kg;

  Durum get durum => widget.durum;

  Future<void> _tmoEkle() async {
    // TMO 2026 hububat alım fiyatları (2. grup, ton başına):
    // buğday 16.500 ₺, arpa 12.750 ₺ (2 Haziran 2026'da açıklandı).
    final t = DateTime(2026, 6, 2, 12).millisecondsSinceEpoch;
    try {
      for (final e in {
        'Buğday': 16.5,
        'Arpa': 12.75,
      }.entries) {
        await durum.kaydet('fiyatlar', {'yer': 'TMO', 'urun': e.key, 'fiyat': e.value, 'tarih': t});
      }
      if (mounted) bildir(context, 'TMO 2026 buğday ve arpa fiyatları eklendi.');
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    }
  }

  Future<void> _kmGir(Kayit tarla, String yer, double eski) async {
    final s = await metinSor(context, '${durum.v.tarlaAdi(tarla.id)} → $yer kaç km?',
        baslangic: eski > 0 ? girdi(eski) : '', sayi: true);
    final km = sayiOku(s);
    if (km == null) return;
    final mesafe = {...tarla.m('mesafe'), yer: km};
    try {
      await durum.kaydet('tarlalar', {'mesafe': mesafe}, id: tarla.id);
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Sayfa(
      baslik: 'Piyasa Durumları',
      durum: durum,
      fab: ekleButonu('Fiyat Gir', () => fiyatFormu(context, durum, urun: _urun)),
      builder: (context, v) {
        final takip = <String>{
          'Buğday', 'Arpa', 'Mısır', 'Şeker Pancarı',
          for (final e in v.ekimler) e.s('urun'),
          for (final f in v.fiyatlar) f.s('urun'),
        }.where((x) => x.isNotEmpty).toList();
        if (!takip.contains(_urun)) takip.insert(0, _urun);
        final depoKg = v.depo().where((d) => d.urun == _urun).fold(0.0, (a, d) => a + d.kalan);
        final kg = _kg ?? (depoKg > 0 ? depoKg : 10000);
        final tarla = v.tarla(_tarlaId) ??
            (v.tarlalar.isNotEmpty ? v.tarlalar.first : null);
        final ozet = v.urunOzetleri(sahip: Veriler.ben).where((u) => u.urun == _urun);
        final kgMaliyet = ozet.isEmpty ? 0.0 : ozet.first.kgMaliyet;
        final satirlar = <(String, Kayit, SatisHesap, double)>[];
        for (final yer in satisYerleri) {
          final f = v.sonFiyat(yer, _urun);
          if (f == null) continue;
          final km = _n(tarla?.m('mesafe')[yer]);
          satirlar.add((yer, f, v.pazarHesap(yer: yer, fiyatKg: f.n('fiyat'), kg: kg, km: km), km));
        }
        satirlar.sort((a, b) => b.$3.net.compareTo(a.$3.net));
        final enIyi = satirlar.isEmpty ? null : satirlar.first.$1;
        return [
          SecimSatiri(
            secenekler: takip,
            secili: _urun,
            onSec: (s) => setState(() {
              _urun = s;
              _kg = null;
            }),
          ),
          const SizedBox(height: 10),
          Panel(
            baslik: '${urunSimge(_urun)} $_urun fiyatları',
            eylem: Text('₺/kg', style: yaziSoluk),
            child: Column(
              children: [
                for (final yer in satisYerleri)
                  if (v.sonFiyat(yer, _urun) case final f?)
                    InkWell(
                      onTap: () => fiyatFormu(context, durum, fiyat: f),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(yer,
                                      style: TextStyle(
                                          color: yer == enIyi ? Renk.altin : Renk.yazi,
                                          fontWeight: FontWeight.w700)),
                                  Text(
                                      '${tarih(f.t('tarih'))}'
                                      '${f.n('enDusuk') > 0 ? ' · ${tl(f.n('enDusuk'))} – ${tl(f.n('enYuksek'))}' : ''}',
                                      style: yaziSoluk),
                                ],
                              ),
                            ),
                            Text(tl(f.n('fiyat')),
                                style: TextStyle(
                                    color: yer == enIyi ? Renk.altin : Renk.yazi,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                if (satirlar.isEmpty)
                  const Text(
                      'Bu ürün için fiyat yok. "Fiyat Gir" ile borsa bülteninden fiyatı girin.',
                      style: yaziSoluk),
                if (kgMaliyet > 0) ...[
                  const Divider(height: 18),
                  Satir('Sizin kg maliyetiniz', tl(kgMaliyet), renk: Renk.turuncu),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Borsaların anlık bülteninden otomatik fiyat çekme bir sonraki sürümde gelecek. '
                  'Şimdilik fiyatları elle girin.',
                  style: yaziSoluk,
                ),
                if (_urun == 'Buğday' || _urun == 'Arpa')
                  if (v.sonFiyat('TMO', _urun) == null)
                    TextButton(
                        onPressed: _tmoEkle,
                        child: const Text('TMO 2026 alım fiyatlarını ekle')),
                if (_urun == 'Şeker Pancarı' && v.sonFiyat('Şeker Fabrikası', _urun) == null)
                  TextButton(
                    onPressed: () async {
                      // Türkşeker 2026-2027 alım fiyatı: 3.720 ₺/ton (kota tamamlama primi dahil).
                      try {
                        await durum.kaydet('fiyatlar', {
                          'yer': 'Şeker Fabrikası',
                          'urun': 'Şeker Pancarı',
                          'fiyat': 3.72,
                          'tarih': DateTime(2026, 10, 13, 12).millisecondsSinceEpoch,
                        });
                      } catch (e) {
                        if (context.mounted) bildir(context, hataYazisi(e));
                      }
                    },
                    child: const Text('Türkşeker 2026-2027 pancar fiyatını ekle'),
                  ),
              ],
            ),
          ),
          Panel(
            baslik: 'Nereye satsam elime ne geçer?',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (v.tarlalar.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: tarla?.id,
                    isExpanded: true,
                    dropdownColor: Renk.kartAcik,
                    decoration: const InputDecoration(labelText: 'Ürün hangi tarladan çıkıyor'),
                    items: [
                      for (final t in v.tarlalar)
                        DropdownMenuItem(value: t.id, child: Text(v.tarlaAdi(t.id))),
                    ],
                    onChanged: (s) => setState(() => _tarlaId = s ?? ''),
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          'Miktar: ${sayi(kg)} kg${depoKg > 0 && _kg == null ? ' (depodaki)' : ''}',
                          style: const TextStyle(color: Renk.yazi)),
                    ),
                    TextButton(
                      onPressed: () async {
                        final s = await metinSor(context, 'Kaç kg?',
                            baslangic: girdi(kg), sayi: true);
                        final x = sayiOku(s);
                        if (x != null && x > 0) setState(() => _kg = x);
                      },
                      child: const Text('Değiştir'),
                    ),
                  ],
                ),
                for (final (yer, f, h, km) in satirlar)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Renk.zeminAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: yer == enIyi ? Renk.yesil : Renk.cizgi, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('${yer == enIyi ? '🏆 ' : ''}$yer',
                                  style: yaziKalin),
                            ),
                            Text(tl0(h.net),
                                style: TextStyle(
                                    color: yer == enIyi ? Renk.yesil : Renk.yazi,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                        Text(
                            '${tl(f.n('fiyat'))}/kg · brüt ${tl0(h.tutar)} · kesinti ${tl0(h.kesinti)} · nakliye ${tl0(h.nakliye)}',
                            style: yaziSoluk),
                        if (yer == 'TMO')
                          const Text('TMO ödemesi teslimden sonra 45 gün içinde yapılır.',
                              style: TextStyle(color: Renk.turuncu, fontSize: 12.5)),
                        if (tarla != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => _kmGir(tarla, yer, km),
                              child: Text(km > 0
                                  ? 'Mesafe: ${sayi(km)} km (değiştir)'
                                  : 'Mesafe girilmedi (nakliye için girin)'),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  'Nakliye: ton başına km ücreti ${tl(v.isletme?.nakliyeTonKm ?? 4)}. '
                  'Kesinti oranları ve nakliye ücreti Profil → Ayarlar\'dan değişir.',
                  style: yaziSoluk,
                ),
              ],
            ),
          ),
        ];
      },
    );
  }
}
