import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdfx/pdfx.dart';

import '../belge.dart';
import '../bicim.dart';
import '../ekstre.dart';
import '../modeller.dart';
import '../sabitler.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'belge_arsiv.dart';
import 'form.dart';
import 'uretim.dart';

/// Kamerayla belge okutma: fiş, fatura, el yazısı hesap. Okunanı özetler,
/// onay alınca ilgili bölüme işler.
class BelgeOkut extends StatefulWidget {
  const BelgeOkut({super.key, required this.durum});
  final Durum durum;

  @override
  State<BelgeOkut> createState() => _BelgeOkutState();
}

/// Belgenin nereye işleneceği.
enum _Hedef { evGider, tarlaGider, araba, borcOdeme }

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
  String? _arsivYolu;
  bool _sakla = true;
  String _odemeHesap = '';
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
        _arsivYolu = x.path;
        _ozet = null;
      });
      await _oku([x.path]);
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    } finally {
      if (mounted) setState(() => _okunuyor = false);
    }
  }

  /// Görüntü dosyalarındaki yazıyı okuyup özete çevirir.
  Future<void> _oku(List<String> yollar) async {
    final okuyucu = TextRecognizer(script: TextRecognitionScript.latin);
    final b = StringBuffer();
    try {
      for (final y in yollar) {
        final sonuc = await okuyucu.processImage(InputImage.fromFilePath(y));
        b.writeln(sonuc.text);
      }
    } finally {
      await okuyucu.close();
    }
    _metin = b.toString();
    if (_metin.trim().isEmpty) {
      throw 'Belgede yazı bulunamadı. Daha aydınlık ve düz bir fotoğraf deneyin.';
    }
    _yerlestir(belgeCoz(_metin));
  }

  /// PDF ya da resim dosyası (Gmail'den kaydedilen ekstre / fatura).
  Future<void> _dosya() async {
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (r == null || r.files.isEmpty) return;
      final f = r.files.first;
      final bytes = f.bytes;
      if (bytes == null) throw 'Dosya okunamadı.';
      setState(() {
        _okunuyor = true;
        _ozet = null;
        _resim = null;
      });
      final gecici = Directory.systemTemp.createTempSync('belge');
      final yollar = <String>[];
      if (f.name.toLowerCase().endsWith('.pdf')) {
        final doc = await PdfDocument.openData(bytes);
        try {
          final sayfa = doc.pagesCount < 3 ? doc.pagesCount : 3;
          for (var i = 1; i <= sayfa; i++) {
            final p = await doc.getPage(i);
            try {
              final img = await p.render(
                width: p.width * 2.5,
                height: p.height * 2.5,
                format: PdfPageImageFormat.png,
                backgroundColor: '#FFFFFF',
              );
              if (img == null) continue;
              final yol = '${gecici.path}/s$i.png';
              File(yol).writeAsBytesSync(img.bytes);
              yollar.add(yol);
            } finally {
              await p.close();
            }
          }
        } finally {
          await doc.close();
        }
      } else {
        final yol = '${gecici.path}/${f.name}';
        File(yol).writeAsBytesSync(bytes);
        yollar.add(yol);
      }
      if (yollar.isEmpty) throw 'Dosyadan sayfa çıkarılamadı.';
      _arsivYolu = yollar.first;
      if (mounted) setState(() => _resim = File(yollar.first));
      await _oku(yollar);
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    } finally {
      if (mounted) setState(() => _okunuyor = false);
    }
  }

  /// Faturadaki abone numarasına göre sayaç.
  Kayit? _sayacBul(String aboneNo) {
    if (aboneNo.isEmpty) return null;
    for (final s in durum.v.sayaclar) {
      final a = s.s('aboneNo').replaceAll(RegExp(r'\D'), '');
      if (a.isNotEmpty && (a == aboneNo || aboneNo.endsWith(a) || a.endsWith(aboneNo))) return s;
    }
    return null;
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
        _evKategori = 'Elektrik';
        _tarlaKalem = 'Elektrik';
        final sayac = _sayacBul(o.aboneNo);
        _hedef = sayac != null ? _Hedef.tarlaGider : _Hedef.evGider;
        _sayac = sayac?.id ?? '';
      case BelgeTuru.tarim:
        _hedef = _Hedef.tarlaGider;
        _tarlaKalem = o.kalem ?? 'Gübre';
      case BelgeTuru.dekont:
        final aday = _borcAdaylari(o.firma, o.toplam);
        _tarlaKalem = o.kalem ?? 'Diğer';
        _evKategori = evKategorisiTahmin(_metin);
        if (aday.isNotEmpty) {
          _hedef = _Hedef.borcOdeme;
          _odemeHesap = aday.first.id;
        } else {
          _hedef = o.kalem != null ? _Hedef.tarlaGider : _Hedef.evGider;
        }
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

  /// Bakiyesi olan borç hesapları; dekonttaki alıcıya ve tutara en uyan başta.
  List<Kayit> _borcAdaylari(String firma, double tutar, {bool hepsi = false}) {
    final v = durum.v;
    final f = araMetni(firma);
    int puan(Kayit h) {
      var p = 0;
      final ad = araMetni(h.s('ad'));
      final ilk = ad.split(' ').first;
      if (f.isNotEmpty && ilk.length >= 3 && (f.contains(ilk) || ad.contains(f.split(' ').first))) p += 2;
      final tol = tutar * 0.01 < 1 ? 1 : tutar * 0.01;
      if ((v.bakiye(h) - tutar).abs() <= tol) p += 2;
      if (h.n('taksitTutari') > 0 && (h.n('taksitTutari') - tutar).abs() <= tol) p += 2;
      return p;
    }

    final l = [
      for (final h in v.hesaplar)
        if (h.s('yon') != 'alacak' && v.bakiye(h) > 0.5 && (hepsi || puan(h) > 0)) h
    ];
    l.sort((a, b) => puan(b).compareTo(puan(a)));
    return l;
  }

  /// Aynı tutarda, yakın tarihte zaten girilmiş gider (mükerrer uyarısı).
  List<Kayit> _benzerGiderler(double tutar, int tarihMs) {
    if (tutar <= 0) return const [];
    return [
      for (final g in durum.v.giderler)
        if ((g.n('tutar') - tutar).abs() <= 0.5 &&
            (g.t('tarih') - tarihMs).abs() <= const Duration(days: 10).inMilliseconds)
          g
    ];
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
      final yol = _arsivYolu;
      final belgeId = _sakla && yol != null
          ? await belgeArsivle(durum, yol, {
              'tur': o.tur.name,
              'firma': firma,
              'tutar': o.tur == BelgeTuru.elYazisi ? o.toplam : tutar,
              'tarih': o.tarih,
            })
          : null;
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
                'belgeId': belgeId,
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
                'belgeId': belgeId,
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
        final sayacK = durum.v.bul('sayaclar', _sayac);
        if (_hedef == _Hedef.tarlaGider &&
            _tarlaKalem == 'Elektrik' &&
            sayacK != null &&
            sayacK.b('ortak')) {
          // Ortak kuyu: sayaç başlangıç-bitiş değerleri gerekli, forma geç.
          final nav = Navigator.of(context);
          nav.pop();
          await giderFormu(nav.context, durum, hazir: {
            'kalem': 'Elektrik',
            'sayac': sayacK.s('ad'),
            'faturaKwh': o.kwh,
            'faturaTutar': tutar,
            'tarih': o.tarih,
            'yil': t.year,
            'tedarikci': firma.isEmpty ? sayacK.s('kurum') : firma,
            'odeme': 'Tamamını ben ödedim',
            'aciklama': 'Fatura ${o.aboneNo}',
            'belgeId': belgeId,
          });
          return;
        }
        if (_hedef == _Hedef.borcOdeme) {
          if (_odemeHesap.isEmpty) throw 'Ödenen borcu seçin.';
          await Veri.hareketEkle(durum.iid, _odemeHesap,
              tip: 'odeme',
              tutar: tutar,
              aciklama: ['Dekont', if (firma.isNotEmpty) firma].join(' · '),
              tarih: o.tarih);
          // Aynı tutarda ödenmemiş fatura varsa ödendi işaretle.
          for (final g in v.giderler) {
            if (g.d['odendi'] == false && (g.n('tutar') - tutar).abs() <= 0.5) {
              await durum.kaydet('giderler', {'odendi': true, if (belgeId != null) 'odemeBelgeId': belgeId},
                  id: g.id);
              break;
            }
          }
          if (mounted) bildir(context, 'Ödeme borçtan düşüldü.');
          if (mounted) Navigator.of(context).pop();
          return;
        }
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
            'belgeId': belgeId,
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
            'belgeId': belgeId,
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
      appBar: AppBar(
        title: const Text('Fiş · Fatura · Dekont'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => BelgelerSayfasi(durum: durum))),
            icon: const Icon(Icons.folder_open, color: Renk.altin),
            label: const Text('Belgelerim', style: TextStyle(color: Renk.altin)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Fiş, fatura, ödeme dekontu, POS slip ya da el yazısı hesabı düz bir zeminde, iyi ışıkta çekin. '
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
                const SizedBox(height: 10),
                Buton(
                  yazi: 'Dosyadan oku (PDF)',
                  ikon: Icons.picture_as_pdf,
                  renk: ButonRenk.mor,
                  onTap: _okunuyor ? null : _dosya,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Gmail\'e gelen ekstre ya da faturayı açıp "İndir / Kaydet" deyin, sonra buradan seçin.',
                  style: yaziSoluk,
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
    final borclar = _borcAdaylari(_firma.text, sayiOku(_toplam.text) ?? o.toplam, hepsi: true);
    final benzer = o.tur == BelgeTuru.elYazisi || _hedef == _Hedef.borcOdeme
        ? const <Kayit>[]
        : _benzerGiderler(sayiOku(_toplam.text) ?? o.toplam, o.tarih);
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
                  if (borclar.isNotEmpty)
                    ChoiceChip(
                      label: const Text('💳 Borç ödemesi'),
                      selected: _hedef == _Hedef.borcOdeme,
                      onSelected: (_) => setState(() {
                        _hedef = _Hedef.borcOdeme;
                        if (_odemeHesap.isEmpty) _odemeHesap = borclar.first.id;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (_hedef == _Hedef.borcOdeme)
                DropdownButtonFormField<String>(
                  initialValue: borclar.any((h) => h.id == _odemeHesap) ? _odemeHesap : null,
                  isExpanded: true,
                  dropdownColor: Renk.kartAcik,
                  decoration: const InputDecoration(labelText: 'Hangi borç ödendi?'),
                  items: [
                    for (final h in borclar)
                      DropdownMenuItem(
                          value: h.id,
                          child: Text('${h.s('ad')} · kalan ${tl0(v.bakiye(h))}',
                              overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (x) => setState(() => _odemeHesap = x ?? ''),
                ),
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
      if (benzer.isNotEmpty)
        Panel(
          kenarRengi: Renk.turuncu,
          child: Text(
            '⚠️ Bu tutarda kayıt zaten var: '
            '${benzer.map((g) => '${g.s('kalem')} ${g.s('aciklama')} (${tarih(g.t('tarih'))})').join(', ')}. '
            'Aynı harcamanın faturası ve dekontu ise tekrar eklemeyin.',
            style: const TextStyle(color: Renk.yazi, height: 1.35),
          ),
        ),
      if (_arsivYolu != null)
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          value: _sakla,
          onChanged: (b) => setState(() => _sakla = b),
          title: const Text('📎 Belgenin fotoğrafını sakla', style: TextStyle(color: Renk.yazi)),
          subtitle: const Text('Kayda eklenir, sonra Belgelerim\'den açabilirsiniz.', style: yaziSoluk),
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
      _Hedef.borcOdeme =>
        'Borç ödemesi → ${durum.v.bul('hesaplar', _odemeHesap)?.s('ad') ?? 'borç seçin'}',
      _Hedef.tarlaGider => 'Tarla gideri → $_tarlaKalem'
          '${_tarlalar.isEmpty ? '' : ' (${_tarlalar.length} tarlaya dekara göre)'}',
    };
    final sayacK = durum.v.bul('sayaclar', _sayac);
    final elektrikEk = o.tur == BelgeTuru.elektrik
        ? '${o.aboneNo.isEmpty ? '' : 'Abone ${o.aboneNo} · '}'
            '${o.kwh == null ? '' : '${sayi(o.kwh!)} kWh · '}'
            '${sayacK == null ? 'kayıtlı sayaç bulunamadı' : 'Sayaç: ${sayacK.s('ad')}${sayacK.b('ortak') ? ' (ortak kuyu → başlangıç/bitiş değerleri sorulacak)' : ''}'}\n'
        : '';
    return '${belgeTuruAdi[o.tur]}\n$elektrikEk'
        '${_firma.text.isEmpty ? '' : '${_firma.text} · '}${tarih(o.tarih)}'
        '${litre != null && litre > 0 ? ' · ${sayi(litre)} lt' : ''}\n'
        'Tutar: ${tl(tutar)}\n'
        '→ $nereye${_hedef == _Hedef.tarlaGider && !_odendi ? ' · borç olarak' : ''}';
  }
}
