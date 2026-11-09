import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bicim.dart';
import '../hesap.dart';
import '../sabitler.dart';
import '../servis/guncelleme.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'form.dart';
import 'kabuk.dart';

class ProfilSayfasi extends StatelessWidget {
  const ProfilSayfasi({super.key, required this.durum});
  final Durum durum;

  Future<void> _sayiAyar(BuildContext context, String alan, String baslik, double mevcut) async {
    final s = await metinSor(context, baslik, baslangic: girdi(mevcut), sayi: true);
    final x = sayiOku(s);
    if (x == null) return;
    try {
      if (alan.startsWith('munavebe.')) {
        final urun = alan.substring('munavebe.'.length);
        await durum.ayarYaz('munavebe', {
          ...?durum.isletme?.munavebe,
          urun: x.round().clamp(1, 10),
        });
        return;
      }
      await durum.ayarYaz(alan, x);
    } catch (e) {
      if (context.mounted) bildir(context, hataYazisi(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil'), automaticallyImplyLeading: false),
      body: Canli(
        durum: durum,
        builder: (context, v) {
          if (!durum.yuklendi) return const Center(child: CircularProgressIndicator());
          final i = durum.isletme!;
          final yil = DateTime.now().year;
          final o = v.yilOzet(yil);
          final onceki = v.yilOzet(yil - 1);
          final buyume = onceki.net.abs() > 1 ? (o.net - onceki.net) / onceki.net.abs() * 100 : 0.0;
          final depo = v.depo().fold(0.0, (a, d) => a + d.deger);
          final krediBorcu = v.hesaplar
              .where((h) => h.s('yon') != 'alacak' && (h.s('tur') == 'Kredi' || h.s('tur') == 'Kredi Kartı'))
              .fold(0.0, (a, h) => a + v.bakiyeTl(h));
          final verimler = v.urunOzetleri(yil: yil, sahip: Veriler.ben).where((u) => u.verim > 0);
          final ortVerim = verimler.isEmpty
              ? 0.0
              : verimler.fold(0.0, (a, u) => a + u.verim) / verimler.length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
            children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 86,
                          height: 86,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(colors: [Renk.kartAcik, Renk.zemin]),
                            border: Border.all(color: Renk.altin, width: 3),
                          ),
                          alignment: Alignment.center,
                          child: const Text('👨‍🌾', style: TextStyle(fontSize: 46)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(i.ad,
                                  style: const TextStyle(
                                      color: Renk.yazi, fontSize: 20, fontWeight: FontWeight.w900)),
                              const Text('📍 Hotamış · Karapınar · Konya', style: yaziSoluk),
                              const SizedBox(height: 6),
                              Text('${durum.isim(durum.uid)} · ${durum.yonetici ? 'Sahip' : 'Üye'}',
                                  style: const TextStyle(
                                      color: Renk.altin, fontSize: 16, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: BilgiKutu(
                                baslik: 'İşletme değeri',
                                deger: tl0(v.toplamVarlik() + v.toplamEkipman() + depo + v.toplamAlacak() - v.toplamBorc()))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: BilgiKutu(
                                baslik: 'Toplam arazi',
                                deger: '${sayi(v.toplamDekar)} da · ${v.tarlalar.length}')),
                      ],
                    ),
                  ],
                ),
              ),
              Panel(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(child: Yuvarlak(simge: '🌾', deger: kisaTl(o.tarimKar), alt: '$yil kâr', renk: Renk.altin)),
                    Expanded(child: Yuvarlak(simge: '📐', deger: o.ekiliDekar > 0 ? kisaTl(o.dekarKar) : '-', alt: 'Dekar kârı', renk: Renk.yesil)),
                    Expanded(child: Yuvarlak(simge: '⚖️', deger: ortVerim > 0 ? '${sayi(ortVerim)} kg' : '-', alt: 'Ort. verim/da', renk: Renk.mavi)),
                    Expanded(child: Yuvarlak(simge: '💼', deger: kisaTl(o.maas + o.digerGelir + o.digerSatis), alt: 'Ek gelir', renk: Renk.mor)),
                  ],
                ),
              ),
              Panel(
                child: Row(
                  children: [
                    Expanded(child: _alt('🧮', tl0(v.toplamBorc()), 'Toplam borç')),
                    Expanded(child: _alt(buyume >= 0 ? '📈' : '📉', '%${buyume.toStringAsFixed(1)}', 'Büyüme')),
                    Expanded(child: _alt('💳', tl0(krediBorcu), 'Kredi borcu')),
                  ],
                ),
              ),
              _ayarlar(context, v),
              _ekip(context),
              if (durum.yonetici) _aile(context, v),
              Panel(
                baslik: 'Hesap',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(FirebaseAuth.instance.currentUser?.email ?? '', style: yaziSoluk),
                    const SizedBox(height: 4),
                    const Text(
                      'Keleş Satış\'a aynı e-postayla girdiğiniz için satışlarınız Satışlarım → '
                      '"Keleş Satış\'tan Al" ile Bereket\'e alınabilir.',
                      style: yaziSoluk,
                    ),
                    const SizedBox(height: 12),
                    Buton(
                      yazi: 'Çıkış Yap',
                      renk: ButonRenk.kirmizi,
                      onTap: () => FirebaseAuth.instance.signOut(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                        Guncelleme.buSurum > 0
                            ? 'Bereket · sürüm ${Guncelleme.buSurum}'
                            : 'Bereket · geliştirme sürümü',
                        textAlign: TextAlign.center,
                        style: yaziSoluk),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _alt(String simge, String deger, String baslik) => Row(
        children: [
          Text(simge, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(deger,
                      style: const TextStyle(color: Renk.yazi, fontWeight: FontWeight.w800)),
                ),
                Text(baslik, style: const TextStyle(color: Renk.soluk, fontSize: 11.5)),
              ],
            ),
          ),
        ],
      );

  Widget _ayarlar(BuildContext context, Veriler v) {
    final i = durum.isletme!;
    final sahipler = v.sahipler().where((s) => s != Veriler.ben).toList();
    Widget ayar(String baslik, String deger, VoidCallback f) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(baslik, style: const TextStyle(color: Renk.yazi)),
          trailing: Text(deger,
              style: const TextStyle(color: Renk.altin, fontWeight: FontWeight.w700)),
          onTap: f,
        );
    return Panel(
      baslik: 'Ayarlar',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ayar('Adınız', durum.isim(durum.uid), () async {
            final s = await metinSor(context, 'Adınız', baslangic: durum.isim(durum.uid));
            if (s == null || s.trim().length < 2) return;
            await Veri.kullanicilar.doc(durum.uid).set({'ad': s.trim()}, SetOptions(merge: true));
            durum.isimler[durum.uid] = s.trim();
          }),
          if (durum.yonetici)
            ayar('İşletme adı', i.ad, () async {
              final s = await metinSor(context, 'İşletme adı', baslangic: i.ad);
              if (s == null || s.trim().length < 2) return;
              try {
                await Veri.isletmeGuncelle(i.id, {'ad': s.trim()});
              } catch (e) {
                if (context.mounted) bildir(context, hataYazisi(e));
              }
            }),
          const Divider(height: 18),
          const Text('Hesap sahipleri (aile)', style: yaziSoluk),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              const Chip(label: Text(Veriler.ben)),
              for (final s in sahipler)
                InputChip(
                  label: Text(s),
                  onDeleted: () async {
                    final l = sahipler.where((x) => x != s).toList();
                    await durum.ayarYaz('sahipler', l);
                  },
                ),
              ActionChip(
                avatar: const Icon(Icons.add, size: 18),
                label: const Text('Kişi ekle'),
                onPressed: () async {
                  final s = await metinSor(context, 'Kişi adı', ipucu: 'Örn. Annem, Amcam');
                  if (s == null || s.trim().isEmpty) return;
                  await durum.ayarYaz('sahipler', {...sahipler, s.trim()}.toList());
                },
              ),
            ],
          ),
          const Divider(height: 18),
          const Text('Satış kesintileri ve nakliye', style: yaziSoluk),
          ayar('Stopaj (borsada tescilli)', '%${sayi(i.stopajBorsa)}',
              () => _sayiAyar(context, 'stopajBorsa', 'Stopaj % (borsa)', i.stopajBorsa)),
          ayar('Stopaj (borsa dışı)', '%${sayi(i.stopajDisi)}',
              () => _sayiAyar(context, 'stopajDisi', 'Stopaj % (borsa dışı)', i.stopajDisi)),
          ayar('SGK / Bağ-Kur kesintisi', '%${sayi(i.sgk)}',
              () => _sayiAyar(context, 'sgk', 'SGK kesintisi %', i.sgk)),
          ayar('Borsa tescil ücreti', '‰${sayi(i.tescilBinde)}',
              () => _sayiAyar(context, 'tescilBinde', 'Tescil ücreti (binde)', i.tescilBinde)),
          ayar('Nakliye (ton × km)', tl(i.nakliyeTonKm),
              () => _sayiAyar(context, 'nakliyeTonKm', 'Ton başına km ücreti ₺', i.nakliyeTonKm)),
          ayar('Gram altın fiyatı', i.altinGram > 0 ? tl(i.altinGram) : 'girilmedi',
              () => _sayiAyar(context, 'altinGram', 'Gram altın ₺', i.altinGram)),
          const Divider(height: 18),
          const Text('Münavebe: aynı ürün kaç yılda bir ekilir', style: yaziSoluk),
          for (final u in urunler.where((u) => {
                'Buğday', 'Arpa', 'Mısır', 'Şeker Pancarı', 'Ayçiçeği', 'Kuru Fasulye', 'Nohut', 'Patates',
                ...v.ekimler.map((e) => e.s('urun')),
              }.contains(u.ad)))
            ayar('${u.simge} ${u.ad}', '${v.araYil(u.ad)} yılda bir',
                () => _sayiAyar(context, 'munavebe.${u.ad}', '${u.ad}: kaç yılda bir?',
                    v.araYil(u.ad).toDouble())),
        ],
      ),
    );
  }

  Widget _aile(BuildContext context, Veriler v) {
    final i = durum.isletme!;
    final kisiler = v.sahipler().where((s) => s != Veriler.ben).toList();
    return Panel(
      baslik: 'Aile Üyeleri',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Babanız, kardeşiniz Bereket\'i kurup aile koduyla katılır. Yalnızca kendi tarla '
            'hesaplarını görür, sizinle alacak/verecek ekleyebilirler. Sizin diğer bilgilerinizi göremezler.',
            style: yaziSoluk,
          ),
          const SizedBox(height: 6),
          for (final e in i.aile.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Text('👤', style: TextStyle(fontSize: 22)),
              title: Text('${e.value} · ${durum.isim(e.key)}', style: const TextStyle(color: Renk.yazi)),
              trailing: IconButton(
                icon: const Icon(Icons.person_remove_outlined, color: Renk.kirmizi),
                onPressed: () async {
                  try {
                    await Veri.aileUyesiCikar(i.id, e.key);
                  } catch (err) {
                    if (context.mounted) bildir(context, hataYazisi(err));
                  }
                },
              ),
            ),
          const SizedBox(height: 6),
          Buton(
            yazi: 'Aile için kod oluştur',
            renk: ButonRenk.mor,
            yukseklik: 46,
            onTap: () async {
              final kim = await secimYap(context, 'Kimin için?', kisiler);
              if (kim == null) return;
              try {
                final kod = await Veri.aileKoduOlustur(i.id, kim);
                if (!context.mounted) return;
                await showDialog<void>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text('$kim için kod'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SelectableText(kod,
                            style: const TextStyle(
                                color: Renk.altin,
                                fontSize: 30,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        const Text(
                          'Bereket\'i kurup hesap açtıktan sonra "Davet kodu ile katıl" bölümüne bu kodu yazsın.',
                          style: yaziSoluk,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Clipboard.setData(ClipboardData(text: kod)),
                        child: const Text('Kopyala'),
                      ),
                      FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Tamam')),
                    ],
                  ),
                );
              } catch (err) {
                if (context.mounted) bildir(context, hataYazisi(err));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _ekip(BuildContext context) {
    final i = durum.isletme!;
    return Panel(
      baslik: 'Ekip',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final u in i.uyeler)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Text('👤', style: TextStyle(fontSize: 22)),
              title: Text(durum.isim(u), style: const TextStyle(color: Renk.yazi)),
              subtitle: Text(
                  u == i.sahip ? 'Sahip' : (i.yoneticiler.contains(u) ? 'Yönetici' : 'Üye'),
                  style: yaziSoluk),
              trailing: durum.yonetici && u != i.sahip && u != durum.uid
                  ? PopupMenuButton<String>(
                      onSelected: (s) async {
                        try {
                          if (s == 'cikar') {
                            await Veri.isletmeGuncelle(i.id, {
                              'uyeler': i.uyeler.where((x) => x != u).toList(),
                              'yoneticiler': i.yoneticiler.where((x) => x != u).toList(),
                            });
                          } else {
                            final y = i.yoneticiler.contains(u)
                                ? i.yoneticiler.where((x) => x != u).toList()
                                : [...i.yoneticiler, u];
                            await Veri.isletmeGuncelle(i.id, {'yoneticiler': y});
                          }
                        } catch (e) {
                          if (context.mounted) bildir(context, hataYazisi(e));
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                            value: 'yonetici',
                            child: Text(i.yoneticiler.contains(u)
                                ? 'Yöneticilikten al'
                                : 'Yönetici yap')),
                        const PopupMenuItem(value: 'cikar', child: Text('Ekipten çıkar')),
                      ],
                    )
                  : null,
            ),
          if (durum.yonetici) ...[
            const Divider(height: 18),
            const Text('Davet kodu: aile üyeleri ya da çalışanlar Bereket\'i kurup bu kodla katılır.',
                style: yaziSoluk),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    durum.davetKodu.isEmpty ? '...' : durum.davetKodu,
                    style: const TextStyle(
                        color: Renk.altin,
                        fontSize: 26,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w900),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Renk.soluk),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: durum.davetKodu));
                    bildir(context, 'Kod kopyalandı.');
                  },
                ),
                IconButton(
                  tooltip: 'Yeni kod',
                  icon: const Icon(Icons.refresh, color: Renk.soluk),
                  onPressed: () async {
                    try {
                      await Veri.kodYenile(i.id, durum.davetKodu);
                    } catch (e) {
                      if (context.mounted) bildir(context, hataYazisi(e));
                    }
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
