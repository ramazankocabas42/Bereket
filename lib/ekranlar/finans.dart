import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'ana.dart';
import 'banka_mesajlari.dart';
import 'hesaplar.dart';
import 'kabuk.dart';
import 'varliklar.dart';

class FinansSayfasi extends StatefulWidget {
  const FinansSayfasi({super.key, required this.durum, this.geri = false});
  final Durum durum;
  final bool geri;

  @override
  State<FinansSayfasi> createState() => _FinansSayfasiState();
}

class _FinansSayfasiState extends State<FinansSayfasi> {
  final _kg = TextEditingController(text: '10000');
  final _bugun = TextEditingController();
  final _sonra = TextEditingController();
  final _ay = TextEditingController(text: '3');
  final _faiz = TextEditingController(text: '3');
  final _depo = TextEditingController(text: '0');

  @override
  void dispose() {
    for (final c in [_kg, _bugun, _sonra, _ay, _faiz, _depo]) {
      c.dispose();
    }
    super.dispose();
  }

  Durum get durum => widget.durum;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.geri ? AppBar(title: const Text('Finans')) : null,
      body: SafeArea(
        child: Canli(
          durum: durum,
          builder: (context, v) {
            if (!durum.yuklendi) return const Center(child: CircularProgressIndicator());
            final simdi = DateTime.now().millisecondsSinceEpoch;
            final borc = v.toplamBorc();
            final gecikmis = v.gecikmisBorc(simdi);
            final krediler = v.hesaplar
                .where((h) =>
                    h.s('yon') != 'alacak' &&
                    (h.s('tur') == 'Kredi' || h.s('tur') == 'Kredi Kartı' || h.s('tur') == 'Banka'))
                .toList();
            // Yaklaşan taksitler (7 gün içinde ödeme günü olanlar)
            final bugun = DateTime.now();
            final yaklasan = v.hesaplar.where((h) {
              final g = h.n('odemeGunu').toInt();
              if (g <= 0 || v.bakiye(h) <= 0 || h.s('yon') == 'alacak') return false;
              var t = DateTime(bugun.year, bugun.month, g);
              if (t.isBefore(DateTime(bugun.year, bugun.month, bugun.day))) {
                t = DateTime(bugun.year, bugun.month + 1, g);
              }
              return t.difference(bugun).inDays <= 7;
            }).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                UstSayaclar(durum: durum, v: v),
                const SizedBox(height: 14),
                Panel(
                  kenarRengi: gecikmis > 0 ? Renk.kirmizi : null,
                  child: Row(
                    children: [
                      const Text('🏛️', style: TextStyle(fontSize: 44)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tl0(borc),
                                style: const TextStyle(
                                    color: Renk.altin, fontSize: 24, fontWeight: FontWeight.w900)),
                            const Text('Toplam borç', style: yaziSoluk),
                            if (gecikmis > 0) ...[
                              const SizedBox(height: 4),
                              Etiket('⚠ Ödeme gecikti · ${tl0(gecikmis)}', renk: Renk.kirmizi),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 110,
                        child: Buton(
                          yazi: 'Borçlarım',
                          yukseklik: 44,
                          onTap: () => git(context, HesaplarSayfasi(durum: durum, yon: 'borc')),
                        ),
                      ),
                    ],
                  ),
                ),
                Buton(
                  yazi: 'Banka mesajlarından borçları güncelle',
                  ikon: Icons.sms,
                  renk: ButonRenk.mor,
                  onTap: () => git(context, BankaMesajlari(durum: durum)),
                ),
                const SizedBox(height: 14),
                if (yaklasan.isNotEmpty)
                  Panel(
                    baslik: 'Yaklaşan ödemeler (7 gün)',
                    kenarRengi: Renk.turuncu,
                    child: Column(
                      children: [
                        for (final h in yaklasan)
                          Satir('${h.s('ad')} · ayın ${h.n('odemeGunu').toInt()}\'i',
                              h.n('taksitTutari') > 0 ? tl0(h.n('taksitTutari')) : tl0(v.bakiyeTl(h)),
                              renk: Renk.turuncu),
                      ],
                    ),
                  ),
                Panel(
                  baslik: 'Kredilerim',
                  eylem: TextButton(
                    onPressed: () => hesapFormu(context, durum, tur: 'Kredi'),
                    child: const Text('+ Ekle'),
                  ),
                  child: krediler.isEmpty
                      ? const Text('Ziraat, Tarım Kredi, ihtiyaç kredisi ve kredi kartlarınızı ekleyin.',
                          style: yaziSoluk)
                      : Column(
                          children: [
                            for (final h in krediler)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(h.s('ad'), style: const TextStyle(color: Renk.yazi)),
                                subtitle: Text(
                                    '${h.s('tur')}${h.n('taksitTutari') > 0 ? ' · taksit ${tl0(h.n('taksitTutari'))}' : ''}',
                                    style: yaziSoluk),
                                trailing: Text(tl0(v.bakiyeTl(h)),
                                    style: const TextStyle(
                                        color: Renk.altin, fontWeight: FontWeight.w800)),
                                onTap: () => git(context, HesapDetay(durum: durum, hesapId: h.id)),
                              ),
                          ],
                        ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: BuyukKart(
                        simge: '📥',
                        baslik: 'Alacaklarım',
                        renk1: const Color(0xFF2BB3A8),
                        renk2: const Color(0xFF16695F),
                        onTap: () => git(context, HesaplarSayfasi(durum: durum, yon: 'alacak')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BuyukKart(
                        simge: '🪙',
                        baslik: 'Varlıklarım',
                        renk1: const Color(0xFFC9932E),
                        renk2: const Color(0xFF7A5414),
                        onTap: () => git(context, VarliklarSayfasi(durum: durum)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _satBeklet(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _satBeklet() {
    final kg = sayiOku(_kg.text) ?? 0;
    final bugun = sayiOku(_bugun.text) ?? 0;
    final sonra = sayiOku(_sonra.text) ?? 0;
    final ay = sayiOku(_ay.text) ?? 0;
    final faiz = sayiOku(_faiz.text) ?? 0;
    final depo = sayiOku(_depo.text) ?? 0;
    final satNow = kg * bugun;
    final faizli = satNow * (1 + faiz / 100 * ay);
    final beklet = kg * sonra - (kg / 1000) * depo * ay;
    Widget kutu(TextEditingController c, String etiket, String birim) => Expanded(
          child: TextField(
            controller: c,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: etiket, suffixText: birim),
            onChanged: (_) => setState(() {}),
          ),
        );
    return Panel(
      baslik: 'Sat mı, Beklet mi?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [kutu(_kg, 'Miktar', 'kg'), const SizedBox(width: 8), kutu(_ay, 'Kaç ay', 'ay')]),
          const SizedBox(height: 8),
          Row(children: [
            kutu(_bugun, 'Bugünkü fiyat', '₺/kg'),
            const SizedBox(width: 8),
            kutu(_sonra, 'Beklenen fiyat', '₺/kg'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            kutu(_faiz, 'Aylık mevduat faizi', '%'),
            const SizedBox(width: 8),
            kutu(_depo, 'Depo masrafı', '₺/ton/ay'),
          ]),
          const SizedBox(height: 12),
          if (bugun > 0 && sonra > 0) ...[
            Satir('Bugün sat + faize yatır', tl0(faizli)),
            Satir('Beklet, ${sayi(ay)} ay sonra sat', tl0(beklet)),
            const SizedBox(height: 6),
            Text(
              faizli >= beklet
                  ? '✅ Bugün satmak ${tl0(faizli - beklet)} daha kârlı.'
                  : '⏳ Bekletmek ${tl0(beklet - faizli)} daha kârlı.',
              style: TextStyle(
                  color: faizli >= beklet ? Renk.yesil : Renk.altin,
                  fontSize: 16,
                  fontWeight: FontWeight.w800),
            ),
          ] else
            const Text('Bugünkü ve beklenen fiyatı yazın.', style: yaziSoluk),
        ],
      ),
    );
  }
}
