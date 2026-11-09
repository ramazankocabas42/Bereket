import 'package:flutter/material.dart';

import '../hesap.dart';
import '../servis/guncelleme.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'ana.dart';
import 'banka_mesajlari.dart';
import 'belge_arsiv.dart';
import 'belge_okut.dart';
import 'ev.dart';
import 'hesaplar.dart';
import 'isler.dart';
import 'profil.dart';
import 'raporlar.dart';
import 'satislar.dart';
import 'tarlalar.dart';
import 'uretim.dart';
import 'ekisler.dart';

/// Durum değiştikçe yeniden çizen yardımcı.
class Canli extends StatelessWidget {
  const Canli({super.key, required this.durum, required this.builder});

  final Durum durum;
  final Widget Function(BuildContext context, Veriler v) builder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: durum,
        builder: (c, _) => builder(c, durum.v),
      );
}

void git(BuildContext context, Widget sayfa) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => sayfa));

/// Alt çubuklu ana iskelet.
class Kabuk extends StatefulWidget {
  const Kabuk({super.key, required this.durum});
  final Durum durum;

  @override
  State<Kabuk> createState() => _KabukState();
}

class _KabukState extends State<Kabuk> {
  int _sekme = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Guncelleme.kontrolEt(context);
    });
  }

  void _hizliEkle() {
    final d = widget.durum;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) {
        Widget oge(String simge, String yazi, VoidCallback f) => ListTile(
              leading: Text(simge, style: const TextStyle(fontSize: 26)),
              title: Text(yazi,
                  style: const TextStyle(
                      color: Renk.yazi, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(c);
                f();
              },
            );
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              oge('📷', 'Fiş · fatura · dekont · slip çek', () => git(context, BelgeOkut(durum: d))),
              oge('📎', 'Belgelerim (saklanan fişler)', () => git(context, BelgelerSayfasi(durum: d))),
              oge('💬', 'Banka mesajlarını tara (SMS)', () => git(context, BankaMesajlari(durum: d))),
              oge('🧾', 'Tarla gideri / fatura', () => giderFormu(context, d)),
              oge('🚜', 'Makine işçiliği / yevmiye', () => giderFormu(context, d, iscilik: true)),
              oge('💰', 'Satış', () => satisFormu(context, d)),
              oge('🌱', 'Ekim / hasat', () => ekimFormu(context, d)),
              oge('🗺️', 'Tarla', () => tarlaFormu(context, d)),
              oge('📤', 'Borç / ödeme', () => git(context, HesaplarSayfasi(durum: d, yon: 'borc'))),
              oge('💵', 'Gelir (maaş, diğer)', () => gelirFormu(context, d)),
              oge('🏠', 'Ev harcaması', () => giderFormu(context, d, ev: true)),
              oge('📄', 'Banka ekstresi yükle', () => git(context, EkstreYukle(durum: d))),
              oge('📋', 'Görev', () => isFormu(context, d)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.durum;
    final sayfalar = [
      AnaSayfa(durum: d),
      EvButcesiSayfasi(durum: d, geri: false),
      RaporlarSayfasi(durum: d),
      ProfilSayfasi(durum: d),
    ];
    return Scaffold(
      body: IndexedStack(index: _sekme, children: sayfalar),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Renk.kartAcik, Renk.zemin],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Renk.cizgi, width: 1.5)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 74,
            child: Row(
              children: [
                _altOge(0, '🏡', 'Ana'),
                _altOge(1, '🏠', 'Ev Bütçem'),
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: _hizliEkle,
                      child: Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Renk.mavi, Renk.maviKoyu],
                          ),
                          border: Border.all(color: const Color(0xFF7FA6F0), width: 3),
                          boxShadow: const [
                            BoxShadow(color: Color(0x884C7DD9), blurRadius: 14),
                          ],
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 36),
                      ),
                    ),
                  ),
                ),
                _altOge(2, '📊', 'Raporlar'),
                _altOge(3, '👤', 'Profil'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _altOge(int i, String simge, String yazi) {
    final secili = _sekme == i;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _sekme = i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: secili ? 1.15 : 1,
              duration: const Duration(milliseconds: 150),
              child: Text(simge, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(height: 2),
            Text(yazi,
                style: TextStyle(
                    color: secili ? Renk.altin : Renk.soluk,
                    fontSize: 12,
                    fontWeight: secili ? FontWeight.w800 : FontWeight.w500)),
            const SizedBox(height: 3),
            Container(
              height: 3,
              width: 34,
              decoration: BoxDecoration(
                color: secili ? Renk.mavi : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sayfa iskeleti: başlık + üst sayaçlar + kaydırılabilir içerik.
class Sayfa extends StatelessWidget {
  const Sayfa({
    super.key,
    required this.baslik,
    required this.durum,
    required this.builder,
    this.eylemler,
    this.fab,
    this.geri = true,
  });

  final String baslik;
  final Durum durum;
  final List<Widget> Function(BuildContext context, Veriler v) builder;
  final List<Widget>? eylemler;
  final Widget? fab;
  final bool geri;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(baslik),
        automaticallyImplyLeading: geri,
        actions: eylemler,
      ),
      floatingActionButton: fab,
      body: Canli(
        durum: durum,
        builder: (c, v) {
          if (!durum.yuklendi) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
            children: builder(c, v),
          );
        },
      ),
    );
  }
}

/// Sağ altta "Ekle" butonu.
Widget ekleButonu(String yazi, VoidCallback f) => FloatingActionButton.extended(
      backgroundColor: Renk.yesil,
      foregroundColor: Colors.white,
      onPressed: f,
      icon: const Icon(Icons.add),
      label: Text(yazi, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
