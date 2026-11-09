import 'package:flutter_test/flutter_test.dart';
import 'package:bereket/belge.dart';
import 'package:bereket/bicim.dart';
import 'package:bereket/ekstre.dart';
import 'package:bereket/hesap.dart';
import 'package:bereket/modeller.dart';
import 'package:bereket/sms_coz.dart';

Kayit k(String id, Map<String, dynamic> d) => Kayit(id, d);

void main() {
  test('Sayı okuma (Türkçe yazım)', () {
    expect(sayiOku('1.234,5'), 1234.5);
    expect(sayiOku('12,75'), 12.75);
    expect(sayiOku('3.125'), 3125);
    expect(sayiOku(''), isNull);
  });

  test('Dekara göre pay', () {
    final p = dekaraGorePay(['a', 'b'], (id) => id == 'a' ? 30 : 10);
    expect(p['a'], 0.75);
    expect(p['b'], 0.25);
  });

  test('Münavebe: pancar 4 yılda bir', () {
    final g = {2023: 'Şeker Pancarı', 2024: 'Buğday', 2025: 'Mısır'};
    expect(munavebeKontrol(g, 'Şeker Pancarı', 2026, 4).seviye, 2);
    expect(munavebeKontrol(g, 'Şeker Pancarı', 2027, 4).seviye, 0);
    expect(munavebeKontrol({2025: 'Buğday'}, 'Arpa', 2026, 2).seviye, 1);
    expect(munavebeKontrol({2025: 'Buğday'}, 'Nohut', 2026, 3).seviye, 0);
  });

  test('Satış kesintileri', () {
    final h = satisHesapla(
        kg: 10000, fiyat: 16.5, stopajYuzde: 1, tescilBinde: 2, sgkYuzde: 2, nakliye: 1000);
    expect(h.tutar, 165000);
    expect(h.stopaj, 1650);
    expect(h.tescil, 330);
    expect(h.sgk, 3300);
    expect(h.beklenen, 165000 - 1650 - 330 - 3300);
    expect(h.net, h.beklenen - 1000);
  });

  Veriler ornek() => Veriler(koleksiyonlar: {
        'tarlalar': [
          k('t1', {'ad': 'Kuyu', 'dekar': 50, 'sahip': 'Ben', 'cks': 'Babam', 'mulkiyet': 'Kendi'}),
          k('t2', {'ad': 'Yol', 'dekar': 30, 'sahip': 'Babam', 'cks': 'Babam', 'mulkiyet': 'Kendi'}),
          k('t3', {'ad': 'Hazine', 'dekar': 20, 'sahip': 'Ben', 'mulkiyet': 'Hazine (ecrimisil)', 'kira': 4000}),
        ],
        'ekimler': [
          k('e1', {'tarlaId': 't1', 'yil': 2026, 'urun': 'Buğday', 'hasatKg': 25000}),
          k('e2', {'tarlaId': 't2', 'yil': 2026, 'urun': 'Buğday', 'hasatKg': 15000}),
          k('e3', {'tarlaId': 't3', 'yil': 2026, 'urun': 'Arpa'}),
        ],
        'sayaclar': [
          k('s1', {'ad': 'Kuyu', 'tarlaIds': ['t1', 't2']}),
        ],
        'giderler': [
          // 80 dekara gübre: Ben 50, Babam 30
          k('g1', {'kalem': 'Gübre', 'tutar': 80000, 'miktar': 3200, 'yil': 2026, 'tarlaIds': ['t1', 't2']}),
          // Elektrik sayaçla: t1 + t2
          k('g2', {'kalem': 'Elektrik', 'tutar': 8000, 'miktar': 4000, 'yil': 2026, 'sayacId': 's1'}),
        ],
        'satislar': [
          k('x1', {'ekimId': 'e2', 'kg': 15000, 'fiyat': 16, 'yil': 2026, 'tahsil': 240000}),
        ],
        'gelirler': [
          // Mazot-gübre: arazi sahibine (Babam, ÇKS); t3 hazine → ekene (Ben)
          k('d1', {'tur': 'Destek', 'destekTuru': 'Mazot-Gübre Desteği', 'tutar': 10000,
            'yil': 2026, 'tarlaIds': ['t1', 't2', 't3'], 'yatan': 'Babam'}),
          // Fark ödemesi: ekene
          k('d2', {'tur': 'Destek', 'destekTuru': 'Fark Ödemesi (Ürün Desteği)', 'tutar': 8000,
            'yil': 2026, 'tarlaIds': ['t1', 't2'], 'yatan': 'Babam'}),
        ],
      });

  test('Gider dağıtımı ve dekar başı maliyet', () {
    final v = ornek();
    final o1 = v.ekimOzet(v.bul('ekimler', 'e1')!);
    expect(o1.kalemler['Gübre']!.tutar, closeTo(50000, 0.01));
    expect(o1.kalemler['Gübre']!.miktar, closeTo(2000, 0.01));
    expect(o1.kalemler['Elektrik']!.tutar, closeTo(5000, 0.01));
    expect(o1.dekarMaliyet, closeTo(1100, 0.01));
    final o3 = v.ekimOzet(v.bul('ekimler', 'e3')!);
    expect(o3.kalemler['Ecrimisil']!.tutar, 4000);
  });

  test('Destekler doğru kişiye', () {
    final v = ornek();
    final p1 = v.destekSahipPaylari(v.bul('gelirler', 'd1')!);
    // t1 (50) + t2 (30) Babam'a, t3 (20) Ben'e: 10000 × 0.8 / 0.2
    expect(p1['Babam'], closeTo(8000, 0.01));
    expect(p1['Ben'], closeTo(2000, 0.01));
    final p2 = v.destekSahipPaylari(v.bul('gelirler', 'd2')!);
    expect(p2['Ben'], closeTo(5000, 0.01));
    expect(p2['Babam'], closeTo(3000, 0.01));
  });

  test('Aile hesaplaşması', () {
    final v = ornek();
    final b = v.sahipOzet('Babam', yil: 2026);
    // Babam: gübre 30000 + elektrik 3000 = 33000 masraf
    expect(b.masraf, closeTo(33000, 0.01));
    // Satış tahsilatı bende: 240000
    expect(b.tahsil, 240000);
    // Babam'a yatan desteklerde benim payım: d1 2000 + d2 5000 = 7000 (o bana borçlu)
    expect(b.destekDuzeltme, closeTo(-7000, 0.01));
    expect(b.hesaplasma, closeTo(240000 - 33000 - 7000, 0.01));
  });

  test('Ortak ekim payları', () {
    final v = Veriler(koleksiyonlar: {
      'tarlalar': [
        k('t1', {'dekar': 100, 'sahip': 'Ben'}),
      ],
      'ekimler': [
        k('e1', {'tarlaId': 't1', 'yil': 2026, 'urun': 'Şeker Pancarı',
          'ortaklar': {'Ben': 50, 'Babam': 50}}),
      ],
      'giderler': [
        k('g1', {'kalem': 'Tohum', 'tutar': 20000, 'yil': 2026, 'tarlaIds': ['t1']}),
      ],
      'satislar': [
        k('s1', {'ekimId': 'e1', 'kg': 600000, 'fiyat': 3.72, 'yil': 2026}),
      ],
    });
    expect(v.giderSahipPayi(v.giderler.first, 'Babam'), closeTo(0.5, 1e-9));
    final b = v.sahipOzet('Babam', yil: 2026);
    expect(b.masraf, closeTo(10000, 0.01));
    expect(b.satis, closeTo(600000 * 3.72 / 2, 0.01));
    final o = v.yilOzet(2026);
    expect(o.tarimGider, closeTo(10000, 0.01));
  });

  test('Hesap bakiyesi', () {
    expect(
        hesapBakiye([
          {'tip': 'artis', 'tutar': 1000},
          {'tip': 'odeme', 'tutar': 250},
        ]),
        750);
  });

  test('Ekstre: hesap hareketleri (CSV, eksi tutar)', () {
    const csv = 'Hesap Hareketleri\n'
        'Tarih;Açıklama;Tutar;Bakiye\n'
        '05.11.2026;MIGROS KONYA;-1.250,50;10.000,00\n'
        '05.11.2026;MAAŞ ÖDEMESİ;45.000,00;55.000,00\n'
        '06.11.2026;OPET KARAPINAR;-2.000,00;53.000,00\n';
    final l = ekstreCoz(csvOku(csv));
    expect(l.length, 3);
    final h = l.where((x) => x.harcama).toList();
    expect(h.length, 2);
    expect(h.first.tutar, 1250.5);
    expect(evKategorisiTahmin(h.first.aciklama), 'Market');
    expect(evKategorisiTahmin(h.last.aciklama), 'Araba (yakıt)');
  });

  test('Ekstre: kredi kartı (borç/alacak sütunları)', () {
    final satirlar = [
      ['İşlem Tarihi', 'İşlem Açıklaması', 'Borç', 'Alacak'],
      ['01/11/2026', 'TURKCELL FATURA', '450,00', ''],
      ['03/11/2026', 'KART ODEMESI', '', '5.000,00'],
      ['2026-11-04', 'TOROS GUBRE BAYI', '12.000,00', ''],
    ];
    final l = ekstreCoz(satirlar);
    expect(l.where((x) => x.harcama).length, 2);
    expect(tarlaKalemiTahmin('TOROS GUBRE BAYI'), 'Gübre');
    expect(tutarOku('(150,00)'), -150);
    expect(tutarOku('1,234.56'), 1234.56);
  });

  test('Belge: akaryakıt fişi', () {
    const fis = 'OPET KARAPINAR PETROL\n'
        'TARIH: 05.11.2026 SAAT: 14:32\n'
        'MOTORIN 42,50 LT X 45,00\n'
        'TOPLAM *1.912,50\n'
        'KDV *318,75\n';
    final o = belgeCoz(fis);
    expect(o.tur, BelgeTuru.akaryakit);
    expect(o.toplam, 1912.5);
    expect(o.litre, 42.5);
    expect(DateTime.fromMillisecondsSinceEpoch(o.tarih).day, 5);
    expect(o.firma, 'OPET KARAPINAR PETROL');
  });

  test('Belge: el yazısı hesap', () {
    const not = 'Ali 1.500\nVeli 2.250\nmazot 200 lt 9.000';
    final o = belgeCoz(not);
    expect(o.tur, BelgeTuru.elYazisi);
    expect(o.satirlar.length, 3);
    expect(o.toplam, 12750);
    expect(o.satirlar.last.miktar, 200);
  });

  test('Aile alacak/verecek hesaplaşmaya girer', () {
    final v = Veriler(koleksiyonlar: {
      'aile_hareketler': [
        k('h1', {'kisi': 'Babam', 'yon': 'o_verdi', 'tutar': 10000, 'yil': 2026}),
        k('h2', {'kisi': 'Babam', 'yon': 'ben_verdim', 'tutar': 2500, 'yil': 2026}),
        k('h3', {'kisi': 'Kardeşim', 'yon': 'o_verdi', 'tutar': 999, 'yil': 2026}),
      ],
    });
    final b = v.sahipOzet('Babam');
    expect(b.onunVerdigi, 10000);
    expect(b.benimVerdigim, 2500);
    expect(b.hesaplasma, 7500);
    final ozet = v.aileOzeti('Babam');
    expect((ozet['tumu'] as Map)['hesaplasma'], 7500);
  });

  test('Belge: MEDAŞ faturası', () {
    const f = 'MERAM ELEKTRIK DAGITIM A.S. (MEDAS)\n'
        'Tesisat No: 4001234567\n'
        'Fatura Tarihi: 02.10.2026\n'
        'Toplam Tuketim 12.450 kWh\n'
        'Odenecek Tutar 38.917,50 TL\n';
    final o = belgeCoz(f);
    expect(o.tur, BelgeTuru.elektrik);
    expect(o.aboneNo, '4001234567');
    expect(o.kwh, 12450);
    expect(o.toplam, 38917.5);
  });

  test('Banka SMS çözme', () {
    final t = DateTime(2026, 11, 5, 10).millisecondsSinceEpoch;
    final a = smsCoz('GARANTI BBVA',
        'Bonus kartinizin 05.11.2026 tarihli ekstre borcu 12.345,67 TL, son odeme tarihi 15.11.2026.', t)!;
    expect(a.tur, SmsTuru.kartBorcu);
    expect(a.tutar, 12345.67);
    expect(DateTime.fromMillisecondsSinceEpoch(a.sonOdeme).day, 15);
    final b = smsCoz('VAKIFBANK', 'Hesabiniza 45.000,00 TL EFT gelmistir. Gonderen: PANAGRO A.S.', t)!;
    expect(b.tur, SmsTuru.gelen);
    expect(b.tutar, 45000);
    final c = smsCoz('ZIRAAT', 'Kredi taksit tutariniz 5.250,00 TL, son odeme 20.11.2026', t)!;
    expect(c.tur, SmsTuru.krediTaksit);
    expect(c.hesapAdi, 'Ziraat Bankası Kredi');
    expect(smsCoz('GARANTI BBVA', 'Dogrulama kodunuz 123456', t), isNull);
    expect(smsCoz('5551234', 'Merhaba 100 TL', t), isNull);
  });

  test('Dekont ve POS slip', () {
    final d = belgeCoz('ZIRAAT BANKASI\nEFT DEKONTU\nIslem Tarihi: 03.11.2026\n'
        'Gonderen: RAMAZAN KOCABAS\nAlici Adi: YILDIZ TARIM GUBRE LTD\n'
        'Alici IBAN: TR12 0001 0000 0000 0000 0000 01\nAciklama: gubre bedeli\n'
        'Tutar: 48.500,00 TL');
    expect(d.tur, BelgeTuru.dekont);
    expect(d.firma, 'YILDIZ TARIM GUBRE LTD');
    expect(d.toplam, 48500);
    expect(d.odemeBelgesi, isTrue);
    expect(DateTime.fromMillisecondsSinceEpoch(d.tarih).day, 3);
    final p = belgeCoz('KARAPINAR ZIRAI ILAC\nSATIS\n05.11.2026 14:22\nKart No: ****1234\n'
        'Onay Kodu: 123456\nTUTAR 7.250,00 TL\nMUSTERI NUSHASI');
    expect(p.tur, BelgeTuru.tarim);
    final q = belgeCoz('OZ YAPI MARKET\nSATIS\n05.11.2026 14:22\nOnay Kodu: 123456\nTUTAR 1.250,00 TL');
    expect(q.tur, BelgeTuru.market);
    final w = belgeCoz('DEMIR HIRDAVAT\nSATIS\n05.11.2026\nProvizyon 778899\nTUTAR 2.100,00 TL');
    expect(w.tur, BelgeTuru.dekont);
    expect(w.toplam, 2100);
  });
}
