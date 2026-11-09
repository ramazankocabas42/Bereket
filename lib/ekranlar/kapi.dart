import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../servis/guncelleme.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'aile_uye.dart';
import 'giris.dart';
import 'kabuk.dart';

/// Oturum → profil → işletme sırasıyla doğru ekranı gösterir.
class Kapi extends StatelessWidget {
  const Kapi({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const _Yukleniyor();
        }
        final u = s.data;
        if (u == null) return const GirisEkrani();
        return _ProfilKapi(key: ValueKey(u.uid), uid: u.uid);
      },
    );
  }
}

class _Yukleniyor extends StatelessWidget {
  const _Yukleniyor();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}

class _ProfilKapi extends StatefulWidget {
  const _ProfilKapi({super.key, required this.uid});
  final String uid;

  @override
  State<_ProfilKapi> createState() => _ProfilKapiState();
}

class _ProfilKapiState extends State<_ProfilKapi> {
  late final _akis = Veri.kullanicilar.doc(widget.uid).snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _akis,
      builder: (context, s) {
        if (s.hasError) {
          return _HataEkrani(yazi: hataYazisi(s.error!));
        }
        if (!s.hasData) return const _Yukleniyor();
        final d = s.data!.data() ?? {};
        final ad = (d['ad'] as String?) ?? '';
        final iid = (d['isletmeId'] as String?) ?? '';
        if (iid.isEmpty) return KurulumEkrani(uid: widget.uid, ad: ad);
        return _FirmaKapi(key: ValueKey(iid), uid: widget.uid, iid: iid);
      },
    );
  }
}

class _FirmaKapi extends StatefulWidget {
  const _FirmaKapi({super.key, required this.uid, required this.iid});
  final String uid;
  final String iid;

  @override
  State<_FirmaKapi> createState() => _FirmaKapiState();
}

class _FirmaKapiState extends State<_FirmaKapi> {
  late Durum _durum = Durum(iid: widget.iid, uid: widget.uid);

  void _yenidenDene() {
    final eski = _durum;
    setState(() => _durum = Durum(iid: widget.iid, uid: widget.uid));
    eski.dispose();
  }

  @override
  void dispose() {
    _durum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _durum,
      builder: (context, _) {
        final d = _durum;
        if (d.isletmeYok || (d.isletme == null && d.hata != null) || (d.isletme != null && !d.uye && !d.aileUyesi)) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Panel(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.lock_outline, size: 48, color: Renk.soluk),
                        const SizedBox(height: 8),
                        const Text(
                          'Bu işletmeye erişiminiz yok. Sahibi sizi çıkarmış ya da işletme silinmiş olabilir.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: Renk.yazi),
                        ),
                        const SizedBox(height: 18),
                        Buton(
                          yazi: 'Tekrar dene',
                          ikon: Icons.refresh,
                          onTap: _yenidenDene,
                        ),
                        const SizedBox(height: 10),
                        Buton(
                          yazi: 'Başka işletmeye katıl / yeni kur',
                          renk: ButonRenk.gri,
                          onTap: () => Veri.isletmedenAyril(widget.uid),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                            onPressed: () => FirebaseAuth.instance.signOut(),
                            child: const Text('Çıkış yap')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        if (d.isletme == null) return const _Yukleniyor();
        if (d.aileUyesi) return AileUyeEkrani(durum: d);
        return Kabuk(durum: d);
      },
    );
  }
}

class _HataEkrani extends StatelessWidget {
  const _HataEkrani({required this.yazi});
  final String yazi;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Renk.kirmizi),
                  const SizedBox(height: 10),
                  Text(yazi, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  TextButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text('Çıkış yap')),
                ],
              ),
            ),
          ),
        ),
      );
}

/// İlk açılış: adınız + yeni işletme kur ya da davet koduyla katıl.
class KurulumEkrani extends StatefulWidget {
  const KurulumEkrani({super.key, required this.uid, required this.ad});
  final String uid;
  final String ad;

  @override
  State<KurulumEkrani> createState() => _KurulumEkraniState();
}

class _KurulumEkraniState extends State<KurulumEkrani> {
  late final _ad = TextEditingController(text: widget.ad);
  final _kod = TextEditingController();
  final _firma = TextEditingController(text: 'Kocabaş Tarım');
  bool _kur = true;
  bool _mesgul = false;

  @override
  void initState() {
    super.initState();
    // Ekipten çıkarılmış ya da yeni katılan biri ana ekrana giremeden
    // burada kalır; eski sürümdeyse güncellemeyi burada da görsün.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Guncelleme.kontrolEt(context);
    });
  }

  @override
  void dispose() {
    _ad.dispose();
    _kod.dispose();
    _firma.dispose();
    super.dispose();
  }

  Future<void> _devam() async {
    final ad = _ad.text.trim();
    if (ad.length < 2) {
      bildir(context, 'Adınızı ve soyadınızı yazın.');
      return;
    }
    if (_kur && _firma.text.trim().length < 2) {
      bildir(context, 'İşletme adını yazın.');
      return;
    }
    if (!_kur && _kod.text.trim().length < 6) {
      bildir(context, 'İşletme sahibinden aldığınız davet kodunu yazın.');
      return;
    }
    setState(() => _mesgul = true);
    try {
      if (_kur) {
        await Veri.isletmeKur(widget.uid, ad, _firma.text);
      } else {
        await Veri.kodlaKatil(widget.uid, ad, _kod.text);
      }
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoş geldiniz'),
        actions: [
          TextButton(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('Çıkış')),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Panel(
              baslik: 'Adınız',
              child: TextField(
                controller: _ad,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    hintText: 'Örn. Ramazan Kocabaş',
                    prefixIcon: Icon(Icons.person_outline)),
              ),
            ),
            Panel(
              baslik: 'İşletme',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Kodla katıl'), icon: Icon(Icons.group_add)),
                      ButtonSegment(value: true, label: Text('Yeni işletme kur'), icon: Icon(Icons.agriculture)),
                    ],
                    selected: {_kur},
                    onSelectionChanged: (s) => setState(() => _kur = s.first),
                  ),
                  const SizedBox(height: 14),
                  if (_kur) ...[
                    TextField(
                      controller: _firma,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'İşletme adı'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'İşletmeyi kuran kişi yönetici olur. Aile üyelerini ya da çalışanları Profil → Ekip bölümündeki davet koduyla eklersiniz.',
                      style: TextStyle(color: Renk.soluk, fontSize: 13.5),
                    ),
                  ] else ...[
                    TextField(
                      controller: _kod,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                          labelText: 'Davet kodu', hintText: 'Örn. K7PX3MQA'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Kodu işletme sahibi Profil → Ekip bölümünden size gönderir.',
                      style: TextStyle(color: Renk.soluk, fontSize: 13.5),
                    ),
                  ],
                ],
              ),
            ),
            Buton(
              yazi: _kur ? 'İşletmeyi Kur' : 'İşletmeye Katıl',
              renk: ButonRenk.yesil,
              yukseklik: 54,
              mesgul: _mesgul,
              onTap: _devam,
            ),
            const SizedBox(height: 16),
            Text(
              Guncelleme.buSurum > 0
                  ? 'Uygulama sürümü: ${Guncelleme.buSurum}'
                  : 'Uygulama sürümü: geliştirme',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Renk.soluk, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
