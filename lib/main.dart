import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const RadarCryptoApp());
}

// ==================== VERİ MODELLERİ ====================
class SinyalModel {
  final String metin;
  final Color renk;
  final String neden;
  SinyalModel({required this.metin, required this.renk, required this.neden});
}

class KilitModel {
  final String tarih;
  final String oran;
  final String durum;
  KilitModel({required this.tarih, required this.oran, required this.durum});
}

class KilitTakvimModel {
  final String coin;
  final String tarih;
  final String kilitMiktari;
  final String piyasaEtkisi;
  KilitTakvimModel({
    required this.coin,
    required this.tarih,
    required this.kilitMiktari,
    required this.piyasaEtkisi,
  });
}

class DelistModel {
  final String coin;
  final String borsa;
  final String tarih;
  final String sebep;
  DelistModel({
    required this.coin,
    required this.borsa,
    required this.tarih,
    required this.sebep,
  });
}

// ==================== ANA UYGULAMA ====================
class RadarCryptoApp extends StatelessWidget {
  const RadarCryptoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Signal & Risk Radar',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0E14),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF181A20),
          elevation: 0,
        ),
      ),
      home: const RadarAnaSayfa(),
    );
  }
}

// ==================== ANA SAYFA ====================
class RadarAnaSayfa extends StatefulWidget {
  const RadarAnaSayfa({super.key});

  @override
  State<RadarAnaSayfa> createState() => _RadarAnaSayfaState();
}

