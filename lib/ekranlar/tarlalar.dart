import 'package:flutter/material.dart';

import '../bicim.dart';
import '../hesap.dart';
import '../modeller.dart';
import '../sabitler.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'form.dart';
import 'kabuk.dart';
import 'uretim.dart';

const _gecmisYilSayisi = 5;

/// Ortak ekim alanları: "Ortak ekiliyor" + her kişi için pay (%).
List<Alan> ortakAlanlari(List<String> sahipler,
        {bool Function(Map<String, dynamic> d)? gorunur}) =>
    [
      Alan('ortak', 'Ortak ekiliyor', tip: AlanTip.anahtar,
          ipucu: 'Masraf, hasat, satış, destek ve kâr paylara göre bölünür.',
          gorunur: gorunur),
      for (final k in sahipler)
        Alan('o_$k', '$k payı', tip: AlanTip.sayi, birim: '%',
            gorunur: (d) => d['ortak'] == true && (gorunur == null || gorunur(d))),
    ];

void ortakDoldur(Map<String, dynamic> bas, Map<String, dynamic> ortaklar) {
  if (ortaklar.isEmpty) return;
  bas['ortak'] = true;
  ortaklar.forEach((k, v) => bas['o_$k'] = v);
}

/// Form değerlerinden 'ortaklar' haritasını kurar, geçici alanları siler.
void ortakTopla(Map<String, dynamic> d) {
  final ortak = d.remove('ortak') == true;
  final m = <String, double>{};
  for (final k in d.keys.where((k) => k.startsWith('o_')).toList()) {
    final v = d.remove(k);
    if (ortak && v is num && v > 0) m[k.substring(2)] = v.toDouble();
  }
  d['ortaklar'] = m;
}

