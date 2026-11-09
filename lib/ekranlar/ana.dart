import 'package:flutter/material.dart';

import '../bicim.dart';
import '../hesap.dart';
import '../modeller.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'aile.dart';
import 'arge.dart';
import 'belge_okut.dart';
import 'depo.dart';
import 'ekisler.dart';
import 'hesaplar.dart';
import 'isler.dart';
import 'kabuk.dart';
import 'pancar.dart';
import 'piyasa.dart';
import 'satislar.dart';
import 'tarlalar.dart';
import 'uretim.dart';
import 'defter.dart';
import 'ekipman.dart';
import 'finans.dart';
import 'varliklar.dart';

/// Üst sayaç çubuğu: bu yıl kâr, alacak, borç, depo değeri.
class UstSayaclar extends StatelessWidget {
  const UstSayaclar({super.key, required this.durum, required this.v});
  final Durum durum;
  final Veriler v;

  @override
  Widget build(BuildContext context) {
    final yil = DateTime.now().year;
    final o = v.yilOzet(yil);
    final depo = v.depo().fold(0.0, (a, d) => a + d.deger);
    return Row(
      children: [
        Expanded(
          child: SayacHapi(
            simge: '🌾',
            deger: kisaTl(o.tarimKar),
            etiket: '$yil KÂR',
            renk: Renk.altin,
            onTap: () => git(context, UretimSayfasi(durum: durum)),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SayacHapi(
            simge: '📥',
            deger: kisaTl(v.toplamAlacak()),
            etiket: 'ALACAK',
            renk: Renk.mor,
            onTap: () => git(context, HesaplarSayfasi(durum: durum, yon: 'alacak')),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SayacHapi(
            simge: '📤',
            deger: kisaTl(v.toplamBorc()),
            etiket: 'BORÇ',
            renk: Renk.kirmizi,
            onTap: () => git(context, HesaplarSayfasi(durum: durum, yon: 'borc')),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SayacHapi(
            simge: '🏪',
            deger: kisaTl(depo),
            etiket: 'DEPO',
            renk: Renk.yesil,
            onTap: () => git(context, DepoSayfasi(durum: durum)),
          ),
        ),
      ],
    );
  }
}

class AnaSayfa extends StatelessWidget {
  const AnaSayfa({super.key, required this.durum});
  final Durum durum;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Canli(
          durum: durum,
          builder: (context, v) {
            if (!durum.yuklendi) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                _baslik(context),
                const SizedBox(height: 10),
                UstSayaclar(durum: durum, v: v),
                const SizedBox(height: 12),
                Buton(
                  yazi: 'Fiş · Fatura · Dekont Çek',
                  ikon: Icons.photo_camera,
                  renk: ButonRenk.turuncu,
                  yukseklik: 56,
                  onTap: () => git(context, BelgeOkut(durum: durum)),
                ),
                const SizedBox(height: 14),
                _profilKarti(context, v),
                _isletmelerim(context, v),
                _buyukKartlar(context, v),
                if (durum.hata != null)
                  Panel(
                    kenarRengi: Renk.kirmizi,
                    child: Text(
                      'Bazı veriler okunamadı: ${hataYazisi(durum.hata!)}',
                      style: const TextStyle(color: Renk.kirmizi),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _baslik(BuildContext context) {
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => git(context, BelgeOkut(durum: durum)),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Renk.kart,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Renk.yesil, width: 1.6),
            ),
            alignment: Alignment.center,
            child: const Text('📷', style: TextStyle(fontSize: 24)),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(colors: [Renk.yesil, Renk.yesilKoyu]),
            border: Border.all(color: Renk.altin, width: 2.5),
          ),
          child: const Text('BEREKET',
              style: TextStyle(
                  color: Renk.altin,
                  fontSize: 26,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black54, offset: Offset(0, 2))])),
        ),
        const Spacer(),
        const SizedBox(
          width: 48,
          height: 48,
          child: Center(child: Text('🚜', style: TextStyle(fontSize: 30))),
        ),
      ],
    );
  }

  Widget _profilKarti(BuildContext context, Veriler v) {
    final i = durum.isletme!;
    final yil = DateTime.now().year;
    final buYil = v.ekimler.where((e) => e.t('yil') == yil).toList();
    double dekar(Kayit e) => v.tarla(e.s('tarlaId'))?.n('dekar') ?? 0;
    final ekili = buYil.fold(0.0, (a, e) => a + dekar(e));
    final hasat = buYil
        .where((e) => e.s('durum') == 'Hasat edildi')
        .fold(0.0, (a, e) => a + dekar(e));
    final acikIs = v.isler.where((x) => !x.b('tamam')).length;
    return Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(colors: [Renk.kartAcik, Renk.zemin]),
                  border: Border.all(color: Renk.altin, width: 3),
                ),
                alignment: Alignment.center,
                child: const Text('👨‍🌾', style: TextStyle(fontSize: 44)),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => git(context, IslerSayfasi(durum: durum)),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 82,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: Renk.zeminAlt,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Renk.cizgi, width: 2),
                      ),
                      child: const Column(
                        children: [
                          Text('Görevler',
                              style: TextStyle(
                                  color: Renk.yazi,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700)),
                          Text('📋', style: TextStyle(fontSize: 24)),
                        ],
                      ),
                    ),
                    if (acikIs > 0)
                      Positioned(
                        right: -4,
                        top: -6,
                        child: CircleAvatar(
                          radius: 11,
                          backgroundColor: Renk.kirmizi,
                          child: Text('$acikIs',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Renk.zeminAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Renk.cizgi),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i.ad.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Renk.yazi,
                              fontSize: 17,
                              fontWeight: FontWeight.w900)),
                      Text(
                          'Toplam arazi: ${sayi(v.toplamDekar)} da · ${v.tarlalar.length} parsel',
                          style: yaziSoluk),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                            colors: [Renk.altin, Color(0xFFC99A2E)]),
                      ),
                      child: Text(durum.yonetici ? 'SAHİP' : 'ÜYE',
                          style: const TextStyle(
                              color: Color(0xFF3A2A00),
                              fontSize: 12,
                              fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(durum.isim(durum.uid),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Renk.altin,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Cubuk(
                  oran: ekili > 0 ? hasat / ekili : 0,
                  yazi: '${sayi(hasat)}/${sayi(ekili)} da hasat',
                ),
                const SizedBox(height: 6),
                Text(
                  ekili <= 0
                      ? '$yil için henüz ekim girilmedi'
                      : 'Hasat edilecek ${sayi(ekili - hasat)} dekar kaldı',
                  textAlign: TextAlign.center,
                  style: yaziSoluk,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _isletmelerim(BuildContext context, Veriler v) {
    final yil = DateTime.now().year;
    final depoTon = v.depo().fold(0.0, (a, d) => a + d.kalan) / 1000;
    final bekleyen = v.satislar.where((s) => v.satisHesap(s).kalan(s.n('tahsil')) > 1).length;
    final borcSayisi = v.hesaplar.where((h) => h.s('yon') != 'alacak' && v.bakiye(h) > 0).length;
    final gecikme = v.gecikmisBorc(DateTime.now().millisecondsSinceEpoch) > 0;
    final kareler = [
      Kare(
        simge: '🗺️',
        baslik: 'Tarlalarım',
        ust: '${v.tarlalar.length} Parsel',
        renk: const Color(0xFF3F6B3A),
        onTap: () => git(context, TarlalarSayfasi(durum: durum)),
      ),
      Kare(
        simge: '🌱',
        baslik: 'Üretim',
        ust: '${v.ekimler.where((e) => e.t('yil') == yil).length} Ekim',
        renk: const Color(0xFF6B5A2E),
        onTap: () => git(context, UretimSayfasi(durum: durum)),
      ),
      Kare(
        simge: '💰',
        baslik: 'Satışlarım',
        ust: '${v.satislar.where((s) => s.yil == yil).length} Satış',
        renk: const Color(0xFF34508F),
        rozet: bekleyen > 0,
        onTap: () => git(context, SatislarSayfasi(durum: durum)),
      ),
      Kare(
        simge: '🏭',
        baslik: 'Depo',
        ust: '${sayi(depoTon)} Ton',
        renk: const Color(0xFF4A5468),
        onTap: () => git(context, DepoSayfasi(durum: durum)),
      ),
      Kare(
        simge: '📈',
        baslik: 'Piyasa',
        ust: 'Borsa · TMO',
        renk: const Color(0xFF5B3FA8),
        onTap: () => git(context, PiyasaSayfasi(durum: durum)),
      ),
      Kare(
        simge: '📤',
        baslik: 'Borçlarım',
        ust: '$borcSayisi Hesap',
        renk: const Color(0xFF7A3A3A),
        rozet: gecikme,
        onTap: () => git(context, HesaplarSayfasi(durum: durum, yon: 'borc')),
      ),
    ];
    return Panel(
      baslik: 'İşletmelerim',
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
        children: kareler,
      ),
    );
  }

  Widget _buyukKartlar(BuildContext context, Veriler v) {
    final simdi = DateTime.now();
    final maasBekleyen = v.isyerleri
        .where((i) => v.maasDurum(i, simdi) != MaasDurum.yatti)
        .isNotEmpty;
    Widget satir(Widget a, Widget b) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Expanded(child: a),
            const SizedBox(width: 12),
            Expanded(child: b),
          ]),
        );
    return Column(
      children: [
        satir(
          BuyukKart(
            simge: '💼',
            baslik: 'Ek İşler',
            alt: 'Maaş ve diğer gelirler',
            renk1: const Color(0xFF3B6FD0),
            renk2: const Color(0xFF203F86),
            rozet: maasBekleyen ? 'Maaş' : null,
            onTap: () => git(context, EkIslerSayfasi(durum: durum)),
          ),
          BuyukKart(
            simge: '🟣',
            baslik: 'Pancar & Koop.',
            alt: 'Kota · fabrika · kooperatif',
            renk1: const Color(0xFF8E5BE8),
            renk2: const Color(0xFF4B2A9C),
            onTap: () => git(context, PancarSayfasi(durum: durum)),
          ),
        ),
        satir(
          BuyukKart(
            simge: '👨‍👩‍👦',
            baslik: 'Aile Hesapları',
            alt: 'Babam · Kardeşim',
            renk1: const Color(0xFF2E8B57),
            renk2: const Color(0xFF1C5A37),
            onTap: () => git(context, AileSayfasi(durum: durum)),
          ),
          BuyukKart(
            simge: '🔬',
            baslik: 'Ar-Ge',
            alt: 'Verimlilik · girdi fiyatı',
            renk1: const Color(0xFF3A4A6B),
            renk2: const Color(0xFF1E2A44),
            onTap: () => git(context, ArgeSayfasi(durum: durum)),
          ),
        ),
        satir(
          BuyukKart(
            simge: '🏦',
            baslik: 'Finans',
            alt: 'Kredi · varlık · sat/beklet',
            renk1: const Color(0xFFC9932E),
            renk2: const Color(0xFF7A5414),
            onTap: () => git(context, FinansSayfasi(durum: durum, geri: true)),
          ),
          BuyukKart(
            simge: '📥',
            baslik: 'Alacaklarım',
            alt: 'Tüccar · kişi · kira',
            renk1: const Color(0xFF2BB3A8),
            renk2: const Color(0xFF16695F),
            onTap: () => git(context, HesaplarSayfasi(durum: durum, yon: 'alacak')),
          ),
        ),
        satir(
          BuyukKart(
            simge: '📒',
            baslik: 'Gelir - Gider',
            alt: 'Bütün para hareketleri',
            renk1: const Color(0xFF4F6B8F),
            renk2: const Color(0xFF253A57),
            onTap: () => git(context, DefterSayfasi(durum: durum)),
          ),
          BuyukKart(
            simge: '🧰',
            baslik: 'Malzemelerim',
            alt: 'Traktör · sulama · araba',
            renk1: const Color(0xFF7A6A4F),
            renk2: const Color(0xFF433824),
            onTap: () => git(context, EkipmanSayfasi(durum: durum)),
          ),
        ),
        satir(
          BuyukKart(
            simge: '🏡',
            baslik: 'Ev Alma Hedefi',
            alt: v.evHedefi(DateTime.now()) == null
                ? 'Hedef belirle'
                : 'Bu ay ${tl0(v.evHedefi(DateTime.now())!.aylik)}',
            renk1: const Color(0xFFD9775A),
            renk2: const Color(0xFF8A3B25),
            onTap: () => git(context, EvHedefiSayfasi(durum: durum)),
          ),
          BuyukKart(
            simge: '🪙',
            baslik: 'Varlıklarım',
            alt: 'Birikim · net durum',
            renk1: const Color(0xFFB8A040),
            renk2: const Color(0xFF6B5A14),
            onTap: () => git(context, VarliklarSayfasi(durum: durum)),
          ),
        ),
      ],
    );
  }
}
