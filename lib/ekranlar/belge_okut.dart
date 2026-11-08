import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../belge.dart';
import '../bicim.dart';
import '../ekstre.dart';
import '../sabitler.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'form.dart';

/// Kamerayla belge okutma: fiş, fatura, el yazısı hesap. Okunanı özetler,
/// onay alınca ilgili bölüme işler.
class BelgeOkut extends StatefulWidget {
  const BelgeOkut({super.key, required this.durum});
  final Durum durum;

  @override
  State<BelgeOkut> createState() => _BelgeOkutState();
}

/// Belgenin nereye işleneceği.
enum _Hedef { evGider, tarlaGider, araba }

/// El yazısı satırı için seçim.
enum _SatirHedef { ev, tarla, borc, alacak, atla }

class _BelgeOkutState extends State<BelgeOkut> {
  File? _resim;
  String _metin = '';
  BelgeOzet? _ozet;
  bool _okunuyor = false;
  bool _mesgul = false;

  final _firma = TextEditingController();
  final _toplam = TextEditingController();
  final _litre = TextEditingController();
  _Hedef _hedef = _Hedef.evGider;
  String _evKategori = 'Market';
  String _tarlaKalem = 'Gübre';
  final Set<String> _tarlalar = {};
  String _sayac = '';
  bool _odendi = true;
  final Map<BelgeSatiri, _SatirHedef> _satirHedef = {};

  Durum get durum => widget.durum;

  @override
  void dispose() {
    _firma.dispose();
    _toplam.dispose();
    _litre.dispose();
    super.dispose();
  }

