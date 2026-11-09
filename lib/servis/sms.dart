import 'package:flutter/services.dart';

/// Telefondaki SMS'leri okuyan yerel kanal (MainActivity.kt).
class Sms {
  Sms._();

  static const _kanal = MethodChannel('bereket/sms');

  static Future<bool> izinVarMi() async =>
      (await _kanal.invokeMethod<bool>('izinVarMi')) ?? false;

  static Future<bool> izinIste() async =>
      (await _kanal.invokeMethod<bool>('izinIste')) ?? false;

  /// Son [gun] günün gelen kutusu: {adres, metin, tarih}.
  static Future<List<({String adres, String metin, int tarih})>> oku({int gun = 180}) async {
    final l = await _kanal.invokeMethod<List<dynamic>>('oku', {'gun': gun}) ?? const [];
    return [
      for (final x in l)
        if (x is Map)
          (
            adres: (x['adres'] ?? '').toString(),
            metin: (x['metin'] ?? '').toString(),
            tarih: (x['tarih'] as num?)?.toInt() ?? 0,
          )
    ];
  }
}
