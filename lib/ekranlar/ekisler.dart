import 'package:flutter/material.dart';

import '../bicim.dart';
import '../hesap.dart';
import '../modeller.dart';
import '../sabitler.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'form.dart';
import 'kabuk.dart';
import 'satislar.dart';

double _n(Object? v) => v is num ? v.toDouble() : 0;

Future<void> isyeriFormu(BuildContext context, Durum durum, {Kayit? isyeri}) {
  return formAc(
    context,
    baslik: isyeri == null ? 'İş Yeri Ekle' : 'İş Yerini Düzenle',
    v: durum.v,
    baslangic: {'gun': 5, ...?isyeri?.d},
    alanlar: const [
      Alan('ad', 'İş yeri', zorunlu: true, oneriler: ['Panagro A.Ş.']),
      Alan('gorev', 'Göreviniz'),
      Alan('maas', 'Aylık net maaş', tip: AlanTip.sayi, birim: '₺',
          aciklama: 'Bu tutar sadece bu telefonda değil, işletmedeki herkese görünür.'),
      Alan('gun', 'Maaş günü (ayın kaçı)', tip: AlanTip.sayi),
      Alan('banka', 'Yattığı banka', tip: AlanTip.secim, secenekler: bankalar),
    ],
    onKaydet: (d) => durum.kaydet('isyerleri', d, id: isyeri?.id),
    onSil: isyeri == null ? null : () => durum.sil('isyerleri', isyeri.id),
  );
}

/// Maaş, prim, destek, kira geliri ve diğer gelirler.
Future<void> gelirFormu(BuildContext context, Durum durum,
    {Kayit? gelir, String? tur, String? isyeriId}) {
  final v = durum.v;
  final isyerleri = {for (final i in v.isyerleri) i.s('ad'): i};
  final bas = <String, dynamic>{
    'tur': tur ?? 'Diğer',
    'tarih': DateTime.now().millisecondsSinceEpoch,
    'yil': DateTime.now().year,
    'yatan': Veriler.ben,
    ...?gelir?.d,
  };
  final iid = isyeriId ?? gelir?.s('isyeriId') ?? '';
  for (final e in isyerleri.entries) {
    if (e.value.id == iid) {
      bas['isyeri'] = e.key;
      bas['tutar'] ??= e.value.n('maas') > 0 ? e.value.n('maas') : null;
      bas['banka'] ??= e.value.s('banka');
    }
  }
  bool maas(Map<String, dynamic> d) => d['tur'] == 'Maaş' || d['tur'] == 'Prim / İkramiye';
  bool destek(Map<String, dynamic> d) => d['tur'] == 'Destek';
  return formAc(
    context,
    baslik: gelir == null ? 'Gelir Ekle' : 'Geliri Düzenle',
    v: v,
    baslangic: bas,
    alanlar: [
      const Alan('tur', 'Gelir türü', tip: AlanTip.secim, secenekler: gelirTurleri),
      if (isyerleri.isNotEmpty)
        Alan('isyeri', 'İş yeri', tip: AlanTip.secim,
            secenekler: isyerleri.keys.toList(), gorunur: maas),
      Alan('destekTuru', 'Destek türü', tip: AlanTip.secim,
          secenekler: destekTurleri, gorunur: destek),
      Alan('kaynak', 'Kimden / açıklama', gorunur: (d) => !maas(d)),
      const Alan('tutar', 'Tutar', tip: AlanTip.sayi, birim: '₺', zorunlu: true),
      const Alan('tarih', 'Yattığı tarih', tip: AlanTip.tarih),
      Alan('yil', 'Hangi sezonun desteği', tip: AlanTip.yil, gorunur: destek),
      Alan('tarlaIds', 'Hangi tarlalar için', tip: AlanTip.tarlalar, gorunur: destek,
          aciklama: 'Alan bazlı destek (mazot-gübre) arazi sahibine, ürün bazlı destek o yıl ekene '
              'dekarına göre yazılır.'),
      Alan('yatan', 'Kimin hesabına yattı', tip: AlanTip.secim,
          secenekler: v.sahipler(), gorunur: destek),
      const Alan('banka', 'Banka', tip: AlanTip.secim, secenekler: bankalar),
    ],
    onKaydet: (d) async {
      final ad = (d.remove('isyeri') ?? '').toString();
      d['isyeriId'] = maas(d) ? (isyerleri[ad]?.id ?? '') : '';
      if (!destek(d)) {
        d['yil'] = DateTime.fromMillisecondsSinceEpoch(_n(d['tarih']).toInt()).year;
      }
      await durum.kaydet('gelirler', d, id: gelir?.id);
    },
    onSil: gelir == null ? null : () => durum.sil('gelirler', gelir.id),
  );
}

