import 'package:flutter/material.dart';

import '../bicim.dart';
import '../hesap.dart';
import '../servis/veri.dart';
import '../tema.dart';

enum AlanTip { metin, sayi, secim, tarih, tarla, tarlalar, anahtar, yil, uzun }

/// Formdaki tek bir alan.
class Alan {
  const Alan(
    this.key,
    this.etiket, {
    this.tip = AlanTip.metin,
    this.secenekler = const [],
    this.oneriler = const [],
    this.zorunlu = false,
    this.ipucu,
    this.birim,
    this.gorunur,
    this.aciklama,
  });

  final String key;
  final String etiket;
  final AlanTip tip;
  final List<String> secenekler;

  /// Metin alanının altında dokununca yazılan hazır seçenekler.
  final List<String> oneriler;
  final bool zorunlu;
  final String? ipucu;
  final String? birim;
  final String? aciklama;

  /// Değerlere göre alanın görünüp görünmeyeceği.
  final bool Function(Map<String, dynamic> d)? gorunur;
}

/// Genel kayıt formu sayfasını açar.
Future<void> formAc(
  BuildContext context, {
  required String baslik,
  required List<Alan> alanlar,
  required Veriler v,
  Map<String, dynamic> baslangic = const {},
  required Future<void> Function(Map<String, dynamic> d) onKaydet,
  Future<void> Function()? onSil,
  Widget Function(Map<String, dynamic> d)? ozet,
  void Function(String key, Map<String, dynamic> d)? degisince,
}) {
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => FormSayfasi(
      baslik: baslik,
      alanlar: alanlar,
      v: v,
      baslangic: baslangic,
      onKaydet: onKaydet,
      onSil: onSil,
      ozet: ozet,
      degisince: degisince,
    ),
  ));
}

class FormSayfasi extends StatefulWidget {
  const FormSayfasi({
    super.key,
    required this.baslik,
    required this.alanlar,
    required this.v,
    required this.baslangic,
    required this.onKaydet,
    this.onSil,
    this.ozet,
    this.degisince,
  });

  final String baslik;
  final List<Alan> alanlar;
  final Veriler v;
  final Map<String, dynamic> baslangic;
  final Future<void> Function(Map<String, dynamic> d) onKaydet;
  final Future<void> Function()? onSil;
  final Widget Function(Map<String, dynamic> d)? ozet;
  final void Function(String key, Map<String, dynamic> d)? degisince;

  @override
  State<FormSayfasi> createState() => _FormSayfasiState();
}

class _FormSayfasiState extends State<FormSayfasi> {
  late final Map<String, dynamic> _d = Map.of(widget.baslangic);
  final Map<String, TextEditingController> _c = {};
  bool _mesgul = false;

  bool _metinli(AlanTip t) =>
      t == AlanTip.metin || t == AlanTip.sayi || t == AlanTip.uzun;