class _RadarAnaSayfaState extends State<RadarAnaSayfa> {
  int _seciliSekme = 0; // 0: Güçlü AL, 1: Güçlü SAT, 2: Yüksek Risk, 3: Kilit Açılımı, 4: Delist Takvimi
  List<dynamic> _binanceTickerlar = [];
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _binanceVerileriniCek();
  }

  Future<void> _binanceVerileriniCek() async {
    try {
      final response = await http.get(Uri.parse('https://api.binance.com/api/v3/ticker/24hr'));
      if (response.statusCode == 200) {
        final List<dynamic> veri = json.decode(response.body);
        setState(() {
          _binanceTickerlar = veri.where((element) => element['symbol'].toString().endsWith('USDT')).toList();
          _yukleniyor = false;
        });
      }
    } catch (e) {
      setState(() => _yukleniyor = false);
    }
  }

  // Statik Yan Veriler
  final List<KilitTakvimModel> _kilitListesi = [
    KilitTakvimModel(coin: 'SUI', tarih: '1 Ağustos', kilitMiktari: '44M SUI (%1.3 Dolaşım)', piyasaEtkisi: 'Tahmini Etki: Orta Düzey Satış Baskısı'),
    KilitTakvimModel(coin: 'ENA', tarih: '2 Ağustos', kilitMiktari: '53M ENA (%2.1 Dolaşım)', piyasaEtkisi: 'Tahmini Etki: Hafif Doğrusal Baskı'),
    KilitTakvimModel(coin: 'APT', tarih: '12 Ağustos', kilitMiktari: '11.3M APT (\$100M+)', piyasaEtkisi: 'Tahmini Etki: Yüksek Satış Baskısı'),
    KilitTakvimModel(coin: 'STRK', tarih: '15 Ağustos', kilitMiktari: '64M STRK (%3.8 Dolaşım)', piyasaEtkisi: 'Tahmini Etki: Orta-Yüksek Baskı'),
    KilitTakvimModel(coin: 'ARB', tarih: '16 Ağustos', kilitMiktari: '92M ARB (%2.6 Dolaşım)', piyasaEtkisi: 'Tahmini Etki: Kurumsal Satış Baskısı'),
    KilitTakvimModel(coin: 'AVAX', tarih: '20 Ağustos', kilitMiktari: '9.5M AVAX (%4.1 Dolaşım)', piyasaEtkisi: 'Tahmini Etki: Kısa Süreli Dalgalanma'),
  ];

  final List<DelistModel> _delistListesi = [
    DelistModel(coin: 'HOT (Pariteler)', borsa: 'Binance', tarih: 'Temmuz Sonu', sebep: 'Vadeli/Marjin İşlem Sonlandırma'),
    DelistModel(coin: 'ATA / FARM / SYS', borsa: 'Binance', tarih: 'Yakın Tarihli', sebep: 'Düşük Likidite & Standart Dışı'),
    DelistModel(coin: 'CYBER / PIXEL', borsa: 'Binance Margin', tarih: 'Ağustos Başı', sebep: 'Marjin Çiftleri Temizliği'),
    DelistModel(coin: 'Düşük Hacimli Altcoinler', borsa: 'Genel Piyasalar', tarih: 'Anlık Risk', sebep: 'Hacim < \$500K (Otomatik Risk)'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📡 AI Sinyal & Risk Radarı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
      ),
      body: Column(
        children: [
          // YATAY KAYDIRILABİLİR SEKME MENÜSÜ (TÜM SEKMELER GÖRÜNECEK)
          Container(
            color: const Color(0xFF181A20),
            padding: const EdgeInsets.vertical(8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _sekmeButonu(0, '🎯 Güçlü AL', Colors.green),
                  _sekmeButonu(1, '🚨 Güçlü SAT', Colors.red),
                  _sekmeButonu(2, '⚠️ Yüksek Risk', Colors.orange),
                  _sekmeButonu(3, '🔓 Kilit Açılımı', Colors.amber),
                  _sekmeButonu(4, '⛔ Delist Takvimi', Colors.redAccent),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.grey),

          // İÇERİK LİSTESİ
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _icerikGetir(),
          ),
        ],
      ),
    );
  }

  Widget _sekmeButonu(int index, String baslik, Color renk) {
    final secili = _seciliSekme == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(baslik, style: TextStyle(color: secili ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        selected: secili,
        selectedColor: renk,
        backgroundColor: const Color(0xFF2B2F3A),
        onSelected: (bool selected) {
          setState(() {
            _seciliSekme = index;
          });
        },
      ),
    );
  }

  Widget _icerikGetir() {
    if (_seciliSekme == 3) return _kilitAcalimiListesi();
    if (_seciliSekme == 4) return _delistTakvimiListesi();

    // Binance Coin Filtreleme
    List<dynamic> filtrelenmis = [];
    if (_seciliSekme == 0) {
      filtrelenmis = _binanceTickerlar.where((e) => (double.tryParse(e['priceChangePercent'] ?? '0') ?? 0) > 5).toList();
    } else if (_seciliSekme == 1) {
      filtrelenmis = _binanceTickerlar.where((e) => (double.tryParse(e['priceChangePercent'] ?? '0') ?? 0) < -5).toList();
    } else {
      filtrelenmis = _binanceTickerlar.where((e) => (double.tryParse(e['priceChangePercent'] ?? '0') ?? 0).abs() > 10).toList();
    }

    return ListView.builder(
      itemCount: filtrelenmis.length,
      itemBuilder: (context, index) {
        final item = filtrelenmis[index];
        final sembol = item['symbol'] ?? '';
        final fiyat = item['lastPrice'] ?? '0';
        final degisim = item['priceChangePercent'] ?? '0';
        final isPositive = (double.tryParse(degisim) ?? 0) >= 0;

        return Card(
          color: const Color(0xFF1E2026),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: ListTile(
            title: Text(sembol, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: Text('24s Değişim: %$degisim', style: TextStyle(color: isPositive ? Colors.green : Colors.red, fontSize: 12)),
            trailing: Text('\$$fiyat', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
            // TIKLAMA İŞLEVİ BURADA EKLENDİ (DETAY SAYFASINA YÖNLENDİRME)
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CoinDetaySayfasi(
                    sembol: sembol,
                    fiyat: fiyat,
                    degisim: degisim,
                    sinyal: _seciliSekme == 0 ? 'GÜÇLÜ AL' : (_seciliSekme == 1 ? 'GÜÇLÜ SAT' : 'YÜKSEK RİSK'),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _kilitAcalimiListesi() {
    return ListView.builder(
      itemCount: _kilitListesi.length,
      itemBuilder: (context, index) {
        final item = _kilitListesi[index];
        return Card(
          color: const Color(0xFF1E2026),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: ListTile(
            leading: const Icon(Icons.lock_open, color: Colors.amber),
            title: Text(item.coin, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: Text('${item.kilitMiktari}\n${item.piyasaEtkisi}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            trailing: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
              child: Text(item.tarih, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ),
        );
      },
    );
  }

  Widget _delistTakvimiListesi() {
    return ListView.builder(
      itemCount: _delistListesi.length,
      itemBuilder: (context, index) {
        final item = _delistListesi[index];
        return Card(
          color: const Color(0xFF1E2026),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: ListTile(
            leading: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            title: Text(item.coin, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: Text('Sebep: ${item.sebep}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            trailing: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
              child: Text(item.tarih, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ),
        );
      },
    );
  }
}

// ==================== DETAY (TERMINAL) SAYFASI ====================
class CoinDetaySayfasi extends StatelessWidget {
  final String sembol;
  final String fiyat;
  final String degisim;
  final String sinyal;

  const CoinDetaySayfasi({
    super.key,
    required this.sembol,
    required this.fiyat,
    required this.degisim,
    required this.sinyal,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$sembol 360° AI Terminali', style: const TextStyle(fontSize: 16)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2026),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sinyal == 'GÜÇLÜ AL' ? Colors.green : Colors.red),
              ),
              child: Column(
                children: [
                  const Text('AI TAVSİYESİ', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(sinyal, style: TextStyle(color: sinyal == 'GÜÇLÜ AL' ? Colors.green : Colors.red, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _bilgiKutusu('Fiyat', '\$$fiyat', Colors.white),
                _bilgiKutusu('24s Değişim', '%$degisim', (double.tryParse(degisim) ?? 0) >= 0 ? Colors.green : Colors.red),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF1E2026), borderRadius: BorderRadius.circular(12)),
              child: const Column(
                crossAxisAlignment: CrossAlignment.start,
                children: [
                  Text('🔍 AI Analiz Özeti', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                  SizedBox(height: 8),
                  Text('• Hacim ve dalgalanma indeksleri incelendi.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  SizedBox(height: 4),
                  Text('• Anlık teknik indikatörler sinyali destekliyor.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bilgiKutusu(String baslik, String deger, Color renk) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1E2026), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Text(baslik, style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 4),
          Text(deger, style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
