import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as im;

import '../bicim.dart';
import '../servis/veri.dart';
import '../tema.dart';

/// Belge fotoğrafını küçültür (en çok ~600 KB JPEG); Firestore belgesine sığar.
Uint8List? _kucult(Uint8List ham) {
  final r = im.decodeImage(ham);
  if (r == null) return null;
  final x = r.width > 1100 ? im.copyResize(r, width: 1100) : r;
  var q = 60;
  var out = im.encodeJpg(x, quality: q);
  while (out.length > 600000 && q > 25) {
    q -= 15;
    out = im.encodeJpg(x, quality: q);
  }
  return out;
}

/// Fiş / fatura / dekont fotoğrafını "belgeler" koleksiyonuna saklar, kimliğini döner.
/// Hata olursa null (kaydın kendisi yine eklenir).
Future<String?> belgeArsivle(Durum d, String yol, Map<String, dynamic> bilgi) async {
  try {
    final ham = await File(yol).readAsBytes();
    final k = await compute(_kucult, ham);
    if (k == null) return null;
    return await d.kaydet('belgeler', {...bilgi, 'resim': base64Encode(k)});
  } catch (_) {
    return null;
  }
}

Future<void> belgeGoster(BuildContext context, Durum d, String id) => Navigator.of(context)
    .push(MaterialPageRoute(builder: (_) => BelgeGorunum(durum: d, id: id)));

/// Kayda bağlı belgenin fotoğrafı (yakınlaştırılabilir).
class BelgeGorunum extends StatelessWidget {
  const BelgeGorunum({super.key, required this.durum, required this.id});
  final Durum durum;
  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Belge')),
      body: FutureBuilder(
        future: Veri.kol(durum.iid, 'belgeler').doc(id).get(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return snap.hasError
                ? Center(child: Text(hataYazisi(snap.error!), style: yaziSoluk))
                : const Center(child: CircularProgressIndicator());
          }
          final d = snap.data!.data();
          if (d == null) return const BosDurum(simge: '🗑️', yazi: 'Belge silinmiş.');
          final resim = base64Decode((d['resim'] ?? '') as String);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  [
                    if ((d['firma'] ?? '') != '') d['firma'],
                    if (d['tarih'] is int) tarih(d['tarih'] as int),
                    if (d['tutar'] is num) tl((d['tutar'] as num).toDouble()),
                  ].join(' · '),
                  style: const TextStyle(color: Renk.yazi, fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Center(child: Image.memory(resim)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Saklanan bütün fiş, fatura ve dekontlar (en yeni 40).
class BelgelerSayfasi extends StatelessWidget {
  const BelgelerSayfasi({super.key, required this.durum});
  final Durum durum;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Belgelerim')),
      body: FutureBuilder(
        future: Veri.kol(durum.iid, 'belgeler').orderBy('olusturma', descending: true).limit(40).get(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return snap.hasError
                ? Center(child: Text(hataYazisi(snap.error!), style: yaziSoluk))
                : const Center(child: CircularProgressIndicator());
          }
          final l = snap.data!.docs;
          if (l.isEmpty) {
            return const BosDurum(simge: '📎', yazi: 'Henüz saklanan belge yok. Belge okuturken fotoğraf saklanır.');
          }
          return GridView.count(
            crossAxisCount: 2,
            padding: const EdgeInsets.all(12),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.78,
            children: [
              for (final b in l)
                InkWell(
                  onTap: () => belgeGoster(context, durum, b.id),
                  child: Panel(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(base64Decode((b.data()['resim'] ?? '') as String),
                                fit: BoxFit.cover, gaplessPlayback: true),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text((b.data()['firma'] ?? '').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Renk.yazi, fontWeight: FontWeight.w700)),
                        Text(
                            [
                              if (b.data()['tarih'] is int) tarih(b.data()['tarih'] as int),
                              if (b.data()['tutar'] is num) tl0((b.data()['tutar'] as num).toDouble()),
                            ].join(' · '),
                            style: yaziSoluk),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
