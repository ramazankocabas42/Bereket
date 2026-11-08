import 'package:flutter/material.dart';

import '../bicim.dart';
import '../modeller.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'form.dart';
import 'kabuk.dart';

Future<void> isFormu(BuildContext context, Durum durum, {Kayit? is_}) {
  final v = durum.v;
  final kisiler = <String>{
    ...v.sahipler(),
    for (final u in durum.isletme?.uyeler ?? const <String>[]) durum.isim(u),
  }.toList();
  return formAc(
    context,
    baslik: is_ == null ? 'Yeni Görev' : 'Görevi Düzenle',
    v: v,
    baslangic: {'tarih': DateTime.now().millisecondsSinceEpoch, ...?is_?.d},
    alanlar: [
      const Alan('baslik', 'Ne yapılacak', zorunlu: true, oneriler: [
        'Sulama', 'İlaçlama', 'Gübreleme', 'Çapa', 'Ekim', 'Hasat', 'Sürüm', 'Fatura öde',
      ]),
      const Alan('tarlaId', 'Tarla', tip: AlanTip.tarla),
      const Alan('tarih', 'Ne zaman', tip: AlanTip.tarih),
      Alan('atanan', 'Kim yapacak', oneriler: kisiler),
      const Alan('not', 'Not', tip: AlanTip.uzun),
      const Alan('tamam', 'Yapıldı', tip: AlanTip.anahtar),
    ],
    onKaydet: (d) => durum.kaydet('isler', d, id: is_?.id),
    onSil: is_ == null ? null : () => durum.sil('isler', is_.id),
  );
}

class IslerSayfasi extends StatefulWidget {
  const IslerSayfasi({super.key, required this.durum});
  final Durum durum;

  @override
  State<IslerSayfasi> createState() => _IslerSayfasiState();
}

class _IslerSayfasiState extends State<IslerSayfasi> {
  bool _bitenler = false;

  @override
  Widget build(BuildContext context) {
    final durum = widget.durum;
    return Sayfa(
      baslik: 'Görevler',
      durum: durum,
      fab: ekleButonu('Görev Ekle', () => isFormu(context, durum)),
      builder: (context, v) {
        final bugun = DateTime.now();
        final gunBasi = DateTime(bugun.year, bugun.month, bugun.day).millisecondsSinceEpoch;
        final l = v.isler.where((x) => _bitenler || !x.b('tamam')).toList()
          ..sort((a, b) => a.t('tarih').compareTo(b.t('tarih')));
        return [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _bitenler,
            onChanged: (b) => setState(() => _bitenler = b),
            title: const Text('Yapılanları da göster', style: TextStyle(color: Renk.soluk)),
          ),
          if (l.isEmpty)
            const BosDurum(simge: '📋', yazi: 'Açık görev yok. Sulama, ilaçlama, hasat gibi işleri ekleyip kişilere atayabilirsiniz.'),
          for (final x in l)
            Panel(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              kenarRengi: !x.b('tamam') && x.t('tarih') > 0 && x.t('tarih') < gunBasi
                  ? Renk.kirmizi
                  : null,
              onTap: () => isFormu(context, durum, is_: x),
              child: Row(
                children: [
                  Checkbox(
                    value: x.b('tamam'),
                    onChanged: (b) async {
                      try {
                        await durum.kaydet('isler', {'tamam': b == true}, id: x.id);
                      } catch (e) {
                        if (context.mounted) bildir(context, hataYazisi(e));
                      }
                    },
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(x.s('baslik'),
                            style: TextStyle(
                                color: Renk.yazi,
                                fontWeight: FontWeight.w700,
                                decoration: x.b('tamam') ? TextDecoration.lineThrough : null)),
                        Text(
                            [
                              tarih(x.t('tarih')),
                              if (x.s('tarlaId').isNotEmpty) v.tarlaAdi(x.s('tarlaId')),
                              if (x.s('atanan').isNotEmpty) '👤 ${x.s('atanan')}',
                            ].join(' · '),
                            style: yaziSoluk),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ];
      },
    );
  }
}
