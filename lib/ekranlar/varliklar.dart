import 'package:flutter/material.dart';

import '../bicim.dart';
import '../hesap.dart';
import '../modeller.dart';
import '../sabitler.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'form.dart';
import 'hesaplar.dart';
import 'ev.dart';
import 'kabuk.dart';
import 'uretim.dart';

Future<void> varlikFormu(BuildContext context, Durum durum, {Kayit? varlik}) {
  return formAc(
    context,
    baslik: varlik == null ? 'Birikim / Yatırım' : 'Düzenle',
    v: durum.v,
    baslangic: {'tur': 'Altın', 'birim': 'gram', ...?varlik?.d},
    alanlar: [
      const Alan('tur', 'Türü', tip: AlanTip.secim, secenekler: ['Altın', 'Döviz', 'Mevduat', 'Fon / Hisse', 'Diğer']),
      const Alan('ad', 'Açıklama', ipucu: 'Örn. Gram altın, USD, vadeli hesap'),
      const Alan('miktar', 'Miktar', tip: AlanTip.sayi, zorunlu: true),
      const Alan('birim', 'Birim', oneriler: ['gram', 'çeyrek', 'USD', 'EUR', '₺', 'adet']),
      const Alan('alisTutar', 'Alış tutarı (toplam)', tip: AlanTip.sayi, birim: '₺'),
      Alan('birimFiyat', 'Güncel birim fiyat', tip: AlanTip.sayi, birim: '₺',
          aciklama: 'Altında boş bırakırsanız Ayarlar\'daki gram altın fiyatı kullanılır.',
          gorunur: (d) => d['tur'] != 'Mevduat'),
      const Alan('tarih', 'Alış tarihi', tip: AlanTip.tarih),
    ],
    onKaydet: (d) async {
      if (d['tur'] == 'Mevduat' && (d['birimFiyat'] == null)) d['birimFiyat'] = 1;
      await durum.kaydet('varliklar', d, id: varlik?.id);
    },
    onSil: varlik == null ? null : () => durum.sil('varliklar', varlik.id),
  );
}

class VarliklarSayfasi extends StatelessWidget {
  const VarliklarSayfasi({super.key, required this.durum});
  final Durum durum;

