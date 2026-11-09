import 'dart:convert';

import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../bicim.dart';
import '../ekstre.dart';
import '../modeller.dart';
import '../sabitler.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'banka_mesajlari.dart';
import 'belge_arsiv.dart';
import 'belge_okut.dart';
import 'defter.dart';
import 'ekipman.dart';
import 'form.dart';
import 'kabuk.dart';
import 'uretim.dart';

/// Ev Bütçem: aylık ev harcamaları, kategoriler, sabit giderler, ekstre.
class EvButcesiSayfasi extends StatefulWidget {
  const EvButcesiSayfasi({super.key, required this.durum, this.geri = true});
  final Durum durum;
  final bool geri;

  @override
  State<EvButcesiSayfasi> createState() => _EvButcesiSayfasiState();
}

class _EvButcesiSayfasiState extends State<EvButcesiSayfasi> {
  DateTime _ay = DateTime(DateTime.now().year, DateTime.now().month);
  String _kategori = 'Hepsi';

  Durum get durum => widget.durum;

  bool _buAy(Kayit x) {
    final d = DateTime.fromMillisecondsSinceEpoch(x.t('tarih'));
    return d.year == _ay.year && d.month == _ay.month;
  }

  @override
  Widget build(BuildContext context) {
    return Sayfa(
      baslik: 'Ev Bütçem',
      durum: durum,
      geri: widget.geri,
      fab: ekleButonu('Harcama', () => giderFormu(context, durum, ev: true)),
      builder: (context, v) {
        final ev = v.giderler.where((g) => g.s('alan') == 'ev').toList();
        final ay = ev.where(_buAy).toList()
          ..sort((a, b) => b.t('tarih').compareTo(a.t('tarih')));
        final toplam = ay.fold(0.0, (a, g) => a + g.n('tutar'));
        final gecen = DateTime(_ay.year, _ay.month - 1);
        final gecenToplam = ev.where((g) {
          final d = DateTime.fromMillisecondsSinceEpoch(g.t('tarih'));
          return d.year == gecen.year && d.month == gecen.month;
        }).fold(0.0, (a, g) => a + g.n('tutar'));
        final kategoriler = <String, double>{};
        for (final g in ay) {
          kategoriler[g.s('kalem')] = (kategoriler[g.s('kalem')] ?? 0) + g.n('tutar');
        }
        final sirali = kategoriler.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        final bankalar_ = <String, double>{};
        for (final g in ay) {
          final b = g.s('banka').isEmpty ? 'Belirtilmedi' : g.s('banka');
          bankalar_[b] = (bankalar_[b] ?? 0) + g.n('tutar');
        }
        // Geçen ay girilmiş, bu ay girilmemiş sabit giderler.
        final sabitler = <String, Kayit>{};
        for (final g in ev) {
          if (!g.b('sabit')) continue;
          final d = DateTime.fromMillisecondsSinceEpoch(g.t('tarih'));
          if (d.year == gecen.year && d.month == gecen.month) sabitler[g.s('kalem')] = g;
        }
        sabitler.removeWhere((k, _) => ay.any((g) => g.s('kalem') == k));
        final liste = ay.where((g) => _kategori == 'Hepsi' || g.s('kalem') == _kategori).toList();
        return [
          Panel(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: Renk.yazi),
                      onPressed: () => setState(() => _ay = DateTime(_ay.year, _ay.month - 1)),
                    ),
                    Expanded(
                      child: Text('${ayAdi(_ay.month)} ${_ay.year}',
                          textAlign: TextAlign.center, style: yaziKalin),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: Renk.yazi),
                      onPressed: () => setState(() => _ay = DateTime(_ay.year, _ay.month + 1)),
                    ),
                  ],
                ),
                Text(tl0(toplam),
                    style: const TextStyle(
                        color: Renk.altin, fontSize: 30, fontWeight: FontWeight.w900)),
                if (gecenToplam > 0)
                  Text(
                      'Geçen ay ${tl0(gecenToplam)} · ${toplam >= gecenToplam ? '▲' : '▼'} %${((toplam - gecenToplam).abs() / gecenToplam * 100).toStringAsFixed(0)}',
                      style: yaziSoluk),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Buton(
                        yazi: 'Ekstre Yükle',
                        renk: ButonRenk.yesil,
                        onTap: () => git(context, EkstreYukle(durum: durum)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Buton(
                        yazi: 'Harcama Ekle',
                        onTap: () => giderFormu(context, durum, ev: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Buton(
                        yazi: 'Banka SMS',
                        ikon: Icons.sms,
                        renk: ButonRenk.mor,
                        onTap: () => git(context, BankaMesajlari(durum: durum)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Buton(
                        yazi: 'Fiş Okut',
                        ikon: Icons.photo_camera,
                        renk: ButonRenk.turuncu,
                        onTap: () => git(context, BelgeOkut(durum: durum)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: BuyukKart(
                  simge: '🏡',
                  baslik: 'Ev Hedefi',
                  alt: v.evHedefi(DateTime.now()) == null
                      ? 'Hedef belirle'
                      : 'Bu ay ${tl0(v.evHedefi(DateTime.now())!.aylik)}',
                  renk1: const Color(0xFFD9775A),
                  renk2: const Color(0xFF8A3B25),
                  onTap: () => git(context, EvHedefiSayfasi(durum: durum)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BuyukKart(
                  simge: '📒',
                  baslik: 'Gelir - Gider',
                  alt: 'Tüm hareketler',
                  renk1: const Color(0xFF4F6B8F),
                  renk2: const Color(0xFF253A57),
                  onTap: () => git(context, DefterSayfasi(durum: durum)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (ay.any((g) => arabaKategorisi(g.s('kalem'))))
            Panel(
              onTap: () => git(context, EkipmanSayfasi(durum: durum)),
              child: Satir('🚗 Bu ay araba masrafı',
                  tl0(ay.where((g) => arabaKategorisi(g.s('kalem'))).fold(0.0, (a, g) => a + g.n('tutar'))),
                  kalin: true),
            ),
          if (sabitler.isNotEmpty)
            Panel(
              baslik: 'Bu ay girilmeyen sabit giderler',
              kenarRengi: Renk.turuncu,
              child: Column(
                children: [
                  for (final g in sabitler.values)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(g.s('kalem'), style: const TextStyle(color: Renk.yazi)),
                      subtitle: Text('Geçen ay ${tl0(g.n('tutar'))}', style: yaziSoluk),
                      trailing: TextButton(
                        onPressed: () async {
                          final t = DateTime(_ay.year, _ay.month,
                              DateTime.fromMillisecondsSinceEpoch(g.t('tarih')).day.clamp(1, 28).toInt(), 12);
                          try {
                            await durum.kaydet('giderler', {
                              'alan': 'ev',
                              'kalem': g.s('kalem'),
                              'tutar': g.n('tutar'),
                              'aciklama': g.s('aciklama'),
                              'banka': g.s('banka'),
                              'sabit': true,
                              'tarih': t.millisecondsSinceEpoch,
                              'yil': t.year,
                            });
                          } catch (e) {
                            if (context.mounted) bildir(context, hataYazisi(e));
                          }
                        },
                        child: const Text('Aynısını ekle'),
                      ),
                    ),
                ],
              ),
            ),
          if (sirali.isNotEmpty)
            Panel(
              baslik: 'Kategoriler',
              child: Column(
                children: [
                  for (final e in sirali)
                    InkWell(
                      onTap: () => setState(() => _kategori = _kategori == e.key ? 'Hepsi' : e.key),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Satir(e.key, '${tl0(e.value)} · %${(e.value / toplam * 100).toStringAsFixed(0)}',
                                renk: _kategori == e.key ? Renk.altin : null),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (e.value / toplam).clamp(0.0, 1.0).toDouble(),
                                minHeight: 7,
                                color: Renk.turuncu,
                                backgroundColor: Renk.zeminAlt,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (bankalar_.length > 1)
            Panel(
              baslik: 'Bankalara göre',
              child: Column(
                children: [for (final e in bankalar_.entries) Satir(e.key, tl0(e.value))],
              ),
            ),
          Panel(
            baslik: _kategori == 'Hepsi' ? 'Harcamalar' : 'Harcamalar · $_kategori',
            child: liste.isEmpty
                ? const Text('Bu ay harcama yok. Ekstre yükleyin ya da elle ekleyin.',
                    style: yaziSoluk)
                : Column(
                    children: [
                      for (final g in liste)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              g.s('aciklama').isEmpty ? g.s('kalem') : g.s('aciklama'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Renk.yazi)),
                          subtitle: Text(
                              [tarih(g.t('tarih')), g.s('kalem'), if (g.s('banka').isNotEmpty) g.s('banka')]
                                  .join(' · '),
                              style: yaziSoluk),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (g.s('belgeId').isNotEmpty)
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.attach_file, color: Renk.altin, size: 20),
                                  onPressed: () => belgeGoster(context, durum, g.s('belgeId')),
                                ),
                              Text(tl0(g.n('tutar')),
                                  style: const TextStyle(color: Renk.yazi, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          onTap: () => giderFormu(context, durum, gider: g),
                        ),
                    ],
                  ),
          ),
        ];
      },
    );
  }
}

/// Ekstre satırı için seçim: ev (kategori), tarla (kalem) ya da atla.
class _Secim {
  _Secim(this.satir, {required this.tur, required this.kategori});
  final EkstreSatir satir;
  String tur; // 'ev' | 'tarla' | 'atla'
  String kategori;
}

class EkstreYukle extends StatefulWidget {
  const EkstreYukle({super.key, required this.durum});
  final Durum durum;

  @override
  State<EkstreYukle> createState() => _EkstreYukleState();
}

class _EkstreYukleState extends State<EkstreYukle> {
  String _banka = 'Ziraat Bankası';
  List<_Secim>? _secimler;
  int _tekrar = 0;
  int _gelen = 0;
  bool _mesgul = false;
  String _dosya = '';

  Durum get durum => widget.durum;

  Future<void> _sec() async {
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'csv', 'txt'],
        withData: true,
      );
      if (r == null || r.files.isEmpty) return;
      final f = r.files.first;
      final bytes = f.bytes;
      if (bytes == null) throw 'Dosya okunamadı.';
      List<List<String>> satirlar;
      if (f.name.toLowerCase().endsWith('.xlsx')) {
        final x = xl.Excel.decodeBytes(bytes);
        satirlar = [];
        for (final t in x.tables.values) {
          for (final row in t.rows) {
            satirlar.add([for (final c in row) _hucreYazi(c?.value)]);
          }
          if (satirlar.length > 3) break;
        }
      } else {
        String metin;
        try {
          metin = utf8.decode(bytes);
        } catch (_) {
          metin = latin1.decode(bytes);
        }
        satirlar = csvOku(metin);
      }
      final cozulen = ekstreCoz(satirlar);
      if (cozulen.isEmpty) {
        throw 'Dosyada tarih ve tutar sütunları bulunamadı. Bankanın uygulamasından '
            '"Excel olarak indir" seçeneğiyle aldığınız dosyayı deneyin; olmazsa bir örneğini gönderin.';
      }
      final varOlan = {for (final g in durum.v.giderler) g.s('ekstreKey')};
      final yeni = <_Secim>[];
      var tekrar = 0, gelen = 0;
      for (final s in cozulen) {
        if (!s.harcama) {
          gelen++;
          continue;
        }
        if (varOlan.contains(s.anahtar)) {
          tekrar++;
          continue;
        }
        final tarla = tarlaKalemiTahmin(s.aciklama);
        yeni.add(_Secim(s,
            tur: tarla != null ? 'tarla' : 'ev',
            kategori: tarla ?? evKategorisiTahmin(s.aciklama)));
      }
      setState(() {
        _secimler = yeni;
        _tekrar = tekrar;
        _gelen = gelen;
        _dosya = f.name;
      });
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    }
  }

  static String _hucreYazi(Object? v) {
    if (v == null) return '';
    if (v is xl.DateCellValue) {
      return '${v.day.toString().padLeft(2, '0')}.${v.month.toString().padLeft(2, '0')}.${v.year}';
    }
    if (v is xl.DateTimeCellValue) {
      return '${v.day.toString().padLeft(2, '0')}.${v.month.toString().padLeft(2, '0')}.${v.year}';
    }
    if (v is xl.DoubleCellValue) return v.value.toString();
    if (v is xl.IntCellValue) return v.value.toString();
    return v.toString();
  }

  Future<void> _kaydet() async {
    final l = _secimler;
    if (l == null) return;
    final kayitlar = <Map<String, dynamic>>[];
    for (final s in l) {
      if (s.tur == 'atla') continue;
      final t = DateTime.fromMillisecondsSinceEpoch(s.satir.tarih);
      kayitlar.add({
        'alan': s.tur == 'ev' ? 'ev' : 'tarla',
        'kalem': s.kategori,
        'tutar': s.satir.tutar,
        'aciklama': s.satir.aciklama,
        'tarih': s.satir.tarih,
        'yil': t.year,
        'banka': _banka,
        'odendi': true,
        'ekstreKey': s.satir.anahtar,
        if (s.tur == 'tarla') 'tarlaIds': <String>[],
      });
    }
    if (kayitlar.isEmpty) {
      bildir(context, 'Kaydedilecek satır yok.');
      return;
    }
    setState(() => _mesgul = true);
    try {
      await Veri.topluEkle(durum.iid, 'giderler', kayitlar, uid: durum.uid);
      if (mounted) {
        bildir(context, '${kayitlar.length} harcama eklendi.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _secimler;
    final secilen = l?.where((s) => s.tur != 'atla').fold(0.0, (a, s) => a + s.satir.tutar) ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Ekstre Yükle')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _banka,
                  dropdownColor: Renk.kartAcik,
                  decoration: const InputDecoration(labelText: 'Banka'),
                  items: [
                    for (final b in bankalar.where((b) => b != 'Nakit'))
                      DropdownMenuItem(value: b, child: Text(b)),
                  ],
                  onChanged: (b) => setState(() => _banka = b ?? _banka),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Bankanın uygulamasından hesap hareketlerini ya da kart ekstresini '
                  'Excel (.xlsx) veya CSV olarak indirin, sonra buradan seçin. '
                  'Harcamalar satır satır gelir; her biri için Ev, Tarla ya da Atla seçin.',
                  style: yaziSoluk,
                ),
                const SizedBox(height: 12),
                Buton(yazi: 'Dosya Seç', ikon: Icons.upload_file, onTap: _sec),
                if (_dosya.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                      '$_dosya · ${l?.length ?? 0} yeni harcama'
                      '${_tekrar > 0 ? ' · $_tekrar daha önce eklenmiş' : ''}'
                      '${_gelen > 0 ? ' · $_gelen gelen para atlandı' : ''}',
                      style: yaziSoluk),
                ],
              ],
            ),
          ),
          if (l != null) ...[
            for (final s in l) _satir(s),
            const SizedBox(height: 8),
            Buton(
              yazi: 'Kaydet · ${tl0(secilen)}',
              renk: ButonRenk.yesil,
              mesgul: _mesgul,
              yukseklik: 54,
              onTap: _kaydet,
            ),
          ],
        ],
      ),
    );
  }

  Widget _satir(_Secim s) {
    final kategoriler = s.tur == 'tarla' ? giderKalemleri.keys.toList() : evKategorileri;
    return Panel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      kenarRengi: s.tur == 'atla' ? Renk.cizgi : (s.tur == 'tarla' ? Renk.yesil : Renk.turuncu),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(s.satir.aciklama.isEmpty ? '(açıklama yok)' : s.satir.aciklama,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: s.tur == 'atla' ? Renk.soluk : Renk.yazi,
                        fontWeight: FontWeight.w600)),
              ),
              Text(tl(s.satir.tutar),
                  style: const TextStyle(color: Renk.yazi, fontWeight: FontWeight.w800)),
            ],
          ),
          Text(tarih(s.satir.tarih), style: yaziSoluk),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final (tur, yazi) in const [('ev', 'Ev'), ('tarla', 'Tarla'), ('atla', 'Atla')])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(yazi),
                    selected: s.tur == tur,
                    onSelected: (_) => setState(() {
                      s.tur = tur;
                      if (tur == 'ev' && !evKategorileri.contains(s.kategori)) {
                        s.kategori = evKategorisiTahmin(s.satir.aciklama);
                      }
                      if (tur == 'tarla' && !giderKalemleri.containsKey(s.kategori)) {
                        s.kategori = tarlaKalemiTahmin(s.satir.aciklama) ?? 'Diğer';
                      }
                    }),
                  ),
                ),
              const Spacer(),
              if (s.tur != 'atla')
                TextButton(
                  onPressed: () async {
                    final k = await secimYap(context, 'Kategori', kategoriler);
                    if (k != null) setState(() => s.kategori = k);
                  },
                  child: Text(s.kategori),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
