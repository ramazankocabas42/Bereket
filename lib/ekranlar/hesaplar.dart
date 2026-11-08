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

String _birimYazi(Kayit h, double x) =>
    h.s('birim') == 'gram' ? '${sayi(x)} gr altın' : tl0(x);

Future<void> hesapFormu(BuildContext context, Durum durum,
    {Kayit? hesap, String yon = 'borc', String? tur}) {
  final borc = (hesap?.s('yon') ?? yon) != 'alacak';
  return formAc(
    context,
    baslik: hesap == null ? (borc ? 'Yeni Borç Hesabı' : 'Yeni Alacak') : 'Hesabı Düzenle',
    v: durum.v,
    baslangic: {
      'tur': tur ?? (borc ? 'Bayi' : 'Kişi'),
      'birim': 'TL',
      ...?hesap?.d,
    },
    alanlar: [
      Alan('ad', borc ? 'Kime borçlusunuz' : 'Kimden alacaklısınız',
          zorunlu: true,
          oneriler: const [
            'Ereğli Pancar Ekicileri Kooperatifi',
            'Ereğli Şeker Fabrikası',
            'Tarım Kredi Kooperatifi',
            'Ziraat Bankası',
            'Milli Emlak',
          ]),
      const Alan('tur', 'Türü', tip: AlanTip.secim, secenekler: hesapTurleri),
      const Alan('birim', 'Birim', tip: AlanTip.secim, secenekler: ['TL', 'gram'],
          aciklama: 'Altın borcu/alacağı için "gram" seçin; değeri altın fiyatıyla hesaplanır.'),
      if (hesap == null)
        Alan('acilis', borc ? 'Şu anki borç' : 'Şu anki alacak', tip: AlanTip.sayi),
      const Alan('vade', 'Son ödeme / vade tarihi', tip: AlanTip.tarih),
      const Alan('taksitSayisi', 'Taksit sayısı', tip: AlanTip.sayi,
          aciklama: 'Kredi, kredi kartı, ecrimisil taksitleri için.'),
      const Alan('taksitTutari', 'Taksit tutarı', tip: AlanTip.sayi, birim: '₺'),
      const Alan('odemeGunu', 'Ayın kaçında ödeniyor', tip: AlanTip.sayi),
      const Alan('not', 'Not', tip: AlanTip.uzun),
    ],
    onKaydet: (d) async {
      final acilis = _n(d.remove('acilis'));
      d['yon'] = borc ? 'borc' : 'alacak';
      if (hesap == null) {
        d['hareketler'] = [
          if (acilis > 0)
            {
              'tip': 'artis',
              'tutar': acilis,
              'ac': 'Açılış',
              't': DateTime.now().millisecondsSinceEpoch,
              'k': Veri.yeniKod(),
            }
        ];
      } else {
        d.remove('hareketler');
      }
      await durum.kaydet('hesaplar', d, id: hesap?.id);
    },
    onSil: hesap == null ? null : () => durum.sil('hesaplar', hesap.id),
  );
}

Future<void> hareketFormu(BuildContext context, Durum durum, Kayit hesap, String tip) {
  final borc = hesap.s('yon') != 'alacak';
  final baslik = tip == 'odeme'
      ? (borc ? 'Ödeme Yap' : 'Tahsilat')
      : (borc ? 'Borç Ekle' : 'Alacak Ekle');
  return formAc(
    context,
    baslik: baslik,
    v: durum.v,
    baslangic: {
      't': DateTime.now().millisecondsSinceEpoch,
      if (tip == 'odeme' && hesap.n('taksitTutari') > 0) 'tutar': hesap.n('taksitTutari'),
    },
    alanlar: [
      Alan('tutar', 'Tutar', tip: AlanTip.sayi,
          birim: hesap.s('birim') == 'gram' ? 'gram' : '₺', zorunlu: true),
      const Alan('t', 'Tarih', tip: AlanTip.tarih),
      Alan('ac', 'Açıklama',
          oneriler: tip == 'odeme'
              ? const ['Taksit', 'Nakit', 'Havale', 'Pancar bedelinden mahsup']
              : const ['Gübre', 'Tohum', 'İlaç', 'Mazot', 'Nakit avans', 'Faiz']),
    ],
    onKaydet: (d) => Veri.hareketEkle(durum.iid, hesap.id,
        tip: tip,
        tutar: _n(d['tutar']),
        aciklama: (d['ac'] ?? '').toString(),
        tarih: _n(d['t']).toInt()),
  );
}

class HesaplarSayfasi extends StatefulWidget {
  const HesaplarSayfasi({super.key, required this.durum, required this.yon, this.tur});
  final Durum durum;
  final String yon;
  final String? tur;