/// Tarla ekle / düzenle.
Future<void> tarlaFormu(BuildContext context, Durum durum, {Kayit? tarla}) {
  final v = durum.v;
  final sahipler = v.sahipler();
  final buYil = DateTime.now().year;
  final bas = <String, dynamic>{
    'cks': 'Babam',
    'mulkiyet': 'Kendi',
    'sahip': Veriler.ben,
    'gelirSahibi': Veriler.ben,
    'ilce': 'Karapınar',
    ...?tarla?.d,
  };
  if (tarla != null) {
    tarla.m('gecmis').forEach((y, u) => bas['g$y'] = u.toString());
    ortakDoldur(bas, tarla.m('ortaklar'));
  }
  bool kiralik(Map<String, dynamic> d) =>
      (d['mulkiyet'] ?? '').toString() != 'Kendi' &&
      (d['mulkiyet'] ?? '').toString() != 'Ortak';
  bool baskasiEkiyor(Map<String, dynamic> d) => d['sahip'] == baskasi;
  final urunAdlari = ['Boş / nadas', for (final u in urunler) u.ad];
  final kiraVerenler = <String>{
    'Milli Emlak',
    for (final t in v.tarlalar)
      if (t.s('kiraVeren').isNotEmpty) t.s('kiraVeren'),
  }.toList();
  return formAc(
    context,
    baslik: tarla == null ? 'Yeni Tarla' : 'Tarlayı Düzenle',
    v: v,
    baslangic: bas,
    alanlar: [
      const Alan('ad', 'Tarla adı / mevki', ipucu: 'Örn. Kuyu başı', zorunlu: true),
      const Alan('ilce', 'İlçe', oneriler: ['Karapınar', 'Ereğli', 'Çumra', 'Karatay']),
      const Alan('mahalle', 'Mahalle / köy', oneriler: ['Hotamış']),
      const Alan('ada', 'Ada'),
      const Alan('parsel', 'Parsel'),
      const Alan('dekar', 'Alan', tip: AlanTip.sayi, birim: 'dekar', zorunlu: true),
      Alan('cks', 'ÇKS kimin üzerine', tip: AlanTip.secim,
          secenekler: [...sahipler, cksBizdeDegil]),
      const Alan('mulkiyet', 'Arazinin durumu', tip: AlanTip.secim, secenekler: mulkiyetler),
      Alan('kira', 'Yıllık kira / ecrimisil bedeli',
          tip: AlanTip.sayi, birim: '₺', gorunur: kiralik,
          aciklama: 'Her yıl bu tarlanın maliyetine eklenir.'),
      Alan('kiraVeren', 'Kime ödeniyor', gorunur: kiralik, oneriler: kiraVerenler),
      Alan('sahip', 'Kim ekiyor', tip: AlanTip.secim,
          secenekler: [...sahipler, baskasi],
          aciklama: 'Maliyet, satış ve kâr bu kişinin hesabına yazılır.'),
      ...ortakAlanlari(sahipler, gorunur: (d) => !baskasiEkiyor(d)),
      Alan('kiraci', 'Eken kişinin adı', gorunur: baskasiEkiyor),
      Alan('kiraGeliri', 'Aldığımız yıllık kira', tip: AlanTip.sayi, birim: '₺',
          gorunur: baskasiEkiyor),
      Alan('gelirSahibi', 'Kira geliri kimin', tip: AlanTip.secim,
          secenekler: sahipler, gorunur: baskasiEkiyor),
      Alan('destekSahibi', 'Mazot-gübre desteği kimin', tip: AlanTip.secim,
          secenekler: ['', ...sahipler],
          gorunur: (d) => !kiralik(d),
          aciklama: 'Boşsa ÇKS sahibine yazılır. Ürün desteği her zaman ekene yazılır.'),
      for (var i = 1; i <= _gecmisYilSayisi; i++)
        Alan('g${buYil - i}', '${buYil - i} yılında ekilen',
            tip: AlanTip.secim, secenekler: urunAdlari,
            aciklama: i == 1 ? 'Münavebe için geçmiş yıllar (ÇKS\'den).' : null),
      const Alan('not', 'Not', tip: AlanTip.uzun),
    ],
    onKaydet: (d) async {
      final gecmis = <String, String>{};
      if (tarla != null) {
        tarla.m('gecmis').forEach((k, x) => gecmis[k] = x.toString());
      }
      for (var i = 1; i <= _gecmisYilSayisi; i++) {
        final k = 'g${buYil - i}';
        final u = (d.remove(k) ?? '').toString();
        if (u.isEmpty || u == 'Boş / nadas') {
          gecmis.remove('${buYil - i}');
        } else {
          gecmis['${buYil - i}'] = u;
        }
      }
      d.removeWhere((k, _) => RegExp(r'^g\d{4}$').hasMatch(k));
      d['gecmis'] = gecmis;
      ortakTopla(d);
      if (d['sahip'] != baskasi) {
        d['kiraci'] = null;
        d['kiraGeliri'] = null;
      }
      await durum.kaydet('tarlalar', d, id: tarla?.id);
    },
    onSil: tarla == null ? null : () => durum.sil('tarlalar', tarla.id),
  );
}