class EkIslerSayfasi extends StatelessWidget {
  const EkIslerSayfasi({super.key, required this.durum});
  final Durum durum;

  @override
  Widget build(BuildContext context) {
    return Sayfa(
      baslik: 'Ek İşler',
      durum: durum,
      fab: ekleButonu('Gelir Ekle', () => gelirFormu(context, durum)),
      builder: (context, v) {
        final simdi = DateTime.now();
        final yil = simdi.year;
        final gelirler = v.gelirler.where((g) => g.yil == yil).toList()
          ..sort((a, b) => b.t('tarih').compareTo(a.t('tarih')));
        final digerSatis = v.satislar.where((s) => s.s('tur') == 'diger' && s.yil == yil).toList()
          ..sort((a, b) => b.t('tarih').compareTo(a.t('tarih')));
        final buAy = v.gelirler.where((g) {
          final d = DateTime.fromMillisecondsSinceEpoch(g.t('tarih'));
          return d.year == yil && d.month == simdi.month && g.s('tur') != 'Destek';
        }).fold(0.0, (a, g) => a + g.n('tutar'));
        final yillik = gelirler.where((g) => g.s('tur') != 'Destek').fold(0.0, (a, g) => a + g.n('tutar')) +
            digerSatis.fold(0.0, (a, s) => a + v.satisHesap(s).beklenen);
        final destekler = gelirler.where((g) => g.s('tur') == 'Destek').toList();
        return [
          Panel(
            child: Column(
              children: [
                const Text('💼', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: BilgiKutu(baslik: 'Bu ay ek gelir', deger: tl0(buAy))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: BilgiKutu(baslik: '$yil toplam', deger: tl0(yillik), renk: Renk.yesil)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: Buton(
                            yazi: 'Gelir Ekle',
                            renk: ButonRenk.yesil,
                            onTap: () => gelirFormu(context, durum))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Buton(
                            yazi: 'İş Yeri Ekle', onTap: () => isyeriFormu(context, durum))),
                  ],
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Aktif İşlerim', style: yaziKalin),
          ),
          if (v.isyerleri.isEmpty)
            Panel(
              onTap: () => isyeriFormu(context, durum),
              child: const Column(
                children: [
                  Text('💼⏱', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 6),
                  Text('İş yeri ekle (maaş günü ve tutarı)', style: yaziSoluk),
                ],
              ),
            ),
          for (final i in v.isyerleri) _isyeriKarti(context, v, i, simdi),
          Panel(
            baslik: 'Diğer satışlar',
            eylem: TextButton(
              onPressed: () => satisFormu(context, durum, diger: true),
              child: const Text('+ Ekle'),
            ),
            child: digerSatis.isEmpty
                ? const Text('Saman, balya, hurda, makine kirası gibi satışlar burada.',
                    style: yaziSoluk)
                : Column(
                    children: [
                      for (final s in digerSatis)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(s.s('aciklama'), style: const TextStyle(color: Renk.yazi)),
                          subtitle: Text(
                              '${tarih(s.t('tarih'))}${s.s('alici').isEmpty ? '' : ' · ${s.s('alici')}'}',
                              style: yaziSoluk),
                          trailing: Text(tl0(v.satisHesap(s).beklenen),
                              style: const TextStyle(
                                  color: Renk.yesil, fontWeight: FontWeight.w800)),
                          onTap: () => satisFormu(context, durum, satis: s),
                        ),
                    ],
                  ),
          ),
          Panel(
            baslik: 'Destekler ($yil)',
            eylem: TextButton(
              onPressed: () => gelirFormu(context, durum, tur: 'Destek'),
              child: const Text('+ Ekle'),
            ),
            child: destekler.isEmpty
                ? const Text('Mazot-gübre, fark ödemesi gibi devlet destekleri.',
                    style: yaziSoluk)
                : Column(
                    children: [
                      for (final g in destekler)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(g.s('destekTuru'), style: const TextStyle(color: Renk.yazi)),
                          subtitle: Text(
                              '${tarih(g.t('tarih'))} · ${g.s('yatan')} hesabına · '
                              '${v.destekSahipPaylari(g).entries.map((e) => '${e.key} ${tl0(e.value)}').join(', ')}',
                              style: yaziSoluk),
                          trailing: Text(tl0(g.n('tutar')),
                              style: const TextStyle(
                                  color: Renk.turkuaz, fontWeight: FontWeight.w800)),
                          onTap: () => gelirFormu(context, durum, gelir: g),
                        ),
                    ],
                  ),
          ),
          Panel(
            baslik: 'Gelir kayıtları ($yil)',
            child: gelirler.where((g) => g.s('tur') != 'Destek').isEmpty
                ? const Text('Kayıt yok.', style: yaziSoluk)
                : Column(
                    children: [
                      for (final g in gelirler.where((g) => g.s('tur') != 'Destek'))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              g.s('tur') == 'Maaş'
                                  ? 'Maaş · ${v.bul('isyerleri', g.s('isyeriId'))?.s('ad') ?? ''}'
                                  : '${g.s('tur')}${g.s('kaynak').isEmpty ? '' : ' · ${g.s('kaynak')}'}',
                              style: const TextStyle(color: Renk.yazi)),
                          subtitle: Text(
                              '${tarih(g.t('tarih'))}${g.s('banka').isEmpty ? '' : ' · ${g.s('banka')}'}',
                              style: yaziSoluk),
                          trailing: Text(tl0(g.n('tutar')),
                              style: const TextStyle(
                                  color: Renk.yesil, fontWeight: FontWeight.w800)),
                          onTap: () => gelirFormu(context, durum, gelir: g),
                        ),
                    ],
                  ),
          ),
        ];
      },
    );
  }

  Widget _isyeriKarti(BuildContext context, Veriler v, Kayit i, DateTime simdi) {
    final d = v.maasDurum(i, simdi);
    final maaslar = <int, double>{};
    for (final g in v.gelirler) {
      if (g.s('isyeriId') == i.id && g.s('tur') == 'Maaş') {
        maaslar[g.yil] = (maaslar[g.yil] ?? 0) + g.n('tutar');
      }
    }
    final yillar = maaslar.keys.toList()..sort();
    return Panel(
      padding: const EdgeInsets.all(14),
      onTap: () => isyeriFormu(context, durum, isyeri: i),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('🏢', style: TextStyle(fontSize: 36)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.s('ad'), style: yaziKalin),
                    Text(i.s('gorev'), style: yaziSoluk),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (i.n('maas') > 0)
                    Text(tl0(i.n('maas')),
                        style: const TextStyle(color: Renk.altin, fontWeight: FontWeight.w800)),
                  Text('her ayın ${i.t('gun')}\'i', style: yaziSoluk),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              switch (d) {
                MaasDurum.yatti => const Etiket('Bu ayın maaşı yattı', renk: Renk.yesil, simge: '✔'),
                MaasDurum.bekleniyor => const Etiket('Bekleniyor', renk: Renk.mavi, simge: '⏳'),
                MaasDurum.gecikti => const Etiket('Maaş henüz yatmadı', renk: Renk.kirmizi, simge: '⚠'),
              },
              const Spacer(),
              if (d != MaasDurum.yatti)
                TextButton(
                  onPressed: () => gelirFormu(context, durum, tur: 'Maaş', isyeriId: i.id),
                  child: const Text('Yattı'),
                ),
            ],
          ),
          if (yillar.length > 1) ...[
            const SizedBox(height: 6),
            Text(
                yillar.map((y) => '$y: ${kisaTl(maaslar[y]!)}').join('  ·  '),
                style: yaziSoluk),
          ],
          const SizedBox(height: 4),
          const Text(
              'Garanti BBVA bildiriminden otomatik "yattı" işaretleme sonraki sürümde gelecek.',
              style: TextStyle(color: Renk.gri, fontSize: 12)),
        ],
      ),
    );
  }
}
