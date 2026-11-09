import 'package:flutter/material.dart';

import '../bicim.dart';
import '../hesap.dart';
import '../modeller.dart';
import '../sms_coz.dart';
import '../servis/sms.dart';
import '../servis/veri.dart';
import '../tema.dart';

/// Telefondaki banka SMS'lerini tarar, mükerrerleri ayıklar, onayla ekler.
class BankaMesajlari extends StatefulWidget {
  const BankaMesajlari({super.key, required this.durum});
  final Durum durum;

  @override
  State<BankaMesajlari> createState() => _BankaMesajlariState();
}

class _Aday {
  _Aday(this.m, this.kayitli, this.neden) : secili = !kayitli;
  final BankaMesaji m;
  final bool kayitli;
  final String neden;
  bool secili;
}

class _BankaMesajlariState extends State<BankaMesajlari> {
  List<_Aday>? _adaylar;
  bool _taraniyor = false;
  bool _kaydediliyor = false;
  int _gun = 90;
  bool _kayitlilariGoster = false;

  Durum get durum => widget.durum;

  /// Zaten işlenmiş anahtarlar ve benzer kayıt kontrolü.
  (bool, String) _kayitliMi(Veriler v, BankaMesaji m, Set<String> anahtarlar) {
    if (anahtarlar.contains(m.anahtar)) return (true, 'Bu mesaj daha önce eklendi');
    bool yakin(int a, int b, int gun) => (a - b).abs() <= gun * 86400000;
    bool ayni(double a, double b) => (a - b).abs() < 0.01;
    switch (m.tur) {
      case SmsTuru.gelen:
        for (final g in v.gelirler) {
          if (ayni(g.n('tutar'), m.tutar) && yakin(g.t('tarih'), m.tarih, 3)) {
            return (true, 'Aynı tutarda gelir kayıtlı (${tarih(g.t('tarih'))})');
          }
        }
        for (final s in v.satislar) {
          for (final t in s.liste('tahsilatlar')) {
            final tt = t['tutar'];
            final tm = t['tarih'] ?? t['t'];
            if (tt is num && tm is num && ayni(tt.toDouble(), m.tutar) && yakin(tm.toInt(), m.tarih, 3)) {
              return (true, 'Satış ödemesi olarak kayıtlı');
            }
          }
        }
      case SmsTuru.harcama:
        for (final g in v.giderler) {
          if (ayni(g.n('tutar'), m.tutar) && yakin(g.t('tarih'), m.tarih, 3)) {
            return (true, 'Aynı tutarda gider kayıtlı (${tarih(g.t('tarih'))})');
          }
        }
      case SmsTuru.kartBorcu:
      case SmsTuru.odemeAlindi:
        final tip = m.tur == SmsTuru.kartBorcu ? 'artis' : 'odeme';
        for (final h in v.hesaplar) {
          for (final x in h.liste('hareketler')) {
            final tt = x['tutar'], tm = x['t'];
            if (x['tip'] == tip && tt is num && tm is num &&
                ayni(tt.toDouble(), m.tutar) && yakin(tm.toInt(), m.tarih, 10)) {
              return (true, '${h.s('ad')} hesabında kayıtlı');
            }
          }
        }
      case SmsTuru.krediTaksit:
        for (final h in v.hesaplar) {
          if (h.s('ad') == m.hesapAdi && ayni(h.n('taksitTutari'), m.tutar) &&
              (m.sonOdeme == 0 || h.t('vade') == m.sonOdeme)) {
            return (true, 'Taksit bilgisi güncel');
          }
        }
    }
    return (false, '');
  }