/// Ekim / hasat kaydı.
Future<void> ekimFormu(BuildContext context, Durum durum,
    {Kayit? ekim, String? tarlaId, String? urun}) {
  final v = durum.v;
  if (v.tarlalar.isEmpty) {
    bildir(context, 'Önce bir tarla ekleyin.');
    return Future.value();
  }
  final bas = <String, dynamic>{
    'yil': DateTime.now().year,
    'durum': 'Ekildi',
    'tarlaId': tarlaId ?? '',
    if (urun != null) 'urun': urun,
    'sahip': '',
    ...?ekim?.d,
  };
  if (ekim != null) ortakDoldur(bas, ekim.m('ortaklar'));
  return formAc(
    context,
    baslik: ekim == null ? 'Ekim / Hasat' : 'Ekimi Düzenle',
    v: v,
    baslangic: bas,
    alanlar: [
      const Alan('tarlaId', 'Tarla', tip: AlanTip.tarla, zorunlu: true),
      const Alan('yil', 'Sezon (yıl)', tip: AlanTip.yil),
      Alan('urun', 'Ürün', tip: AlanTip.secim,
          secenekler: [for (final u in urunler) u.ad], zorunlu: true),
      Alan('sahip', 'Bu yıl kim ekiyor', tip: AlanTip.secim,
          secenekler: ['', ...v.sahipler()],
          aciklama: 'Boş bırakırsanız tarlada seçili kişi geçerli olur.'),
      ...ortakAlanlari(v.sahipler()),
      const Alan('durum', 'Durum', tip: AlanTip.secim, secenekler: ekimDurumlari),
      const Alan('ekimTarihi', 'Ekim tarihi', tip: AlanTip.tarih),
      Alan('hasatKg', 'Hasat edilen miktar', tip: AlanTip.sayi, birim: 'kg',
          gorunur: (d) => d['durum'] == 'Hasat edildi',
          aciklama: 'Depoya bu miktar girer.'),
      Alan('hasatTarihi', 'Hasat tarihi', tip: AlanTip.tarih,
          gorunur: (d) => d['durum'] == 'Hasat edildi'),
      const Alan('not', 'Not', tip: AlanTip.uzun),
    ],
    ozet: (d) {
      final t = v.tarla((d['tarlaId'] ?? '').toString());
      final u = (d['urun'] ?? '').toString();
      final y = d['yil'] is num ? (d['yil'] as num).toInt() : DateTime.now().year;
      if (t == null || u.isEmpty) {
        return const Text('Tarla ve ürün seçince münavebe kontrol edilir.',
            style: yaziSoluk);
      }
      final m = v.munavebe(t, u, y);
      return MunavebeSatiri(m);
    },
    onKaydet: (d) async {
      if (d['durum'] != 'Hasat edildi') {
        d['hasatKg'] = null;
        d['hasatTarihi'] = null;
      }
      ortakTopla(d);
      await durum.kaydet('ekimler', d, id: ekim?.id);
    },
    onSil: ekim == null ? null : () => durum.sil('ekimler', ekim.id),
  );
}

class MunavebeSatiri extends StatelessWidget {
  const MunavebeSatiri(this.m, {super.key});
  final Munavebe m;

  @override
  Widget build(BuildContext context) {
    final renk = switch (m.seviye) {
      0 => Renk.yesil,
      1 => Renk.turuncu,
      _ => Renk.kirmizi,
    };
    final simge = switch (m.seviye) { 0 => '✅', 1 => '⚠️', _ => '⛔' };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(simge, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(child: Text(m.mesaj, style: TextStyle(color: renk, fontSize: 14.5))),
      ],
    );
  }
}

