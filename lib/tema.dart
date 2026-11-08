import 'package:flutter/material.dart';

/// Koyu lacivert, oyun ekranı havasında tema: parlak kartlar, renkli
/// kabartma butonlar, üstte sayaç hapları.
class Renk {
  static const zemin = Color(0xFF070C18);
  static const zeminAlt = Color(0xFF0B1324);
  static const kart = Color(0xFF111A2E);
  static const kartAcik = Color(0xFF17223A);
  static const cizgi = Color(0xFF26324D);
  static const yazi = Color(0xFFFFFFFF);
  static const soluk = Color(0xFFB7C2DA);

  static const altin = Color(0xFFF5C451);
  static const yesil = Color(0xFF5DBB4F);
  static const yesilKoyu = Color(0xFF3E8E35);
  static const mavi = Color(0xFF4C7DD9);
  static const maviKoyu = Color(0xFF2F5BB0);
  static const mor = Color(0xFF7C5CE0);
  static const morKoyu = Color(0xFF5A3DB8);
  static const kirmizi = Color(0xFFE5534B);
  static const turuncu = Color(0xFFF09A3E);
  static const turkuaz = Color(0xFF2BB3A8);
  static const gri = Color(0xFF6B7690);
}

ThemeData temaOlustur() {
  final cs = const ColorScheme.dark().copyWith(
    primary: Renk.mavi,
    onPrimary: Colors.white,
    secondary: Renk.yesil,
    surface: Renk.kart,
    onSurface: Renk.yazi,
    onSurfaceVariant: Renk.soluk,
    outline: Renk.cizgi,
    outlineVariant: Renk.cizgi,
    error: Renk.kirmizi,
    primaryContainer: Renk.kartAcik,
    onPrimaryContainer: Renk.yazi,
    secondaryContainer: Renk.kartAcik,
    onSecondaryContainer: Renk.yazi,
  );
  final kenar = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Renk.cizgi),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: cs,
    scaffoldBackgroundColor: Renk.zemin,
    dividerColor: Renk.cizgi,
    dividerTheme: const DividerThemeData(color: Renk.cizgi, space: 1, thickness: 1),
    appBarTheme: const AppBarTheme(
      backgroundColor: Renk.zemin,
      foregroundColor: Renk.yazi,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
          fontSize: 21, fontWeight: FontWeight.w800, color: Renk.yazi),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Renk.zeminAlt,
      labelStyle: const TextStyle(color: Renk.soluk),
      hintStyle: const TextStyle(color: Renk.gri),
      border: kenar,
      enabledBorder: kenar,
      focusedBorder:
          kenar.copyWith(borderSide: const BorderSide(color: Renk.mavi, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Renk.mavi,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Renk.altin),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Renk.kart,
      selectedColor: Renk.maviKoyu,
      side: const BorderSide(color: Renk.cizgi),
      labelStyle: const TextStyle(color: Renk.yazi, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Renk.kart),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Renk.kart),
    popupMenuTheme: const PopupMenuThemeData(color: Renk.kartAcik),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Renk.kartAcik,
      contentTextStyle: const TextStyle(color: Renk.yazi, fontSize: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Renk.altin),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : Renk.soluk),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Renk.yesil : Renk.kartAcik),
    ),
  );
}

void bildir(BuildContext context, String mesaj) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mesaj)));
}

const yaziKalin = TextStyle(
    color: Renk.yazi, fontSize: 16, fontWeight: FontWeight.w700);
const yaziSoluk = TextStyle(color: Renk.soluk, fontSize: 13.5);

/// Lacivert, ince kenarlı yuvarlak kart.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    this.baslik,
    required this.child,
    this.eylem,
    this.padding,
    this.margin,
    this.onTap,
    this.kenarRengi,
  });

  final String? baslik;
  final Widget child;
  final Widget? eylem;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? kenarRengi;

  @override
  Widget build(BuildContext context) {
    final ic = Padding(
      padding: padding ?? const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (baslik != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(baslik!,
                      style: const TextStyle(
                          color: Renk.yazi,
                          fontSize: 19,
                          fontWeight: FontWeight.w800)),
                ),
                if (eylem != null) eylem!,
              ],
            ),
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              height: 2,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Renk.cizgi, Colors.transparent]),
              ),
            ),
          ],
          child,
        ],
      ),
    );
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Renk.kart,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kenarRengi ?? Renk.cizgi, width: 1.2),
      ),
      child: onTap == null
          ? ic
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: onTap,
                child: ic,
              ),
            ),
    );
  }
}