  Future<void> _tara() async {
    setState(() => _taraniyor = true);
    try {
      if (!await Sms.izinVarMi()) {
        final ok = await Sms.izinIste();
        if (!ok) throw 'SMS okuma izni verilmedi. Ayarlar → Uygulamalar → Bereket → İzinler bölümünden açabilirsiniz.';
      }
      final mesajlar = await Sms.oku(gun: _gun);
      final v = durum.v;
      final anahtarlar = <String>{
        for (final g in v.giderler) g.s('smsKey'),
        for (final g in v.gelirler) g.s('smsKey'),
        for (final h in v.hesaplar) ...h.l('smsAnahtarlar'),
        for (final h in v.hesaplar)
          for (final x in h.liste('hareketler')) (x['k'] ?? '').toString(),
      };
      final gorulen = <String>{};
      final adaylar = <_Aday>[];
      for (final s in mesajlar) {
        final m = smsCoz(s.adres, s.metin, s.tarih);
        if (m == null || !gorulen.add(m.anahtar)) continue;
        final (kayitli, neden) = _kayitliMi(v, m, anahtarlar);
        adaylar.add(_Aday(m, kayitli, neden));
      }
      setState(() => _adaylar = adaylar);
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    } finally {
      if (mounted) setState(() => _taraniyor = false);
    }
  }

  Future<String> _hesap(Veriler v, BankaMesaji m) async {
    for (final h in v.hesaplar) {
      if (h.s('yon') != 'alacak' && h.s('ad') == m.hesapAdi) return h.id;
    }
    return durum.kaydet('hesaplar', {
      'ad': m.hesapAdi,
      'yon': 'borc',
      'tur': m.tur == SmsTuru.krediTaksit || m.hesapAdi.endsWith('Kredi') ? 'Kredi' : 'Kredi Kartı',
      'birim': 'TL',
      'hareketler': <Map<String, dynamic>>[],
    });
  }