/// "Ne ekeyim?" önerileri.
Future<void> neEkeyim(BuildContext context, Durum durum, Kayit tarla) {
  final v = durum.v;
  final yil = DateTime.now().month >= 8 ? DateTime.now().year + 1 : DateTime.now().year;
  final oneriler = v.neEkeyim(tarla, yil);
  final gecmis = v.urunGecmisi(tarla);
  final yillar = gecmis.keys.toList()..sort((a, b) => b.compareTo(a));
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (c, kontrol) => ListView(
        controller: kontrol,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text('${v.tarlaAdi(tarla.id)} · $yil için ne ekilsin?', style: yaziKalin),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final y in yillar.take(6))
                Etiket('$y: ${gecmis[y]}', renk: Renk.kartAcik, simge: urunSimge(gecmis[y]!)),
            ],
          ),
          if (yillar.isEmpty)
            const Text('Geçmiş yıl bilgisi yok. Tarlayı düzenleyip son yıllarda ne ekildiğini girerseniz öneriler daha doğru olur.',
                style: yaziSoluk),
          const SizedBox(height: 12),
          for (final o in oneriler)
            Panel(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              kenarRengi: o.munavebe.seviye == 0
                  ? Renk.yesil
                  : (o.munavebe.seviye == 1 ? Renk.turuncu : Renk.cizgi),
              onTap: o.munavebe.seviye == 2
                  ? null
                  : () {
                      Navigator.pop(c);
                      ekimFormu(context, durum, tarlaId: tarla.id, urun: o.urun);
                    },
              child: Row(
                children: [
                  Text(urunSimge(o.urun), style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.urun, style: yaziKalin),
                        MunavebeSatiri(o.munavebe),
                      ],
                    ),
                  ),
                  if (o.dekarKar != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(tl0(o.dekarKar!),
                            style: TextStyle(
                                color: o.dekarKar! >= 0 ? Renk.yesil : Renk.kirmizi,
                                fontWeight: FontWeight.w800)),
                        const Text('dekar kârı', style: yaziSoluk),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class TarlalarSayfasi extends StatefulWidget {
  const TarlalarSayfasi({super.key, required this.durum});
  final Durum durum;

  @override
  State<TarlalarSayfasi> createState() => _TarlalarSayfasiState();
}

class _TarlalarSayfasiState extends State<TarlalarSayfasi> {
  String _filtre = 'Hepsi';
  String _ara = '';
  final Set<String> _secili = {};

  Durum get durum => widget.durum;

  bool _uyar(Veriler v, Kayit t) {
    final s = v.tarlaSahibi(t.id);
    final m = t.s('mulkiyet');
    switch (_filtre) {
      case 'Hepsi':
        return true;
      case 'Benim ektiklerim':
        return s == Veriler.ben;
      case 'Kiraladıklarımız':
        return m == 'Kiralık' || m.startsWith('Hazine');
      case 'Başkasına verilenler':
        return s == baskasi;
      case 'ÇKS bizde olmayanlar':
        return t.s('cks') == cksBizdeDegil;
      default:
        return s == _filtre;
    }
  }

  Future<void> _topluAta() async {
    final v = durum.v;
    final kim = await secimYap(context, '${_secili.length} parseli kim ekiyor?',
        [...v.sahipler(), baskasi]);
    if (kim == null) return;
    try {
      for (final id in _secili) {
        await durum.kaydet('tarlalar', {'sahip': kim}, id: id);
      }
      if (mounted) {
        bildir(context, '${_secili.length} parsel "$kim" olarak işaretlendi.');
        setState(_secili.clear);
      }
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    }
  }

  void _cksBilgi() {
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('ÇKS Yükle'),
        content: const Text(
          'ÇKS belgesini (e-Devlet ya da Ziraat Odası çıktısı) otomatik okuma, '
          'örnek bir belge gönderdiğinizde bir sonraki sürümde eklenecek.\n\n'
          'Şimdilik parselleri "Tarla Ekle" ile girip, her tarlanın son yıllarda '
          'ne ekildiğini düzenleme ekranından seçebilirsiniz. Münavebe ve '
          '"Ne ekeyim?" bu bilgiyle çalışır.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tamam')),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              tarlaFormu(context, durum);
            },
            child: const Text('Tarla Ekle'),
          ),
        ],
      ),
    );
  }

  Future<void> _neEkeyimSec() async {
    final v = durum.v;
    if (v.tarlalar.isEmpty) {
      bildir(context, 'Önce tarla ekleyin.');
      return;
    }
    final adlar = {for (final t in v.tarlalar) v.tarlaAdi(t.id): t};
    final s = await secimYap(context, 'Hangi tarla?', adlar.keys.toList());
    if (s != null && mounted) await neEkeyim(context, durum, adlar[s]!);
  }

  @override
  Widget build(BuildContext context) {
    final secimModu = _secili.isNotEmpty;
    return Sayfa(
      baslik: secimModu ? '${_secili.length} seçili' : 'Tarlalarım',
      durum: durum,
      eylemler: [
        if (secimModu) ...[
          TextButton.icon(
            onPressed: _topluAta,
            icon: const Icon(Icons.person_pin_circle_outlined),
            label: const Text('Kim ekiyor?'),
          ),
          IconButton(
              onPressed: () => setState(_secili.clear),
              icon: const Icon(Icons.close)),
        ],
      ],
      fab: secimModu ? null : ekleButonu('Tarla Ekle', () => tarlaFormu(context, durum)),
      builder: (context, v) {
        final yil = DateTime.now().year;
        final ekiliIds = {
          for (final e in v.ekimler)
            if (e.t('yil') == yil) e.s('tarlaId')
        };
        double da(Iterable<Kayit> l) => l.fold(0.0, (a, t) => a + t.n('dekar'));
        final ekili = v.tarlalar.where((t) => ekiliIds.contains(t.id));
        final bos = v.tarlalar.where((t) => !ekiliIds.contains(t.id));
        final filtreler = [
          'Hepsi',
          'Benim ektiklerim',
          ...v.sahipler().where((s) => s != Veriler.ben),
          'Kiraladıklarımız',
          'Başkasına verilenler',
          'ÇKS bizde olmayanlar',
        ];
        final a = araMetni(_ara);
        final liste = v.tarlalar
            .where((t) => _uyar(v, t))
            .where((t) =>
                a.isEmpty ||
                araMetni('${t.s('ad')} ${t.s('mahalle')} ${t.s('ada')}/${t.s('parsel')}')
                    .contains(a))
            .toList()
          ..sort((x, y) => v.tarlaAdi(x.id).compareTo(v.tarlaAdi(y.id)));
        return [
          Panel(
            child: Column(
              children: [
                const Text('🗺️', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Buton(
                          yazi: 'ÇKS Yükle', renk: ButonRenk.yesil, onTap: _cksBilgi),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Buton(yazi: 'Ne Ekeyim?', onTap: _neEkeyimSec),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: BilgiKutu(
                          baslik: 'Boş tarlalar ($yil)',
                          deger: '${bos.length} · ${sayi(da(bos))} da'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: BilgiKutu(
                          baslik: 'Ekili tarlalar',
                          deger: '${ekili.length} · ${sayi(da(ekili))} da'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SecimSatiri(
            secenekler: filtreler,
            secili: filtreler.contains(_filtre) ? _filtre : 'Hepsi',
            onSec: (s) => setState(() => _filtre = s),
          ),
          const SizedBox(height: 8),
          if (v.tarlalar.length > 5)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                decoration: const InputDecoration(
                    hintText: 'Ara (ad, köy, ada/parsel)...',
                    prefixIcon: Icon(Icons.search)),
                onChanged: (s) => setState(() => _ara = s),
              ),
            ),
          if (v.tarlalar.isEmpty)
            BosDurum(
              simge: '🌾',
              yazi: 'Henüz tarla yok. Parsellerinizi ekleyin; ÇKS\'deki ada/parsel ve dekar bilgisi yeterli.',
              butonYazi: 'Tarla Ekle',
              onTap: () => tarlaFormu(context, durum),
            )
          else if (liste.isEmpty)
            const BosDurum(simge: '🔎', yazi: 'Bu filtrede tarla yok.'),
          for (final t in liste) _tarlaKarti(context, v, t, yil),
          if (v.tarlalar.isNotEmpty && !secimModu)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'İpucu: Bir karta uzun basıp birden çok parsel seçerek "kim ekiyor" bilgisini toplu değiştirebilirsiniz.',
                textAlign: TextAlign.center,
                style: yaziSoluk,
              ),
            ),
        ];
      },
    );
  }

  Widget _tarlaKarti(BuildContext context, Veriler v, Kayit t, int yil) {
    final gecmis = v.urunGecmisi(t);
    final yillar = gecmis.keys.toList()..sort((a, b) => b.compareTo(a));
    final buYilUrun = gecmis[yil];
    final sahip = v.tarlaSahibi(t.id);
    final secili = _secili.contains(t.id);
    final m = buYilUrun == null ? null : v.munavebe(t, buYilUrun, yil);
    final ekimler = v.tarlaEkimleri(t.id);
    final kira = t.n('kira');
    return GestureDetector(
      onLongPress: () => setState(() => _secili.add(t.id)),
      child: Panel(
        kenarRengi: secili ? Renk.altin : null,
        onTap: _secili.isNotEmpty
            ? () => setState(() => secili ? _secili.remove(t.id) : _secili.add(t.id))
            : () => tarlaFormu(context, durum, tarla: t),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (_secili.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(secili ? Icons.check_circle : Icons.circle_outlined,
                        color: secili ? Renk.altin : Renk.soluk),
                  ),
                Expanded(
                  child: Text(v.tarlaAdi(t.id),
                      style: const TextStyle(
                          color: Renk.yazi, fontSize: 19, fontWeight: FontWeight.w800)),
                ),
                Text(
                  [t.s('mahalle'), t.s('ilce')].where((x) => x.isNotEmpty).join('/'),
                  style: const TextStyle(color: Renk.yazi, fontSize: 14),
                ),
                const Text(' 📍'),
              ],
            ),
            const Divider(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Renk.zeminAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Renk.cizgi, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(buYilUrun == null ? '🟫' : urunSimge(buYilUrun),
                      style: const TextStyle(fontSize: 38)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      Satir('Ada / Parsel', '${t.s('ada').isEmpty ? '-' : t.s('ada')} / ${t.s('parsel').isEmpty ? '-' : t.s('parsel')}'),
                      Satir('Alan', '${sayi(t.n('dekar'))} dekar'),
                      Satir('Arazi', t.s('mulkiyet').isEmpty ? 'Kendi' : t.s('mulkiyet')),
                      if (kira > 0) Satir(kiraKalemi(t.s('mulkiyet')), tl0(kira)),
                      Satir('$yil', buYilUrun ?? 'Ekilmedi',
                          renk: buYilUrun == null ? Renk.soluk : Renk.altin),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Etiket('ÇKS: ${t.s('cks').isEmpty ? '-' : t.s('cks')}', renk: Renk.mor),
                Etiket(
                    sahip == baskasi
                        ? 'Eken: ${t.s('kiraci').isEmpty ? baskasi : t.s('kiraci')}'
                        : (v.tarlaPaylari(t.id).length > 1
                            ? 'Ortak: ${v.tarlaPaylari(t.id).entries.map((e) => '${e.key} %${(e.value * 100).round()}').join(', ')}'
                            : 'Eken: $sahip'),
                    renk: sahip == Veriler.ben ? Renk.yesilKoyu : Renk.maviKoyu),
                if (sahip == baskasi && t.n('kiraGeliri') > 0)
                  Etiket('Kira geliri ${tl0(t.n('kiraGeliri'))}', renk: Renk.turkuaz),
              ],
            ),
            if (yillar.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final y in yillar.where((y) => y != yil).take(4))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Renk.zeminAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Renk.cizgi),
                      ),
                      child: Text('$y ${urunSimge(gecmis[y]!)} ${gecmis[y]}',
                          style: const TextStyle(color: Renk.soluk, fontSize: 12.5)),
                    ),
                ],
              ),
            ],
            if (m != null) ...[
              const SizedBox(height: 8),
              MunavebeSatiri(m),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Buton(
                    yazi: ekimler.any((e) => e.t('yil') == yil) ? 'Tarlayı Yönet' : 'Ekim Gir',
                    yukseklik: 44,
                    onTap: () {
                      final buYil = ekimler.where((e) => e.t('yil') == yil).toList();
                      if (buYil.isEmpty) {
                        ekimFormu(context, durum, tarlaId: t.id);
                      } else {
                        git(context, EkimDetay(durum: durum, ekimId: buYil.first.id));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Buton(
                    yazi: 'Ne Ekeyim?',
                    renk: ButonRenk.mor,
                    yukseklik: 44,
                    onTap: () => neEkeyim(context, durum, t),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
