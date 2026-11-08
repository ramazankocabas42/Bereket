import 'package:flutter/material.dart';

import '../bicim.dart';
import '../hesap.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'ekisler.dart';
import 'form.dart';
import 'hesaplar.dart';
import 'kabuk.dart';
import 'satislar.dart';
import 'uretim.dart';
import 'varliklar.dart';

const _turSimge = {
  'Ürün satışı': '🌾',
  'Diğer satış': '🧺',
  'Maaş': '💼',
  'Destek': '🏛️',
  'Diğer gelir': '💵',
  'Tarla gideri': '🚜',
  'Ev': '🏠',
  'Araba': '🚗',
  'Borç ödemesi': '📤',
};

/// Bütün gelir ve giderler.
class DefterSayfasi extends StatefulWidget {
  const DefterSayfasi({super.key, required this.durum});
  final Durum durum;

  @override
  State<DefterSayfasi> createState() => _DefterSayfasiState();
}

class _DefterSayfasiState extends State<DefterSayfasi> {
  DateTime? _ay = DateTime(DateTime.now().year, DateTime.now().month);
  String _tur = 'Hepsi';

  Durum get durum => widget.durum;

  void _ac(DefterSatir d) {
    switch (d.koleksiyon) {
      case 'satislar':
        satisFormu(context, durum, satis: d.kayit);
      case 'gelirler':
        gelirFormu(context, durum, gelir: d.kayit);
      case 'giderler':
        giderFormu(context, durum, gider: d.kayit);
      case 'hesaplar':
        git(context, HesapDetay(durum: durum, hesapId: d.kayit.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Sayfa(
      baslik: 'Gelir - Gider',
      durum: durum,
      builder: (context, v) {
        final hepsi = v.defter();
        final ayinki = hepsi.where((d) {
          final a = _ay;
          if (a == null) return d.tarih > 0 && DateTime.fromMillisecondsSinceEpoch(d.tarih).year == DateTime.now().year;
          final t = DateTime.fromMillisecondsSinceEpoch(d.tarih);
          return t.year == a.year && t.month == a.month;
        }).toList();
        final turler = ['Hepsi', 'Gelirler', 'Giderler', ..._turSimge.keys];
        final l = ayinki.where((d) {
          if (_tur == 'Hepsi') return true;
          if (_tur == 'Gelirler') return d.tutar >= 0;
          if (_tur == 'Giderler') return d.tutar < 0;
          return d.tur == _tur;
        }).toList();
        final gelir = ayinki.where((d) => d.tutar >= 0).fold(0.0, (a, d) => a + d.tutar);
        final gider = ayinki.where((d) => d.tutar < 0).fold(0.0, (a, d) => a - d.tutar);
        final turToplam = <String, double>{};
        for (final d in ayinki) {
          turToplam[d.tur] = (turToplam[d.tur] ?? 0) + d.tutar;
        }
        final a = _ay;
        return [
          Panel(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: Renk.yazi),
                      onPressed: a == null
                          ? null
                          : () => setState(() => _ay = DateTime(a.year, a.month - 1)),
                    ),
                    Expanded(
                      child: Text(a == null ? '${DateTime.now().year} tüm yıl' : '${ayAdi(a.month)} ${a.year}',
                          textAlign: TextAlign.center, style: yaziKalin),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: Renk.yazi),
                      onPressed: a == null
                          ? null
                          : () => setState(() => _ay = DateTime(a.year, a.month + 1)),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => setState(() => _ay = _ay == null
                      ? DateTime(DateTime.now().year, DateTime.now().month)
                      : null),
                  child: Text(_ay == null ? 'Aylık göster' : 'Bütün yılı göster'),
                ),
                Row(
                  children: [
                    Expanded(child: BilgiKutu(baslik: 'Gelir', deger: tl0(gelir), renk: Renk.yesil)),
                    const SizedBox(width: 8),
                    Expanded(child: BilgiKutu(baslik: 'Gider', deger: tl0(gider), renk: Renk.kirmizi)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: BilgiKutu(
                            baslik: 'Kalan',
                            deger: tl0(gelir - gider),
                            renk: gelir >= gider ? Renk.altin : Renk.kirmizi)),
                  ],
                ),
              ],
            ),
          ),
          if (turToplam.isNotEmpty)
            Panel(
              baslik: 'Türlere göre',
              child: Column(
                children: [
                  for (final e in turToplam.entries.toList()
                    ..sort((x, y) => y.value.abs().compareTo(x.value.abs())))
                    Satir('${_turSimge[e.key] ?? ''} ${e.key}', tl0(e.value),
                        renk: e.value >= 0 ? Renk.yesil : Renk.kirmizi),
                ],
              ),
            ),
          SecimSatiri(
            secenekler: turler,
            secili: _tur,
            onSec: (s) => setState(() => _tur = s),
          ),
          const SizedBox(height: 8),
          if (l.isEmpty) const BosDurum(simge: '📒', yazi: 'Bu dönemde kayıt yok.'),
          for (final d in l)
            Panel(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              onTap: () => _ac(d),
              child: Row(
                children: [
                  Text(_turSimge[d.tur] ?? '•', style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.baslik.isEmpty ? d.tur : d.baslik,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Renk.yazi, fontWeight: FontWeight.w600)),
                        Text('${tarih(d.tarih)} · ${d.tur}', style: yaziSoluk),
                      ],
                    ),
                  ),
                  Text('${d.tutar >= 0 ? '+' : '−'}${tl0(d.tutar.abs())}',
                      style: TextStyle(
                          color: d.tutar >= 0 ? Renk.yesil : Renk.kirmizi,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
        ];
      },
    );
  }
}