  @override
  Widget build(BuildContext context) {
    return Sayfa(
      baslik: 'Varlıklarım & Ev Bütçem',
      durum: durum,
      fab: ekleButonu('Ev Gideri', () => giderFormu(context, durum, ev: true)),
      builder: (context, v) {
        final simdi = DateTime.now();
        final varlik = v.toplamVarlik();
        final alacak = v.toplamAlacak();
        final borc = v.toplamBorc();
        final ekipman = v.toplamEkipman(sahip: Veriler.ben);
        final net = varlik + ekipman + alacak - borc;
        bool buAy(Kayit x) {
          final d = DateTime.fromMillisecondsSinceEpoch(x.t('tarih'));
          return d.year == simdi.year && d.month == simdi.month;
        }

        final ayGelir = v.gelirler.where((g) => buAy(g) && g.s('tur') != 'Destek').fold(0.0, (a, g) => a + g.n('tutar')) +
            v.satislar.where(buAy).fold(0.0, (a, s) => a + v.satisHesap(s).beklenen);
        final evAy = v.giderler.where((g) => g.s('alan') == 'ev' && buAy(g)).toList();
        final ayEv = evAy.fold(0.0, (a, g) => a + g.n('tutar'));
        final ayTarla = v.giderler.where((g) => g.s('alan') != 'ev' && buAy(g)).fold(0.0, (a, g) => a + g.n('tutar'));
        final taksitler = v.hesaplar
            .where((h) => h.s('yon') != 'alacak' && h.n('taksitTutari') > 0 && v.bakiye(h) > 0)
            .fold(0.0, (a, h) => a + h.n('taksitTutari'));
        final kalan = ayGelir - ayEv - ayTarla - taksitler;
        final aylikBorcBitis = taksitler > 0 ? (borc / taksitler).ceil() : 0;
        return [
          Panel(
            baslik: 'Net Durum',
            child: Column(
              children: [
                Satir('Birikim / yatırım', tl0(varlik)),
                Satir('Malzeme / ekipman', tl0(ekipman)),
                Satir('Alacaklar', tl0(alacak)),
                Satir('Borçlar', '− ${tl0(borc)}', renk: Renk.kirmizi),
                const Divider(height: 16),
                Satir('Net', tl0(net), kalin: true, renk: net >= 0 ? Renk.yesil : Renk.kirmizi),
                if (aylikBorcBitis > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                        'Aylık ${tl0(taksitler)} taksitle borçlar yaklaşık $aylikBorcBitis ayda biter '
                        '(${ayAdi(DateTime(simdi.year, simdi.month + aylikBorcBitis).month)} '
                        '${DateTime(simdi.year, simdi.month + aylikBorcBitis).year}).',
                        style: yaziSoluk),
                  ),
              ],
            ),
          ),
          Panel(
            baslik: '${ayAdi(simdi.month)} ayı',
            child: Column(
              children: [
                Satir('Gelen para (maaş, satış, diğer)', tl0(ayGelir), renk: Renk.yesil),
                Satir('Ev giderleri', '− ${tl0(ayEv)}'),
                Satir('Tarla giderleri', '− ${tl0(ayTarla)}'),
                Satir('Taksitler', '− ${tl0(taksitler)}'),
                const Divider(height: 16),
                Satir('Ay sonu kalan', tl0(kalan),
                    kalin: true, renk: kalan >= 0 ? Renk.yesil : Renk.kirmizi),
              ],
            ),
          ),
          Panel(
            onTap: () => git(context, EvButcesiSayfasi(durum: durum)),
            child: Row(
              children: [
                const Text('🏠', style: TextStyle(fontSize: 30)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Ev Bütçem · bu ay ${tl0(ayEv)}',
                      style: yaziKalin),
                ),
                const Icon(Icons.chevron_right, color: Renk.soluk),
              ],
            ),
          ),
          Panel(
            baslik: 'Birikim / Yatırım',
            eylem: TextButton(
                onPressed: () => varlikFormu(context, durum), child: const Text('+ Ekle')),
            child: v.varliklar.isEmpty
                ? const Text('Altın, döviz, mevduat gibi birikimlerinizi ekleyin.',
                    style: yaziSoluk)
                : Column(
                    children: [
                      for (final x in v.varliklar)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Text(varlikSimge[x.s('tur')] ?? '💼',
                              style: const TextStyle(fontSize: 26)),
                          title: Text(
                              '${x.s('ad').isEmpty ? x.s('tur') : x.s('ad')} · ${sayi(x.n('miktar'))} ${x.s('birim')}',
                              style: const TextStyle(color: Renk.yazi)),
                          subtitle: x.n('alisTutar') > 0
                              ? Text(
                                  'Alış ${tl0(x.n('alisTutar'))} · ${v.varlikDegeri(x) >= x.n('alisTutar') ? 'kâr' : 'zarar'} ${tl0((v.varlikDegeri(x) - x.n('alisTutar')).abs())}',
                                  style: yaziSoluk)
                              : null,
                          trailing: Text(tl0(v.varlikDegeri(x)),
                              style: const TextStyle(
                                  color: Renk.altin, fontWeight: FontWeight.w800)),
                          onTap: () => varlikFormu(context, durum, varlik: x),
                        ),
                    ],
                  ),
          ),
          Panel(
            baslik: 'Borç türleri',
            child: Column(
              children: [
                for (final t in ['Kredi Kartı', 'Kredi', 'Kişi', 'Bayi', 'Kooperatif'])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(hesapSimge[t] ?? '📌', style: const TextStyle(fontSize: 24)),
                    title: Text(t == 'Kişi' ? 'Kişilere borçlar (altın dahil)' : t,
                        style: const TextStyle(color: Renk.yazi)),
                    trailing: Text(
                        tl0(v.hesaplar
                            .where((h) => h.s('yon') != 'alacak' && h.s('tur') == t)
                            .fold(0.0, (a, h) => a + v.bakiyeTl(h))),
                        style: const TextStyle(color: Renk.altin)),
                    onTap: () => git(context, HesaplarSayfasi(durum: durum, yon: 'borc', tur: t)),
                  ),
              ],
            ),
          ),
        ];
      },
    );
  }
}