  Future<void> _kaydet() async {
    final l = _adaylar?.where((a) => a.secili).toList() ?? [];
    if (l.isEmpty) {
      bildir(context, 'Seçili mesaj yok.');
      return;
    }
    setState(() => _kaydediliyor = true);
    var n = 0;
    try {
      for (final a in l) {
        final m = a.m;
        final v = durum.v;
        final t = DateTime.fromMillisecondsSinceEpoch(m.tarih);
        switch (m.tur) {
          case SmsTuru.kartBorcu:
            final id = await _hesap(v, m);
            await Veri.hareketEkle(durum.iid, id,
                tip: 'artis',
                tutar: m.tutar,
                aciklama: 'Dönem borcu${m.sonOdeme > 0 ? ' · son ödeme ${tarih(m.sonOdeme)}' : ''}',
                tarih: m.tarih,
                anahtar: m.anahtar);
            if (m.sonOdeme > 0) await durum.kaydet('hesaplar', {'vade': m.sonOdeme}, id: id);
          case SmsTuru.odemeAlindi:
            final id = await _hesap(v, m);
            await Veri.hareketEkle(durum.iid, id,
                tip: 'odeme', tutar: m.tutar, aciklama: 'Ödeme (SMS)', tarih: m.tarih, anahtar: m.anahtar);
          case SmsTuru.krediTaksit:
            final id = await _hesap(v, m);
            await durum.kaydet('hesaplar', {
              'taksitTutari': m.tutar,
              if (m.sonOdeme > 0) 'vade': m.sonOdeme,
              if (m.sonOdeme > 0) 'odemeGunu': DateTime.fromMillisecondsSinceEpoch(m.sonOdeme).day,
            }, id: id);
            await Veri.smsIsaretle(durum.iid, id, m.anahtar);
          case SmsTuru.gelen:
            Kayit? isyeri;
            for (final i in v.isyerleri) {
              final maas = i.n('maas');
              final gun = i.t('gun');
              if (maas > 0 && (m.tutar - maas).abs() <= maas * 0.1 &&
                  (gun <= 0 || (t.day >= gun - 3 && t.day <= gun + 5))) {
                isyeri = i;
              }
            }
            await durum.kaydet('gelirler', {
              'tur': isyeri != null ? 'Maaş' : 'Diğer',
              'isyeriId': isyeri?.id ?? '',
              'kaynak': isyeri == null ? '${m.banka} hesabına gelen' : '',
              'tutar': m.tutar,
              'tarih': m.tarih,
              'yil': t.year,
              'banka': m.banka,
              'smsKey': m.anahtar,
            });
          case SmsTuru.harcama:
            await durum.kaydet('giderler', {
              'alan': 'ev',
              'kalem': smsKategori(m),
              'aciklama': harcamaYeri(m.metin).isEmpty ? '${m.banka} kart harcaması' : harcamaYeri(m.metin),
              'tutar': m.tutar,
              'tarih': m.tarih,
              'yil': t.year,
              'banka': m.banka,
              'smsKey': m.anahtar,
            });
        }
        n++;
      }
      if (mounted) {
        bildir(context, '$n kayıt eklendi.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) bildir(context, '$n kayıt eklendi, sonra hata: ${hataYazisi(e)}');
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _adaylar;
    final gorunen = l?.where((a) => _kayitlilariGoster || !a.kayitli).toList() ?? const <_Aday>[];
    final kayitliSayi = l?.where((a) => a.kayitli).length ?? 0;
    final secili = l?.where((a) => a.secili).length ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Banka Mesajları')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Garanti, Vakıfbank, Ziraat, Yapı Kredi, Kuveyt Türk ve ING\'den gelen SMS\'lerden '
                  'kart borcu, kredi taksiti, ödeme, gelen para ve harcamaları bulur. Mesajlar telefonda '
                  'okunur, hiçbir yere gönderilmez. Daha önce eklenenler ya da aynı tutarda kayıtlı olanlar '
                  'seçilmez.',
                  style: yaziSoluk,
                ),
                const SizedBox(height: 10),
                SecimSatiri(
                  secenekler: const ['30 gün', '90 gün', '180 gün', '365 gün'],
                  secili: '$_gun gün',
                  onSec: (s) => setState(() => _gun = int.parse(s.split(' ').first)),
                ),
                const SizedBox(height: 10),
                Buton(
                  yazi: 'Mesajları Tara',
                  ikon: Icons.sms,
                  renk: ButonRenk.yesil,
                  mesgul: _taraniyor,
                  onTap: _tara,
                ),
                if (l != null) ...[
                  const SizedBox(height: 8),
                  Text('${l.length} banka mesajı bulundu · $kayitliSayi tanesi zaten kayıtlı',
                      style: yaziSoluk),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _kayitlilariGoster,
                    onChanged: (b) => setState(() => _kayitlilariGoster = b),
                    title: const Text('Kayıtlı olanları da göster',
                        style: TextStyle(color: Renk.soluk, fontSize: 14)),
                  ),
                ],
              ],
            ),
          ),
          for (final a in gorunen)
            Panel(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              kenarRengi: a.kayitli ? Renk.cizgi : (a.secili ? Renk.yesil : Renk.cizgi),
              onTap: () => setState(() => a.secili = !a.secili),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(value: a.secili, onChanged: (b) => setState(() => a.secili = b == true)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('${smsTuruAdi[a.m.tur]} · ${a.m.banka}',
                                  style: const TextStyle(color: Renk.yazi, fontWeight: FontWeight.w700)),
                            ),
                            Text(tl(a.m.tutar),
                                style: TextStyle(
                                    color: a.m.tur == SmsTuru.gelen ? Renk.yesil : Renk.altin,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                        Text(
                            '${tarih(a.m.tarih)}'
                            '${a.m.sonOdeme > 0 ? ' · son ödeme ${tarih(a.m.sonOdeme)}' : ''}',
                            style: yaziSoluk),
                        if (a.kayitli)
                          Text('⚠ ${a.neden}', style: const TextStyle(color: Renk.turuncu, fontSize: 12.5)),
                        const SizedBox(height: 4),
                        Text(a.m.metin,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Renk.gri, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (l != null && l.isNotEmpty) ...[
            const SizedBox(height: 6),
            Buton(
              yazi: 'Seçilenleri Ekle ($secili)',
              renk: ButonRenk.yesil,
              mesgul: _kaydediliyor,
              yukseklik: 54,
              onTap: _kaydet,
            ),
          ],
        ],
      ),
    );
  }
}