/// Ev alma hedefi ve aylık birikim planı.
class EvHedefiSayfasi extends StatelessWidget {
  const EvHedefiSayfasi({super.key, required this.durum});
  final Durum durum;

  Future<void> _duzenle(BuildContext context) {
    final mevcut = durum.isletme?.ayarlar['evHedefi'];
    return formAc(
      context,
      baslik: 'Ev Alma Hedefi',
      v: durum.v,
      baslangic: {
        'pesinatYuzde': 100,
        'tarih': DateTime(DateTime.now().year + 3, DateTime.now().month).millisecondsSinceEpoch,
        if (mevcut is Map) ...{for (final e in mevcut.entries) e.key.toString(): e.value},
      },
      alanlar: const [
        Alan('fiyat', 'Evin tahmini fiyatı', tip: AlanTip.sayi, birim: '₺', zorunlu: true),
        Alan('pesinatYuzde', 'Biriktirilecek kısım', tip: AlanTip.sayi, birim: '%',
            aciklama: 'Peşin alacaksanız 100; kredinin yanında peşinat ödeyecekseniz örn. 30.'),
        Alan('tarih', 'Ne zamana kadar', tip: AlanTip.tarih),
        Alan('biriken', 'Bu iş için ayrılan birikim', tip: AlanTip.sayi, birim: '₺',
            aciklama: 'Boş bırakırsanız Varlıklarım\'daki toplam birikim sayılır.'),
      ],
      onKaydet: (d) => durum.ayarYaz('evHedefi', {
        for (final e in d.entries)
          if (e.value != null) e.key: e.value
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Sayfa(
      baslik: 'Ev Alma Hedefi',
      durum: durum,
      eylemler: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => _duzenle(context),
        ),
      ],
      builder: (context, v) {
        final h = v.evHedefi(DateTime.now());
        if (h == null) {
          return [
            BosDurum(
              simge: '🏡',
              yazi: 'Almak istediğiniz evin fiyatını ve hedef tarihi girin; her ay ne kadar '
                  'biriktirmeniz gerektiğini hesaplayayım.',
              butonYazi: 'Hedef Belirle',
              onTap: () => _duzenle(context),
            ),
          ];
        }
        return [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: Text('🏡', style: TextStyle(fontSize: 54))),
                const SizedBox(height: 8),
                Text(tl0(h.aylik),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Renk.altin, fontSize: 32, fontWeight: FontWeight.w900)),
                const Text('bu ay (ve her ay) yatırmanız gereken',
                    textAlign: TextAlign.center, style: yaziSoluk),
                const SizedBox(height: 12),
                Cubuk(
                  oran: h.oran,
                  yazi: '${tl0(h.biriken)} / ${tl0(h.gereken)}',
                ),
                const SizedBox(height: 12),
                Satir('Ev fiyatı', tl0(h.fiyat)),
                Satir('Biriktirilecek (%${sayi(h.pesinatYuzde)})', tl0(h.gereken)),
                if (h.kredi > 0) Satir('Kalan kısım (kredi)', tl0(h.kredi)),
                Satir('Şu anki birikim', tl0(h.biriken)),
                Satir('Eksik', tl0(h.eksik), kalin: true),
                Satir('Hedef tarih', '${ayAdi(h.hedef.month)} ${h.hedef.year} · ${h.kalanAy} ay'),
              ],
            ),
          ),
          Panel(
            baslik: 'Gidişat',
            kenarRengi: h.yetisir ? Renk.yesil : Renk.turuncu,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Satir('Son 3 ay ortalama aylık fazla', tl0(h.ortalamaFazla),
                    renk: h.ortalamaFazla >= 0 ? Renk.yesil : Renk.kirmizi),
                Satir('Gereken aylık', tl0(h.aylik)),
                const SizedBox(height: 8),
                Text(
                  h.eksik <= 0
                      ? '🎉 Hedef tutara ulaştınız.'
                      : (h.yetisir
                          ? '✅ Bu gidişle hedefe yetişirsiniz${h.tahminiAy != null ? ' (yaklaşık ${h.tahminiAy} ayda)' : ''}.'
                          : (h.tahminiAy != null
                              ? '⚠ Bu gidişle yaklaşık ${h.tahminiAy} ay sürer. Hedef tarihe yetişmek için ayda ${tl0(h.aylik - h.ortalamaFazla)} daha ayırmanız gerekiyor.'
                              : '⚠ Son aylarda gider gelirden fazla. Önce aylık fazlanın artı olması gerekiyor.')),
                  style: TextStyle(
                      color: h.yetisir || h.eksik <= 0 ? Renk.yesil : Renk.turuncu,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ortalama fazla; satışlar, maaş, destekler ve diğer gelirlerden tarla, ev, araba '
                  'giderleri ve borç ödemeleri düşülerek hesaplanır.',
                  style: yaziSoluk,
                ),
              ],
            ),
          ),
          Buton(
            yazi: 'Birikim Ekle (altın, mevduat...)',
            renk: ButonRenk.yesil,
            onTap: () => varlikFormu(context, durum),
          ),
        ];
      },
    );
  }
}