  Future<void> _cek(ImageSource kaynak) async {
    try {
      final x = await ImagePicker().pickImage(source: kaynak, imageQuality: 90, maxWidth: 2400);
      if (x == null) return;
      setState(() {
        _okunuyor = true;
        _resim = File(x.path);
        _ozet = null;
      });
      final okuyucu = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        final sonuc = await okuyucu.processImage(InputImage.fromFilePath(x.path));
        _metin = sonuc.text;
      } finally {
        await okuyucu.close();
      }
      if (_metin.trim().isEmpty) throw 'Belgede yazı bulunamadı. Daha aydınlık ve düz bir fotoğraf deneyin.';
      _yerlestir(belgeCoz(_metin));
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    } finally {
      if (mounted) setState(() => _okunuyor = false);
    }
  }

  void _yerlestir(BelgeOzet o) {
    _ozet = o;
    _firma.text = o.firma;
    _toplam.text = girdi(double.parse(o.toplam.toStringAsFixed(2)));
    _litre.text = o.litre == null ? '' : girdi(o.litre);
    _odendi = true;
    _tarlalar.clear();
    _satirHedef.clear();
    switch (o.tur) {
      case BelgeTuru.akaryakit:
        _hedef = _Hedef.araba;
        _tarlaKalem = 'Mazot';
      case BelgeTuru.market:
        _hedef = _Hedef.evGider;
        _evKategori = 'Market';
      case BelgeTuru.elektrik:
        _hedef = _Hedef.evGider;
        _evKategori = 'Elektrik';
        _tarlaKalem = 'Elektrik';
      case BelgeTuru.tarim:
        _hedef = _Hedef.tarlaGider;
        _tarlaKalem = o.kalem ?? 'Gübre';
      case BelgeTuru.faturaDiger:
      case BelgeTuru.diger:
        _hedef = _Hedef.evGider;
        _evKategori = evKategorisiTahmin(_metin);
      case BelgeTuru.elYazisi:
        for (final s in o.satirlar) {
          final tarla = tarlaKalemiTahmin(s.ad);
          _satirHedef[s] = tarla != null ? _SatirHedef.tarla : _SatirHedef.ev;
        }
    }
  }

  Future<void> _onayla() async {
    final o = _ozet;
    if (o == null) return;
    final v = durum.v;
    final tutar = sayiOku(_toplam.text) ?? 0;
    final t = DateTime.fromMillisecondsSinceEpoch(o.tarih);
    final firma = _firma.text.trim();
    setState(() => _mesgul = true);
    try {
      if (o.tur == BelgeTuru.elYazisi) {
        var n = 0;
        for (final e in _satirHedef.entries) {
          final s = e.key;
          if (e.value == _SatirHedef.atla) continue;
          switch (e.value) {
            case _SatirHedef.atla:
              break;
            case _SatirHedef.ev:
              await durum.kaydet('giderler', {
                'alan': 'ev',
                'kalem': evKategorisiTahmin(s.ad),
                'aciklama': s.ad,
                'tutar': s.tutar,
                'tarih': o.tarih,
                'yil': t.year,
                'kaynak': 'belge',
              });
            case _SatirHedef.tarla:
              await durum.kaydet('giderler', {
                'alan': 'tarla',
                'kalem': tarlaKalemiTahmin(s.ad) ?? 'Diğer',
                'aciklama': s.ad,
                'tutar': s.tutar,
                if (s.miktar != null) 'miktar': s.miktar,
                'tarih': o.tarih,
                'yil': t.year,
                'tarlaIds': _tarlalar.toList(),
                'odendi': true,
                'kaynak': 'belge',
              });
            case _SatirHedef.borc:
            case _SatirHedef.alacak:
              await Veri.borcaYaz(durum.iid, v,
                  kime: s.ad,
                  tur: 'Kişi',
                  tutar: s.tutar,
                  aciklama: 'El yazısı hesap',
                  tarih: o.tarih,
                  uid: durum.uid,
                  yon: e.value == _SatirHedef.alacak ? 'alacak' : 'borc');
          }
          n++;
        }
        if (mounted) bildir(context, '$n kayıt eklendi.');
      } else {
        if (tutar <= 0) throw 'Toplam tutarı yazın.';
        final litre = sayiOku(_litre.text);
        if (_hedef == _Hedef.tarlaGider) {
          final sayacId = _tarlaKalem == 'Elektrik' ? _sayac : '';
          await durum.kaydet('giderler', {
            'alan': 'tarla',
            'kalem': _tarlaKalem,
            'aciklama': firma,
            'tedarikci': firma,
            'tutar': tutar,
            if (litre != null && litre > 0) 'miktar': litre,
            if (litre != null && litre > 0) 'birim': 'lt',
            'tarih': o.tarih,
            'yil': t.year,
            'tarlaIds': sayacId.isEmpty ? _tarlalar.toList() : <String>[],
            'sayacId': sayacId,
            'odendi': _odendi,
            'kaynak': 'belge',
          });
          if (!_odendi && firma.isNotEmpty) {
            await Veri.borcaYaz(durum.iid, v,
                kime: firma,
                tur: 'Bayi',
                tutar: tutar,
                aciklama: _tarlaKalem,
                tarih: o.tarih,
                uid: durum.uid);
          }
        } else {
          await durum.kaydet('giderler', {
            'alan': 'ev',
            'kalem': _hedef == _Hedef.araba ? 'Araba (yakıt)' : _evKategori,
            'aciklama': [firma, if (litre != null && litre > 0) '${sayi(litre)} lt']
                .where((x) => x.isNotEmpty)
                .join(' · '),
            'tutar': tutar,
            'tarih': o.tarih,
            'yil': t.year,
            'kaynak': 'belge',
          });
        }
        if (mounted) bildir(context, 'Belge işlendi.');
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _ozet;
    return Scaffold(
      appBar: AppBar(title: const Text('Belge Okut')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Fiş, fatura ya da el yazısı hesabı düz bir zeminde, iyi ışıkta çekin. '
                  'Yazı telefonda okunur, internete gönderilmez.',
                  style: yaziSoluk,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Buton(
                        yazi: 'Kamera',
                        ikon: Icons.photo_camera,
                        renk: ButonRenk.yesil,
                        mesgul: _okunuyor,
                        onTap: () => _cek(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Buton(
                        yazi: 'Galeri',
                        ikon: Icons.photo_library,
                        onTap: _okunuyor ? null : () => _cek(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
                if (_resim != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_resim!, height: 180, fit: BoxFit.cover),
                  ),
                ],
              ],
            ),
          ),
          if (o != null) ..._onayBolumu(o),
        ],
      ),
    );
  }

  List<Widget> _onayBolumu(BelgeOzet o) {
    final v = durum.v;
    Widget tarlaSecimi() => Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final t in v.tarlalar)
              FilterChip(
                label: Text('${v.tarlaAdi(t.id)} (${sayi(t.n('dekar'))} da)'),
                selected: _tarlalar.contains(t.id),
                onSelected: (b) => setState(() => b ? _tarlalar.add(t.id) : _tarlalar.remove(t.id)),
              ),
            if (v.tarlalar.isEmpty)
              const Text('Tarla seçilmezse genel tarla gideri olur.', style: yaziSoluk),
          ],
        );
    return [
      Panel(
        baslik: 'Okunan belge',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<BelgeTuru>(
              initialValue: o.tur,
              dropdownColor: Renk.kartAcik,
              decoration: const InputDecoration(labelText: 'Belge türü'),
              items: [
                for (final e in belgeTuruAdi.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (t) {
                if (t == null) return;
                o.tur = t;
                if (t == BelgeTuru.elYazisi && o.satirlar.isNotEmpty) {
                  o.toplam = o.satirlar.fold<double>(0, (x, s) => x + s.tutar);
                }
                setState(() => _yerlestir(o));
              },
            ),
            const SizedBox(height: 12),
            if (o.tur != BelgeTuru.elYazisi) ...[
              TextField(
                controller: _firma,
                decoration: const InputDecoration(labelText: 'Firma / açıklama'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _toplam,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Toplam', suffixText: '₺'),
                    ),
                  ),
                  if (o.tur == BelgeTuru.akaryakit) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _litre,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Litre', suffixText: 'lt'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Tarih: ${tarih(o.tarih)}', style: const TextStyle(color: Renk.yazi)),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.fromMillisecondsSinceEpoch(o.tarih),
                      firstDate: DateTime(2015),
                      lastDate: DateTime(DateTime.now().year + 1),
                    );
                    if (d != null) {
                      setState(() => o.tarih = DateTime(d.year, d.month, d.day, 12).millisecondsSinceEpoch);
                    }
                  },
                  child: const Text('Değiştir'),
                ),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Okunan yazının tamamı', style: yaziSoluk),
              children: [
                SelectableText(_metin, style: const TextStyle(color: Renk.soluk, fontSize: 12.5)),
              ],
            ),
          ],
        ),
      ),
      if (o.tur == BelgeTuru.elYazisi)
        Panel(
          baslik: 'Satırlar (${o.satirlar.length})',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (o.satirlar.isEmpty)
                const Text('Tutarlı satır bulunamadı.', style: yaziSoluk),
              for (final s in o.satirlar) ...[
                Row(
                  children: [
                    Expanded(child: Text(s.ad, style: const TextStyle(color: Renk.yazi, fontWeight: FontWeight.w600))),
                    TextButton(
                      onPressed: () async {
                        final y = await metinSor(context, s.ad, baslangic: girdi(s.tutar), sayi: true);
                        final x = sayiOku(y);
                        if (x != null) setState(() => s.tutar = x);
                      },
                      child: Text(tl(s.tutar)),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final (h, yazi) in const [
                      (_SatirHedef.ev, 'Ev'),
                      (_SatirHedef.tarla, 'Tarla'),
                      (_SatirHedef.borc, 'Borcum'),
                      (_SatirHedef.alacak, 'Alacağım'),
                      (_SatirHedef.atla, 'Atla'),
                    ])
                      ChoiceChip(
                        label: Text(yazi),
                        selected: _satirHedef[s] == h,
                        onSelected: (_) => setState(() => _satirHedef[s] = h),
                      ),
                  ],
                ),
                const Divider(height: 18),
              ],
              if (_satirHedef.values.contains(_SatirHedef.tarla)) ...[
                const Text('Tarla satırları hangi tarlalara:', style: yaziSoluk),
                const SizedBox(height: 6),
                tarlaSecimi(),
              ],
            ],
          ),
        )
      else
        Panel(
          baslik: 'Nereye işlensin?',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: const Text('🏠 Ev gideri'),
                    selected: _hedef == _Hedef.evGider,
                    onSelected: (_) => setState(() => _hedef = _Hedef.evGider),
                  ),
                  if (o.tur == BelgeTuru.akaryakit)
                    ChoiceChip(
                      label: const Text('🚗 Araba (yakıt)'),
                      selected: _hedef == _Hedef.araba,
                      onSelected: (_) => setState(() => _hedef = _Hedef.araba),
                    ),
                  ChoiceChip(
                    label: Text(o.tur == BelgeTuru.akaryakit ? '🚜 Tarla mazotu' : '🚜 Tarla gideri'),
                    selected: _hedef == _Hedef.tarlaGider,
                    onSelected: (_) => setState(() => _hedef = _Hedef.tarlaGider),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_hedef == _Hedef.evGider)
                DropdownButtonFormField<String>(
                  initialValue: evKategorileri.contains(_evKategori) ? _evKategori : 'Diğer',
                  dropdownColor: Renk.kartAcik,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: [for (final k in evKategorileri) DropdownMenuItem(value: k, child: Text(k))],
                  onChanged: (k) => setState(() => _evKategori = k ?? _evKategori),
                ),
              if (_hedef == _Hedef.tarlaGider) ...[
                DropdownButtonFormField<String>(
                  initialValue: giderKalemleri.containsKey(_tarlaKalem) ? _tarlaKalem : 'Diğer',
                  dropdownColor: Renk.kartAcik,
                  decoration: const InputDecoration(labelText: 'Gider kalemi'),
                  items: [
                    for (final k in giderKalemleri.keys) DropdownMenuItem(value: k, child: Text(k))
                  ],
                  onChanged: (k) => setState(() => _tarlaKalem = k ?? _tarlaKalem),
                ),
                const SizedBox(height: 10),
                if (_tarlaKalem == 'Elektrik' && v.sayaclar.isNotEmpty)
                  DropdownButtonFormField<String>(
                    initialValue: _sayac.isEmpty ? null : _sayac,
                    dropdownColor: Renk.kartAcik,
                    decoration: const InputDecoration(labelText: 'Elektrik sayacı'),
                    items: [
                      for (final s in v.sayaclar) DropdownMenuItem(value: s.id, child: Text(s.s('ad')))
                    ],
                    onChanged: (s) => setState(() => _sayac = s ?? ''),
                  )
                else
                  tarlaSecimi(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _odendi,
                  onChanged: (b) => setState(() => _odendi = b),
                  title: const Text('Ödendi', style: TextStyle(color: Renk.yazi)),
                  subtitle: const Text('Kapatırsanız firma adına borç yazılır.', style: yaziSoluk),
                ),
              ],
            ],
          ),
        ),
      Panel(
        kenarRengi: Renk.yesil,
        child: Text(_ozetYazisi(o), style: const TextStyle(color: Renk.yazi, fontSize: 15.5, height: 1.4)),
      ),
      Buton(
        yazi: 'Onayla ve Ekle',
        ikon: Icons.check,
        renk: ButonRenk.yesil,
        mesgul: _mesgul,
        yukseklik: 54,
        onTap: _onayla,
      ),
    ];
  }

  String _ozetYazisi(BelgeOzet o) {
    if (o.tur == BelgeTuru.elYazisi) {
      final secili = _satirHedef.entries.where((e) => e.value != _SatirHedef.atla);
      final top = secili.fold<double>(0, (a, e) => a + e.key.tutar);
      return '${secili.length} satır, toplam ${tl(top)} eklenecek.';
    }
    final tutar = sayiOku(_toplam.text) ?? 0;
    final litre = sayiOku(_litre.text);
    final nereye = switch (_hedef) {
      _Hedef.araba => 'Ev Bütçem → Araba (yakıt)',
      _Hedef.evGider => 'Ev Bütçem → $_evKategori',
      _Hedef.tarlaGider => 'Tarla gideri → $_tarlaKalem'
          '${_tarlalar.isEmpty ? '' : ' (${_tarlalar.length} tarlaya dekara göre)'}',
    };
    return '${belgeTuruAdi[o.tur]}\n'
        '${_firma.text.isEmpty ? '' : '${_firma.text} · '}${tarih(o.tarih)}'
        '${litre != null && litre > 0 ? ' · ${sayi(litre)} lt' : ''}\n'
        'Tutar: ${tl(tutar)}\n'
        '→ $nereye${_hedef == _Hedef.tarlaGider && !_odendi ? ' · borç olarak' : ''}';
  }
}
