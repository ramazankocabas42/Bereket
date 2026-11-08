import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../servis/guncelleme.dart';
import '../servis/veri.dart';
import '../tema.dart';

class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> {
  final _form = GlobalKey<FormState>();
  final _eposta = TextEditingController();
  final _sifre = TextEditingController();
  bool _kayit = false;
  bool _mesgul = false;
  bool _gizli = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Guncelleme.kontrolEt(context);
    });
  }

  @override
  void dispose() {
    _eposta.dispose();
    _sifre.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _mesgul = true);
    try {
      final a = FirebaseAuth.instance;
      if (_kayit) {
        await a.createUserWithEmailAndPassword(
            email: _eposta.text.trim(), password: _sifre.text);
      } else {
        await a.signInWithEmailAndPassword(
            email: _eposta.text.trim(), password: _sifre.text);
      }
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _sifreSifirla() async {
    final e = _eposta.text.trim();
    if (!e.contains('@')) {
      bildir(context, 'Önce e-posta adresinizi yazın.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: e);
      if (mounted) bildir(context, 'Şifre sıfırlama bağlantısı e-postanıza gönderildi.');
    } catch (err) {
      if (mounted) bildir(context, hataYazisi(err));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Renk.yesil, Renk.yesilKoyu]),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Renk.altin, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: const Text('🌾', style: TextStyle(fontSize: 34)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text('BEREKET',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 30,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w900,
                            color: Renk.altin)),
                    const SizedBox(height: 2),
                    const Text('Tarla, bütçe ve işletme takibi',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Renk.soluk)),
                    const SizedBox(height: 28),
                    Panel(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(_kayit ? 'Yeni hesap' : 'Giriş yap',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Renk.yazi)),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _eposta,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                                labelText: 'E-posta',
                                prefixIcon: Icon(Icons.mail_outline)),
                            validator: (v) => (v == null || !v.contains('@'))
                                ? 'Geçerli bir e-posta yazın'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _sifre,
                            obscureText: _gizli,
                            decoration: InputDecoration(
                              labelText: 'Şifre',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_gizli
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _gizli = !_gizli),
                              ),
                            ),
                            validator: (v) => (v == null || v.length < 6)
                                ? 'Şifre en az 6 karakter olmalı'
                                : null,
                            onFieldSubmitted: (_) => _gonder(),
                          ),
                          const SizedBox(height: 18),
                          Buton(
                            yazi: _kayit ? 'Hesap Oluştur' : 'Giriş Yap',
                            renk: ButonRenk.yesil,
                            mesgul: _mesgul,
                            yukseklik: 50,
                            onTap: _gonder,
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: _mesgul
                                ? null
                                : () => setState(() => _kayit = !_kayit),
                            child: Text(_kayit
                                ? 'Zaten hesabım var, giriş yap'
                                : 'Hesabım yok, yeni hesap oluştur'),
                          ),
                          if (!_kayit)
                            TextButton(
                                onPressed: _mesgul ? null : _sifreSifirla,
                                child: const Text('Şifremi unuttum')),
                        ],
                      ),
                    ),
                    Text(
                      Guncelleme.buSurum > 0
                          ? 'Sürüm ${Guncelleme.buSurum}'
                          : 'Geliştirme sürümü',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Renk.soluk, fontSize: 12.5),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Keleş Satış ya da Eğitim Takip hesabınız varsa aynı e-posta ve şifreyle girin; satışlarınız Bereket\'e bağlanabilir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Renk.soluk, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