enum ButonRenk { yesil, mavi, mor, gri, kirmizi, turuncu }

(Color, Color) _butonRenkleri(ButonRenk r) => switch (r) {
      ButonRenk.yesil => (Renk.yesil, Renk.yesilKoyu),
      ButonRenk.mavi => (Renk.mavi, Renk.maviKoyu),
      ButonRenk.mor => (Renk.mor, Renk.morKoyu),
      ButonRenk.gri => (const Color(0xFF8C93A6), const Color(0xFF6A7186)),
      ButonRenk.kirmizi => (Renk.kirmizi, const Color(0xFFB23A33)),
      ButonRenk.turuncu => (Renk.turuncu, const Color(0xFFC0742A)),
    };

/// Altı gölgeli, kabartma oyun butonu.
class Buton extends StatelessWidget {
  const Buton({
    super.key,
    required this.yazi,
    required this.onTap,
    this.renk = ButonRenk.mavi,
    this.ikon,
    this.mesgul = false,
    this.yukseklik = 50,
  });

  final String yazi;
  final VoidCallback? onTap;
  final ButonRenk renk;
  final IconData? ikon;
  final bool mesgul;
  final double yukseklik;

  @override
  Widget build(BuildContext context) {
    final (acik, koyu) = _butonRenkleri(onTap == null ? ButonRenk.gri : renk);
    return Container(
      height: yukseklik,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [acik, koyu],
        ),
        boxShadow: [
          BoxShadow(color: koyu.withValues(alpha: 0.9), offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: mesgul ? null : onTap,
          child: Center(
            child: mesgul
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (ikon != null) ...[
                        Icon(ikon, color: Colors.white, size: 21),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Text(yazi,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                shadows: [
                                  Shadow(color: Colors.black38, offset: Offset(0, 1.5))
                                ])),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Üst çubuktaki sayaç hapı: solda emoji, içinde değer.
class SayacHapi extends StatelessWidget {
  const SayacHapi({
    super.key,
    required this.simge,
    required this.deger,
    required this.renk,
    this.etiket,
    this.onTap,
  });

  final String simge;
  final String deger;
  final Color renk;
  final String? etiket;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        padding: const EdgeInsets.only(left: 4, right: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1226),
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: renk, width: 2),
        ),
        child: Row(
          children: [
            Text(simge, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(deger,
                        style: const TextStyle(
                            color: Renk.yazi,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                  ),
                  if (etiket != null)
                    Text(etiket!,
                        maxLines: 1,
                        style: TextStyle(
                            color: renk, fontSize: 9.5, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// İşletmelerim ızgarasındaki renkli kare.
class Kare extends StatelessWidget {
  const Kare({
    super.key,
    required this.simge,
    required this.baslik,
    required this.ust,
    required this.renk,
    required this.onTap,
    this.rozet = false,
  });

  final String simge;
  final String baslik;
  final String ust;
  final Color renk;
  final VoidCallback onTap;
  final bool rozet;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: renk.withValues(alpha: 0.7), width: 1.6),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Renk.kart, renk.withValues(alpha: 0.35)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Column(
                  children: [
                    Text(ust,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Renk.yazi,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const Divider(height: 8, indent: 10, endIndent: 10),
                    Expanded(
                      child: Center(
                          child: FittedBox(
                              child: Text(simge,
                                  style: const TextStyle(fontSize: 40)))),
                    ),
                    Text(baslik,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Renk.yazi,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (rozet)
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Renk.kirmizi,
                shape: BoxShape.circle,
                border: Border.all(color: Renk.zemin, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

/// Ana sayfadaki büyük işlem kartı: koyu zemin, renkli kenar ve simge.
class BuyukKart extends StatelessWidget {
  const BuyukKart({
    super.key,
    required this.simge,
    required this.baslik,
    required this.renk1,
    required this.renk2,
    required this.onTap,
    this.alt,
    this.rozet,
  });

  final String simge;
  final String baslik;
  final Color renk1, renk2;
  final VoidCallback onTap;
  final String? alt;
  final String? rozet;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 108,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: renk1.withValues(alpha: 0.85), width: 1.6),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [renk2.withValues(alpha: 0.55), Renk.kart],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(simge, style: const TextStyle(fontSize: 30)),
                        const SizedBox(height: 4),
                        Text(baslik,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Renk.yazi,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800)),
                        if (alt != null)
                          Text(alt!,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Renk.soluk, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ),
                if (rozet != null)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Renk.kirmizi,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(rozet!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Küçük renkli etiket ("Hasat edildi", "Münavebeye uygun"...).
class Etiket extends StatelessWidget {
  const Etiket(this.yazi, {super.key, this.renk = Renk.yesil, this.simge});

  final String yazi;
  final Color renk;
  final String? simge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text('${simge == null ? '' : '$simge '}$yazi',
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }
}

/// "Boştaki Araziler / 8" gibi bilgi kutusu.
class BilgiKutu extends StatelessWidget {
  const BilgiKutu({
    super.key,
    required this.baslik,
    required this.deger,
    this.renk,
    this.onTap,
  });

  final String baslik;
  final String deger;
  final Color? renk;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Renk.zeminAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Renk.cizgi, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(baslik,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Renk.soluk, fontSize: 13.5)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(deger,
                    style: TextStyle(
                        color: renk ?? Renk.yazi,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sol başlık, sağ değer satırı.
class Satir extends StatelessWidget {
  const Satir(this.sol, this.sag, {super.key, this.renk, this.kalin = false});

  final String sol;
  final String sag;
  final Color? renk;
  final bool kalin;

  @override
  Widget build(BuildContext context) {
    final st = TextStyle(
      color: renk ?? Renk.yazi,
      fontSize: kalin ? 16 : 14.5,
      fontWeight: kalin ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
              child: Text(sol,
                  style: kalin
                      ? st.copyWith(color: Renk.yazi)
                      : const TextStyle(color: Renk.soluk, fontSize: 14.5))),
          Text(sag, style: st),
        ],
      ),
    );
  }
}

/// Yuvarlak istatistik (profil ekranındaki dörtlü).
class Yuvarlak extends StatelessWidget {
  const Yuvarlak({
    super.key,
    required this.simge,
    required this.deger,
    required this.alt,
    this.renk = Renk.mavi,
  });

  final String simge;
  final String deger;
  final String alt;
  final Color renk;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(colors: [Renk.kartAcik, Renk.zemin]),
            border: Border.all(color: renk, width: 2.5),
          ),
          alignment: Alignment.center,
          child: Text(simge, style: const TextStyle(fontSize: 28)),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(deger,
              style: TextStyle(
                  color: renk, fontSize: 15, fontWeight: FontWeight.w800)),
        ),
        Text(alt,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Renk.soluk, fontSize: 12)),
      ],
    );
  }
}

/// Boş liste gösterimi.
class BosDurum extends StatelessWidget {
  const BosDurum({
    super.key,
    required this.simge,
    required this.yazi,
    this.butonYazi,
    this.onTap,
  });

  final String simge;
  final String yazi;
  final String? butonYazi;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(simge, style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 10),
          Text(yazi,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Renk.soluk, fontSize: 15)),
          if (butonYazi != null && onTap != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: 240,
              child: Buton(yazi: butonYazi!, onTap: onTap, renk: ButonRenk.yesil),
            ),
          ],
        ],
      ),
    );
  }
}

/// İnce ilerleme çubuğu (sezon ilerlemesi gibi).
class Cubuk extends StatelessWidget {
  const Cubuk({super.key, required this.oran, required this.yazi});

  final double oran;
  final String yazi;

  @override
  Widget build(BuildContext context) {
    final o = oran.isNaN ? 0.0 : oran.clamp(0.0, 1.0).toDouble();
    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: const Color(0xFF0A1226),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Renk.cizgi, width: 2),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: o,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                gradient: const LinearGradient(colors: [Renk.mavi, Color(0xFF7FA6F0)]),
              ),
            ),
          ),
          Center(
            child: Text(yazi,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Seçim çipleri satırı (Hepsi / Ben / Babam...).
class SecimSatiri extends StatelessWidget {
  const SecimSatiri({
    super.key,
    required this.secenekler,
    required this.secili,
    required this.onSec,
  });

  final List<String> secenekler;
  final String secili;
  final ValueChanged<String> onSec;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final s in secenekler)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(s),
                selected: s == secili,
                onSelected: (_) => onSec(s),
              ),
            ),
        ],
      ),
    );
  }
}