  @override
  void initState() {
    super.initState();
    for (final a in widget.alanlar) {
      if (_metinli(a.tip)) {
        final v = _d[a.key];
        _c[a.key] = TextEditingController(
            text: v == null ? '' : (v is num ? girdi(v) : v.toString()));
      }
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Metin kutularındaki değerleri _d'ye aktarır.
  Map<String, dynamic> _topla() {
    for (final a in widget.alanlar) {
      final c = _c[a.key];
      if (c == null) continue;
      if (a.tip == AlanTip.sayi) {
        _d[a.key] = sayiOku(c.text);
      } else {
        _d[a.key] = c.text.trim();
      }
    }
    return _d;
  }

  void _degisti(String key) {
    _topla();
    widget.degisince?.call(key, _d);
    // Değişim fonksiyonu başka bir alanı doldurduysa kutuya yansıt.
    for (final a in widget.alanlar) {
      final c = _c[a.key];
      if (c == null || a.key == key) continue;
      final v = _d[a.key];
      final yazi = v == null ? '' : (v is num ? girdi(v) : v.toString());
      if (a.tip == AlanTip.sayi) {
        if (sayiOku(c.text) != (v is num ? v.toDouble() : null)) c.text = yazi;
      } else if (c.text.trim() != yazi) {
        c.text = yazi;
      }
    }
    setState(() {});
  }

  Future<void> _kaydet() async {
    final d = _topla();
    for (final a in widget.alanlar) {
      if (!a.zorunlu) continue;
      if (a.gorunur != null && !a.gorunur!(d)) continue;
      final v = d[a.key];
      final bos = v == null ||
          (v is String && v.isEmpty) ||
          (v is List && v.isEmpty);
      if (bos) {
        bildir(context, '"${a.etiket}" boş olamaz.');
        return;
      }
    }
    setState(() => _mesgul = true);
    try {
      await widget.onKaydet(Map.of(d));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _sil() async {
    final evet = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Silinsin mi?'),
        content: const Text('Bu kayıt kalıcı olarak silinecek.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Renk.kirmizi),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (evet != true) return;
    try {
      await widget.onSil!();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    }
  }

  Widget _alan(Alan a) {
    final etiket = '${a.etiket}${a.zorunlu ? ' *' : ''}';
    switch (a.tip) {
      case AlanTip.metin:
      case AlanTip.sayi:
      case AlanTip.uzun:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _c[a.key],
              keyboardType: a.tip == AlanTip.sayi
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : (a.tip == AlanTip.uzun ? TextInputType.multiline : TextInputType.text),
              maxLines: a.tip == AlanTip.uzun ? 3 : 1,
              textCapitalization: a.tip == AlanTip.sayi
                  ? TextCapitalization.none
                  : TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: etiket,
                hintText: a.ipucu,
                suffixText: a.birim,
              ),
              onChanged: (_) => _degisti(a.key),
            ),
            if (a.oneriler.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final o in a.oneriler.take(12))
                      ActionChip(
                        label: Text(o, style: const TextStyle(fontSize: 13)),
                        onPressed: () {
                          _c[a.key]!.text = o;
                          _degisti(a.key);
                        },
                      ),
                  ],
                ),
              ),
          ],
        );
      case AlanTip.secim:
        final sS = (_d[a.key] ?? '').toString();
        final lS = [
          ...a.secenekler,
          if (sS.isNotEmpty && !a.secenekler.contains(sS)) sS,
        ];
        return DropdownButtonFormField<String>(
          initialValue: sS.isEmpty ? null : sS,
          isExpanded: true,
          dropdownColor: Renk.kartAcik,
          decoration: InputDecoration(labelText: etiket),
          items: [
            for (final s in lS)
              DropdownMenuItem(
                  value: s, child: Text(s.isEmpty ? '— (varsayılan)' : s)),
          ],
          onChanged: (s) {
            _d[a.key] = s;
            _degisti(a.key);
          },
        );
      case AlanTip.yil:
        final buYil = DateTime.now().year;
        final sY = _d[a.key] is num ? (_d[a.key] as num).toInt() : buYil;
        _d[a.key] = sY;
        final yillar = {
          for (var y = buYil + 1; y >= buYil - 8; y--) y,
          sY,
        }.toList()
          ..sort((x, y) => y.compareTo(x));
        return DropdownButtonFormField<int>(
          initialValue: sY,
          dropdownColor: Renk.kartAcik,
          decoration: InputDecoration(labelText: etiket),
          items: [
            for (final y in yillar) DropdownMenuItem(value: y, child: Text('$y')),
          ],
          onChanged: (y) {
            _d[a.key] = y;
            _degisti(a.key);
          },
        );
      case AlanTip.tarih:
        final ms = _d[a.key] is num ? (_d[a.key] as num).toInt() : 0;
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final simdi = DateTime.now();
            final t = await showDatePicker(
              context: context,
              initialDate: ms > 0 ? DateTime.fromMillisecondsSinceEpoch(ms) : simdi,
              firstDate: DateTime(simdi.year - 15),
              lastDate: DateTime(simdi.year + 5),
            );
            if (t != null) {
              _d[a.key] = DateTime(t.year, t.month, t.day, 12).millisecondsSinceEpoch;
              _degisti(a.key);
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: etiket,
              suffixIcon: const Icon(Icons.calendar_month),
            ),
            child: Text(ms > 0 ? tarih(ms) : 'Seçin',
                style: const TextStyle(color: Renk.yazi, fontSize: 16)),
          ),
        );
      case AlanTip.tarla:
        final sT = (_d[a.key] ?? '').toString();
        final tT = widget.v.tarlalar;
        return DropdownButtonFormField<String>(
          initialValue: tT.any((t) => t.id == sT) ? sT : null,
          isExpanded: true,
          dropdownColor: Renk.kartAcik,
          decoration: InputDecoration(labelText: etiket),
          items: [
            for (final t in tT)
              DropdownMenuItem(
                value: t.id,
                child: Text(
                    '${widget.v.tarlaAdi(t.id)} · ${sayi(t.n('dekar'))} da · ${widget.v.tarlaSahibi(t.id)}',
                    overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (s) {
            _d[a.key] = s;
            _degisti(a.key);
          },
        );
      case AlanTip.tarlalar:
        final sL = <String>{
          if (_d[a.key] is List) for (final x in _d[a.key] as List) x.toString()
        };
        final tL = widget.v.tarlalar;
        final toplam = tL
            .where((t) => sL.contains(t.id))
            .fold(0.0, (s, t) => s + t.n('dekar'));
        return InputDecorator(
          decoration: InputDecoration(labelText: etiket),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (tL.isEmpty)
                const Text('Önce Tarlalarım bölümünden tarla ekleyin.',
                    style: yaziSoluk),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in tL)
                    FilterChip(
                      label: Text('${widget.v.tarlaAdi(t.id)} (${sayi(t.n('dekar'))} da)'),
                      selected: sL.contains(t.id),
                      onSelected: (s) {
                        if (s) {
                          sL.add(t.id);
                        } else {
                          sL.remove(t.id);
                        }
                        _d[a.key] = sL.toList();
                        _degisti(a.key);
                      },
                    ),
                ],
              ),
              if (tL.length > 1)
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        _d[a.key] = [for (final t in tL) t.id];
                        _degisti(a.key);
                      },
                      child: const Text('Hepsini seç'),
                    ),
                    TextButton(
                      onPressed: () {
                        _d[a.key] = <String>[];
                        _degisti(a.key);
                      },
                      child: const Text('Temizle'),
                    ),
                    const Spacer(),
                    if (sL.isNotEmpty)
                      Text('${sayi(toplam)} da', style: yaziSoluk),
                  ],
                ),
            ],
          ),
        );
      case AlanTip.anahtar:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(a.etiket, style: const TextStyle(color: Renk.yazi)),
          subtitle: a.ipucu == null ? null : Text(a.ipucu!, style: yaziSoluk),
          value: _d[a.key] == true,
          onChanged: (b) {
            _d[a.key] = b;
            _degisti(a.key);
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gorunen = [
      for (final a in widget.alanlar)
        if (a.gorunur == null || a.gorunur!(_d)) a
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.baslik),
        actions: [
          if (widget.onSil != null)
            IconButton(
              tooltip: 'Sil',
              icon: const Icon(Icons.delete_outline, color: Renk.kirmizi),
              onPressed: _sil,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            for (final a in gorunen) ...[
              _alan(a),
              if (a.aciklama != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(a.aciklama!, style: yaziSoluk),
                ),
              const SizedBox(height: 14),
            ],
            if (widget.ozet != null) ...[
              Panel(child: widget.ozet!(_d)),
            ],
            Buton(
              yazi: 'Kaydet',
              ikon: Icons.check,
              renk: ButonRenk.yesil,
              mesgul: _mesgul,
              yukseklik: 54,
              onTap: _kaydet,
            ),
          ],
        ),
      ),
    );
  }
}

/// Basit seçim penceresi (alt sayfa).
Future<String?> secimYap(BuildContext context, String baslik, List<String> secenekler) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(baslik, style: yaziKalin),
          ),
          for (final s in secenekler)
            ListTile(
              title: Text(s, style: const TextStyle(color: Renk.yazi)),
              onTap: () => Navigator.pop(c, s),
            ),
        ],
      ),
    ),
  );
}

/// Tek satırlık metin/sayı soran pencere.
Future<String?> metinSor(BuildContext context, String baslik,
    {String baslangic = '', String? ipucu, bool sayi = false}) {
  final c = TextEditingController(text: baslangic);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(baslik),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: sayi
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(hintText: ipucu),
        onSubmitted: (s) => Navigator.pop(ctx, s),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Tamam')),
      ],
    ),
  ).whenComplete(c.dispose);
}