  @override
  State<HesaplarSayfasi> createState() => _HesaplarSayfasiState();
}

class _HesaplarSayfasiState extends State<HesaplarSayfasi> {
  late String _tur = widget.tur ?? 'Hepsi';
  bool _kapananlar = false;

  Durum get durum => widget.durum;
  bool get borc => widget.yon != 'alacak';

  @override
  Widget build(BuildContext context) {
    return Sayfa(
      baslik: borc ? 'Borçlarım' : 'Alacaklarım',
      durum: durum,
      fab: ekleButonu(borc ? 'Borç Ekle' : 'Alacak Ekle',
          () => hesapFormu(context, durum, yon: widget.yon, tur: _tur == 'Hepsi' ? null : _tur)),
      builder: (context, v) {
        final simdi = DateTime.now().millisecondsSinceEpoch;
        final tumu = v.hesaplar
            .where((h) => (h.s('yon') != 'alacak') == borc)
            .toList();
        final l = tumu
            .where((h) => _tur == 'Hepsi' || h.s('tur') == _tur)
            .where((h) => _kapananlar || v.bakiye(h).abs() > 0.5)
            .toList()
          ..sort((a, b) {
            final av = a.t('vade') > 0 ? a.t('vade') : 1 << 62;
            final bv = b.t('vade') > 0 ? b.t('vade') : 1 << 62;
            return av.compareTo(bv);
          });
        final toplam = l.fold(0.0, (a, h) => a + v.bakiyeTl(h));
        final gecikmis = l
            .where((h) => h.t('vade') > 0 && h.t('vade') < simdi && v.bakiye(h) > 0)
            .fold(0.0, (a, h) => a + v.bakiyeTl(h));
        final turler = ['Hepsi', ...{for (final h in tumu) h.s('tur')}.where((x) => x.isNotEmpty)];
        if (widget.tur != null && !turler.contains(widget.tur)) turler.add(widget.tur!);
        final satisAlacak = borc
            ? 0.0
            : v.satislar.fold(0.0, (a, s) => a + v.satisHesap(s).kalan(tahsilToplam(s)));
        return [
          Panel(
            kenarRengi: gecikmis > 0 ? Renk.kirmizi : null,
            child: Row(
              children: [
                Text(borc ? '🏦' : '📥', style: const TextStyle(fontSize: 46)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tl0(toplam + satisAlacak),
                          style: TextStyle(
                              color: borc ? Renk.altin : Renk.yesil,
                              fontSize: 26,
                              fontWeight: FontWeight.w900)),
                      Text(borc ? 'Toplam borç' : 'Toplam alacak', style: yaziSoluk),
                      if (!borc && satisAlacak > 0)
                        Text('(${tl0(satisAlacak)} tahsil edilmemiş satışlardan)',
                            style: yaziSoluk),
                      if (gecikmis > 0) ...[
                        const SizedBox(height: 6),
                        Etiket('⚠ Vadesi geçen ${tl0(gecikmis)}', renk: Renk.kirmizi),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SecimSatiri(
            secenekler: turler,
            secili: turler.contains(_tur) ? _tur : 'Hepsi',
            onSec: (s) => setState(() => _tur = s),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _kapananlar,
            onChanged: (b) => setState(() => _kapananlar = b),
            title: const Text('Kapanmış hesapları da göster',
                style: TextStyle(color: Renk.soluk, fontSize: 14)),
          ),
          if (l.isEmpty)
            BosDurum(
              simge: borc ? '✅' : '📭',
              yazi: borc ? 'Açık borç yok.' : 'Açık alacak yok.',
            ),
          for (final h in l) _kart(context, v, h, simdi),
        ];
      },
    );
  }

  Widget _kart(BuildContext context, Veriler v, Kayit h, int simdi) {
    final b = v.bakiye(h);
    final gecikti = h.t('vade') > 0 && h.t('vade') < simdi && b > 0;
    final taksit = h.n('taksitSayisi');
    final odenenTaksit = h.liste('hareketler').where((x) => x['tip'] == 'odeme').length;
    return Panel(
      padding: const EdgeInsets.all(14),
      kenarRengi: gecikti ? Renk.kirmizi : null,
      onTap: () => git(context, HesapDetay(durum: durum, hesapId: h.id)),
      child: Row(
        children: [
          Text(hesapSimge[h.s('tur')] ?? '📌', style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.s('ad'), style: yaziKalin),
                Text(
                    [
                      h.s('tur'),
                      if (h.t('vade') > 0) 'vade ${tarih(h.t('vade'))}',
                      if (taksit > 0) '$odenenTaksit/${taksit.toInt()} taksit',
                      if (h.n('odemeGunu') > 0) 'her ayın ${h.n('odemeGunu').toInt()}\'i',
                    ].join(' · '),
                    style: yaziSoluk),
                if (gecikti) ...[
                  const SizedBox(height: 4),
                  const Etiket('Ödeme gecikti', renk: Renk.kirmizi, simge: '⚠'),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_birimYazi(h, b),
                  style: TextStyle(
                      color: b > 0 ? (borc ? Renk.altin : Renk.yesil) : Renk.soluk,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              if (h.s('birim') == 'gram' && (v.isletme?.altinGram ?? 0) > 0)
                Text(tl0(v.bakiyeTl(h)), style: yaziSoluk),
            ],
          ),
        ],
      ),
    );
  }
}

class HesapDetay extends StatelessWidget {
  const HesapDetay({super.key, required this.durum, required this.hesapId});
  final Durum durum;
  final String hesapId;

  @override
  Widget build(BuildContext context) {
    return Sayfa(
      baslik: 'Hesap',
      durum: durum,
      builder: (context, v) {
        final h = v.bul('hesaplar', hesapId);
        if (h == null) return [const BosDurum(simge: '🗑️', yazi: 'Hesap silinmiş.')];
        final borc = h.s('yon') != 'alacak';
        final hareketler = [...h.liste('hareketler')]
          ..sort((a, b) => _n(b['t']).compareTo(_n(a['t'])));
        final b = v.bakiye(h);
        return [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(hesapSimge[h.s('tur')] ?? '📌', style: const TextStyle(fontSize: 40)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h.s('ad'), style: yaziKalin),
                          Text(h.s('tur'), style: yaziSoluk),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Renk.soluk),
                      onPressed: () => hesapFormu(context, durum, hesap: h),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(_birimYazi(h, b),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: borc ? Renk.altin : Renk.yesil,
                        fontSize: 30,
                        fontWeight: FontWeight.w900)),
                Text(borc ? 'Kalan borç' : 'Kalan alacak',
                    textAlign: TextAlign.center, style: yaziSoluk),
                if (h.s('birim') == 'gram')
                  Text(
                      (v.isletme?.altinGram ?? 0) > 0
                          ? '≈ ${tl0(v.bakiyeTl(h))} (gram ${tl(v.isletme!.altinGram)})'
                          : 'Altın fiyatını Profil → Ayarlar\'dan girin.',
                      textAlign: TextAlign.center,
                      style: yaziSoluk),
                if (h.n('taksitTutari') > 0 && b > 0)
                  Text(
                      'Taksit ${tl0(h.n('taksitTutari'))} · kalan yaklaşık ${(b / h.n('taksitTutari')).ceil()} taksit',
                      textAlign: TextAlign.center,
                      style: yaziSoluk),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Buton(
                        yazi: borc ? 'Borç Ekle' : 'Alacak Ekle',
                        renk: ButonRenk.turuncu,
                        onTap: () => hareketFormu(context, durum, h, 'artis'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Buton(
                        yazi: borc ? 'Ödeme Yap' : 'Tahsilat',
                        renk: ButonRenk.yesil,
                        onTap: () => hareketFormu(context, durum, h, 'odeme'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Panel(
            baslik: 'Hareketler',
            child: hareketler.isEmpty
                ? const Text('Hareket yok.', style: yaziSoluk)
                : Column(
                    children: [
                      for (final x in hareketler)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Text(x['tip'] == 'odeme' ? '⬇️' : '⬆️',
                              style: const TextStyle(fontSize: 22)),
                          title: Text(
                              (x['ac'] ?? '').toString().isEmpty
                                  ? (x['tip'] == 'odeme' ? 'Ödeme' : 'Borç')
                                  : x['ac'].toString(),
                              style: const TextStyle(color: Renk.yazi)),
                          subtitle: Text(tarih(_n(x['t']).toInt()), style: yaziSoluk),
                          trailing: Text(
                              '${x['tip'] == 'odeme' ? '−' : '+'} ${_birimYazi(h, _n(x['tutar']))}',
                              style: TextStyle(
                                  color: x['tip'] == 'odeme' ? Renk.yesil : Renk.altin,
                                  fontWeight: FontWeight.w800)),
                          onLongPress: () async {
                            final evet = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Hareket silinsin mi?'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Vazgeç')),
                                  FilledButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Sil')),
                                ],
                              ),
                            );
                            if (evet == true) {
                              try {
                                await Veri.hareketSil(durum.iid, h.id, x);
                              } catch (e) {
                                if (context.mounted) bildir(context, hataYazisi(e));
                              }
                            }
                          },
                        ),
                    ],
                  ),
          ),
          const Text('Bir hareketi silmek için üzerine uzun basın.',
              textAlign: TextAlign.center, style: yaziSoluk),
        ];
      },
    );
  }
}
