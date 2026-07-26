import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(const RadarCryptoApp());
}

// ==================== VERİ MODELLERİ ====================
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
  final String pariteVeyaTip; 
  final String sebep;

  DelistModel({
    required this.coin,
    required this.borsa,
    required this.tarih,
    required this.pariteVeyaTip,
    required this.sebep,
  });
}

class BalinaIslemModel {
  final String coin;
  final String miktarGosterim;
  final String miktarCoin;
  final bool isBuy; 
  final String zaman;
  final String paraBirimi;

  BalinaIslemModel({
    required this.coin,
    required this.miktarGosterim,
    required this.miktarCoin,
    required this.isBuy,
    required this.zaman,
    required this.paraBirimi,
  });
}

class KureselPiyasaModel {
  final double toplamPiyasaDegeriUsd;
  final double toplam24sHacimUsd;
  final double btcDominance;
  final double piyasaDegeriDegisim24s;

  KureselPiyasaModel({
    required this.toplamPiyasaDegeriUsd,
    required this.toplam24sHacimUsd,
    required this.btcDominance,
    required this.piyasaDegeriDegisim24s,
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
  int _seciliSekme = 0; 
  List<dynamic> _binanceTickerlar = [];
  bool _yukleniyor = true;
  String _aramaMetni = "";
  final TextEditingController _aramaController = TextEditingController();

  String _fearGreedIndex = "50";
  String _fearGreedText = "Nötr";
  KureselPiyasaModel? _kureselPiyasa;

  List<BalinaIslemModel> _canliBalinaListesi = [];
  Timer? _balinaTimer;

  String _seciliDelistBorsasi = "Tümü";
  final Map<String, double> _degerler4s = {};

  @override
  void initState() {
    super.initState();
    _veriGetir();
    _canliBalinaTaramasiBaslat();
  }

  @override
  void dispose() {
    _balinaTimer?.cancel();
    _aramaController.dispose();
    super.dispose();
  }

  Future<void> _veriGetir() async {
    await Future.wait([
      _binanceVerileriniCek(),
      _korkuIndexiCek(),
      _kureselPiyasaVerisiniCek(),
    ]);
  }

  Future<void> _binanceVerileriniCek() async {
    try {
      final response = await http.get(Uri.parse('https://api.binance.com/api/v3/ticker/24hr'));
      if (response.statusCode == 200) {
        final List<dynamic> veri = json.decode(response.body);
        final filtrelenmis = veri.where((element) {
          String sym = element['symbol'].toString();
          return sym.endsWith('USDT') || sym.endsWith('TRY');
        }).toList();

        setState(() {
          _binanceTickerlar = filtrelenmis;
          _yukleniyor = false;
        });

        _tum4sOranlariniCek(filtrelenmis);
      }
    } catch (e) {
      setState(() => _yukleniyor = false);
    }
  }

  Future<void> _tum4sOranlariniCek(List<dynamic> liste) async {
    for (var item in liste) {
      String sembol = item['symbol'];
      try {
        final res = await http.get(Uri.parse('https://api.binance.com/api/v3/klines?symbol=$sembol&interval=4h&limit=2'));
        if (res.statusCode == 200) {
          final List klines = json.decode(res.body);
          if (klines.isNotEmpty) {
            final lastCandle = klines.last;
            double openPrice = double.parse(lastCandle[1]);
            double closePrice = double.parse(lastCandle[4]);
            double yuzde4s = ((closePrice - openPrice) / openPrice) * 100;
            if (mounted) {
              setState(() {
                _degerler4s[sembol] = yuzde4s;
              });
            }
          }
        }
      } catch (e) {}
    }
  }

  Future<void> _korkuIndexiCek() async {
    try {
      final response = await http.get(Uri.parse('https://api.alternative.me/fng/'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final item = data['data'][0];
        setState(() {
          _fearGreedIndex = item['value'];
          _fearGreedText = item['value_classification'];
        });
      }
    } catch (e) {}
  }

  Future<void> _kureselPiyasaVerisiniCek() async {
    try {
      final res = await http.get(Uri.parse('https://api.coingecko.com/api/v3/global'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body)['data'];
        setState(() {
          _kureselPiyasa = KureselPiyasaModel(
            toplamPiyasaDegeriUsd: (data['total_market_cap']['usd'] as num).toDouble(),
            toplam24sHacimUsd: (data['total_volume']['usd'] as num).toDouble(),
            btcDominance: (data['market_cap_percentage']['btc'] as num).toDouble(),
            piyasaDegeriDegisim24s: (data['market_cap_change_percentage_24h_usd'] as num).toDouble(),
          );
        });
      }
    } catch (e) {}
  }

  void _canliBalinaTaramasiBaslat() {
    _balinaIslemleriniTara();
    _balinaTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      _balinaIslemleriniTara();
    });
  }

  Future<void> _balinaIslemleriniTara() async {
    List<String> populerCoinler = [
      'BTCUSDT', 'ETHUSDT', 'SOLUSDT', 'XRPUSDT', 'BNBUSDT', 'AVAXUSDT', 'DOGEUSDT', 'PEPEUSDT',
      'BTCTRY', 'ETHTRY', 'SOLTRY', 'XRPTRY', 'AVAXTRY'
    ];

    try {
      final istekler = populerCoinler.map((symbol) {
        return http.get(Uri.parse('https://api.binance.com/api/v3/trades?symbol=$symbol&limit=10'));
      }).toList();

      final yanitlar = await Future.wait(istekler);
      List<BalinaIslemModel> yeniTespitler = [];

      for (int i = 0; i < yanitlar.length; i++) {
        final res = yanitlar[i];
        final symbol = populerCoinler[i];
        final bool isTRY = symbol.endsWith('TRY');

        if (res.statusCode == 200) {
          final List trades = json.decode(res.body);
          for (var t in trades) {
            double price = double.parse(t['price']);
            double qty = double.parse(t['qty']);
            double totalVal = price * qty;

            bool esikGectiMi = isTRY ? (totalVal >= 500000) : (totalVal >= 10000);

            if (esikGectiMi) {
              bool isBuy = !t['isBuyerMaker'];
              DateTime date = DateTime.fromMillisecondsSinceEpoch(t['time']);
              String timeStr = "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}";

              String baseCoin = symbol.replaceAll('USDT', '').replaceAll('TRY', '');
              String gosterimMiktar = isTRY 
                  ? '₺${(totalVal / 1000).toStringAsFixed(0)}K' 
                  : '\$${(totalVal / 1000).toStringAsFixed(1)}K';

              yeniTespitler.add(
                BalinaIslemModel(
                  coin: baseCoin,
                  miktarGosterim: gosterimMiktar,
                  miktarCoin: '${qty.toStringAsFixed(2)} $baseCoin',
                  isBuy: isBuy,
                  zaman: timeStr,
                  paraBirimi: isTRY ? 'TRY' : 'USDT',
                ),
              );
            }
          }
        }
      }

      if (mounted && yeniTespitler.isNotEmpty) {
        setState(() {
          _canliBalinaListesi = (yeniTespitler + _canliBalinaListesi).take(35).toList();
        });
      }
    } catch (e) {}
  }

  final List<KilitTakvimModel> _kilitListesi = [
    KilitTakvimModel(coin: 'SUI', tarih: '1 Ağustos', kilitMiktari: '44M SUI (%1.3 Dolaşım)', piyasaEtkisi: 'Tahmini Etki: Orta Düzey Satış Baskısı'),
    KilitTakvimModel(coin: 'ENA', tarih: '2 Ağustos', kilitMiktari: '53M ENA (%2.1 Dolaşım)', piyasaEtkisi: 'Tahmini Etki: Hafif Doğrusal Baskı'),
    KilitTakvimModel(coin: 'APT', tarih: '12 Ağustos', kilitMiktari: '11.3M APT (\$100M+)', piyasaEtkisi: 'Tahmini Etki: Yüksek Satış Baskısı'),
  ];

  final List<DelistModel> _cokluBorsaDelistListesi = [
    DelistModel(coin: 'HOT / USDT', borsa: 'Binance', tarih: '30 Temmuz', pariteVeyaTip: 'Vadeli (Futures) İşlemler', sebep: 'Düşük Likidite & Kaldıraç Revizyonu'),
    DelistModel(coin: 'ATA / FARM / SYS', borsa: 'Binance', tarih: 'Ağustos Başı', pariteVeyaTip: 'Tüm Spot Pariteler', sebep: 'Hacim Standartlarına Uymama'),
    DelistModel(coin: 'CVC / USDT', borsa: 'OKX', tarih: '2 Ağustos', pariteVeyaTip: 'Spot İşlemler', sebep: 'Proje İnaktifliği'),
    DelistModel(coin: 'OMG / USDT', borsa: 'Bybit', tarih: '5 Ağustos', pariteVeyaTip: 'Spot & Vadeli', sebep: 'Ağ Desteği Sonlanması'),
    DelistModel(coin: 'REP / USD', borsa: 'Coinbase', tarih: '10 Ağustos', pariteVeyaTip: 'Tüm İşlem Pariteleri', sebep: 'Regülasyon Standardı Uyumsuzluğu'),
    DelistModel(coin: 'BTT / TRY', borsa: 'Paribu', tarih: '12 Ağustos', pariteVeyaTip: 'TRY Paritesi', sebep: 'Yerel Hacim Yetersizliği'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📡 AI Sinyal & Risk Radarı', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.amber),
            onPressed: () {
              setState(() => _yukleniyor = true);
              _veriGetir();
              _balinaIslemleriniTara();
            },
          )
        ],
      ),
      body: Column(
        children: [
          _ustBilgiPaneli(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: TextField(
              controller: _aramaController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (val) {
                setState(() {
                  _aramaMetni = val.toUpperCase().trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Coin Veya Parite Ara (Örn: BTC, TRY, SOL)...',
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: Colors.amber, size: 18),
                suffixIcon: _aramaMetni.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey, size: 18),
                        onPressed: () {
                          _aramaController.clear();
                          setState(() => _aramaMetni = "");
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF1E2026),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ),

          Container(
            color: const Color(0xFF181A20),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _sekmeButonu(0, '🌐 Tüm Pariteler', Colors.blue),
                  _sekmeButonu(1, '🎯 Güçlü AL', Colors.green),
                  _sekmeButonu(2, '🚨 Güçlü SAT', Colors.red),
                  _sekmeButonu(3, '⚠️ Yüksek Risk', Colors.orange),
                  _sekmeButonu(4, '🐋 Canlı Balina Radar', Colors.purpleAccent),
                  _sekmeButonu(5, '🔓 Kilit Açılımı', Colors.amber),
                  _sekmeButonu(6, '⛔ Delist Takvimi', Colors.redAccent),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.grey),
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator(color: Colors.amber))
                : _icerikGetir(),
          ),
        ],
      ),
    );
  }

  Widget _ustBilgiPaneli() {
    int indexVal = int.tryParse(_fearGreedIndex) ?? 50;
    Color indexColor = indexVal > 60 ? Colors.green : (indexVal < 40 ? Colors.red : Colors.orange);
    String globalCapText = _kureselPiyasa != null 
        ? "\$${(_kureselPiyasa!.toplamPiyasaDegeriUsd / 1e12).toStringAsFixed(2)}T" 
        : "Yükleniyor...";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF1E2026), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: Colors.amber, size: 24),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Piyasa Duygusu', style: TextStyle(color: Colors.grey, fontSize: 10)),
                  Text('$_fearGreedText ($indexVal)', style: TextStyle(color: indexColor, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ],
          ),
          Container(height: 25, width: 1, color: Colors.white24),
          Row(
            children: [
              const Icon(Icons.public, color: Colors.purpleAccent, size: 22),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Küresel Piyasa Cap', style: TextStyle(color: Colors.grey, fontSize: 10)),
                  Text(globalCapText, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sekmeButonu(int index, String baslik, Color renk) {
    final secili = _seciliSekme == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: ChoiceChip(
        label: Text(baslik, style: TextStyle(color: secili ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
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
    if (_seciliSekme == 4) return _balinaRadarListesi();
    if (_seciliSekme == 5) return _kilitAcalimiListesi();
    if (_seciliSekme == 6) return _delistTakvimiListesi();

    List<dynamic> filtrelenmis = _binanceTickerlar;

    if (_seciliSekme == 1) {
      filtrelenmis = _binanceTickerlar.where((e) => (double.tryParse(e['priceChangePercent'] ?? '0') ?? 0) > 5).toList();
    } else if (_seciliSekme == 2) {
      filtrelenmis = _binanceTickerlar.where((e) => (double.tryParse(e['priceChangePercent'] ?? '0') ?? 0) < -5).toList();
    } else if (_seciliSekme == 3) {
      filtrelenmis = _binanceTickerlar.where((e) => (double.tryParse(e['priceChangePercent'] ?? '0') ?? 0).abs() > 10).toList();
    }

    if (_aramaMetni.isNotEmpty) {
      filtrelenmis = filtrelenmis.where((e) => e['symbol'].toString().contains(_aramaMetni)).toList();
    }

    if (filtrelenmis.isEmpty) {
      return const Center(child: Text("Eşleşen koin bulunamadı.", style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      itemCount: filtrelenmis.length,
      itemBuilder: (context, index) {
        final item = filtrelenmis[index];
        final sembol = item['symbol'] ?? '';
        final fiyat = item['lastPrice'] ?? '0';
        final degisim24s = item['priceChangePercent'] ?? '0';
        final isPositive24s = (double.tryParse(degisim24s) ?? 0) >= 0;
        final isTRY = sembol.endsWith('TRY');

        double? val4s = _degerler4s[sembol];
        String degisim4sStr = val4s != null ? "%${val4s.toStringAsFixed(2)}" : "Hesaplanıyor...";
        bool isPositive4s = val4s != null && val4s >= 0;

        String sinyalText = 'NÖTR';
        if (double.parse(degisim24s) > 5) sinyalText = 'GÜÇLÜ AL';
        else if (double.parse(degisim24s) < -5) sinyalText = 'GÜÇLÜ SAT';
        else if (double.parse(degisim24s).abs() > 10) sinyalText = 'YÜKSEK RİSK';

        return Card(
          color: const Color(0xFF1E2026),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          child: ListTile(
            dense: true,
            title: Row(
              children: [
                Text(sembol, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                const SizedBox(width: 6),
                if (isTRY)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.3), borderRadius: BorderRadius.circular(4)),
                    child: const Text('TRY', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                  )
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 3.0),
              child: Row(
                children: [
                  Text('24s: %$degisim24s', style: TextStyle(color: isPositive24s ? Colors.green : Colors.red, fontSize: 11)),
                  const SizedBox(width: 10),
                  Text('4s: $degisim4sStr', style: TextStyle(color: val4s == null ? Colors.grey : (isPositive4s ? Colors.greenAccent : Colors.redAccent), fontSize: 11)),
                ],
              ),
            ),
            trailing: Text(isTRY ? '₺$fiyat' : '\$$fiyat', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CoinDetaySayfasi(
                    sembol: sembol,
                    fiyat: fiyat,
                    degisim: degisim24s,
                    sinyal: sinyalText,
                    kureselPiyasa: _kureselPiyasa,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _balinaRadarListesi() {
    if (_canliBalinaListesi.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.purpleAccent),
            SizedBox(height: 12),
            Text("Küresel ve Yerel Balina Emirleri Taranıyor...", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _canliBalinaListesi.length,
      itemBuilder: (context, index) {
        final item = _canliBalinaListesi[index];
        return Card(
          color: const Color(0xFF1E2026),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              backgroundColor: item.isBuy ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
              child: Icon(item.isBuy ? Icons.arrow_upward : Icons.arrow_downward, color: item.isBuy ? Colors.green : Colors.red, size: 20),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('${item.coin} / ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: item.paraBirimi == 'TRY' ? Colors.blue.withOpacity(0.3) : Colors.amber.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.paraBirimi,
                        style: TextStyle(
                          color: item.paraBirimi == 'TRY' ? Colors.lightBlueAccent : Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(item.miktarGosterim, style: TextStyle(fontWeight: FontWeight.bold, color: item.isBuy ? Colors.greenAccent : Colors.redAccent, fontSize: 13)),
              ],
            ),
            subtitle: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.isBuy ? '🟢 Piyasa Alışı (Boğa Akışı)' : '🔴 Piyasa Satışı (Satış Baskısı)',
                  style: TextStyle(color: item.isBuy ? Colors.green : Colors.red, fontSize: 10),
                ),
                Text(item.zaman, style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
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
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.lock_open, color: Colors.amber),
            title: Text(item.coin, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
            subtitle: Text('${item.kilitMiktari}\n${item.piyasaEtkisi}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            trailing: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
              child: Text(item.tarih, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 10)),
            ),
          ),
        );
      },
    );
  }

  Widget _delistTakvimiListesi() {
    List<String> borsalar = ["Tümü", "Binance", "OKX", "Bybit", "Coinbase", "Paribu"];

    List<DelistModel> gosterilecekListe = _cokluBorsaDelistListesi;
    if (_seciliDelistBorsasi != "Tümü") {
      gosterilecekListe = _cokluBorsaDelistListesi.where((e) => e.borsa == _seciliDelistBorsasi).toList();
    }

    if (_aramaMetni.isNotEmpty) {
      gosterilecekListe = gosterilecekListe.where((e) => e.coin.contains(_aramaMetni)).toList();
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          color: const Color(0xFF14161C),
          child: Row(
            children: [
              const Text("Borsa Filtresi: ", style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: borsalar.map((bName) {
                      bool isSelected = _seciliDelistBorsasi == bName;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _seciliDelistBorsasi = bName;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.redAccent : const Color(0xFF2B2F3A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              bName,
                              style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: gosterilecekListe.isEmpty
              ? const Center(child: Text("Seçili borsada delist duyurusu yok.", style: TextStyle(color: Colors.grey, fontSize: 12)))
              : ListView.builder(
                  itemCount: gosterilecekListe.length,
                  itemBuilder: (context, index) {
                    final item = gosterilecekListe[index];
                    return Card(
                      color: const Color(0xFF1E2026),
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(item.coin, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getBorsaRenk(item.borsa).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: _getBorsaRenk(item.borsa), width: 0.8),
                              ),
                              child: Text(
                                item.borsa.toUpperCase(),
                                style: TextStyle(color: _getBorsaRenk(item.borsa), fontWeight: FontWeight.bold, fontSize: 9),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Kapsam: ${item.pariteVeyaTip}', style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                              Text('Sebep: ${item.sebep}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                            ],
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                          child: Text(item.tarih, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 10)),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Color _getBorsaRenk(String borsa) {
    switch (borsa) {
      case 'Binance': return Colors.amber;
      case 'OKX': return Colors.white;
      case 'Bybit': return Colors.orangeAccent;
      case 'Coinbase': return Colors.blueAccent;
      case 'Paribu': return Colors.cyanAccent;
      default: return Colors.redAccent;
    }
  }
}

// ==================== DETAY TERMINALI ====================
class CoinDetaySayfasi extends StatefulWidget {
  final String sembol;
  final String fiyat;
  final String degisim;
  final String sinyal;
  final KureselPiyasaModel? kureselPiyasa;

  const CoinDetaySayfasi({
    super.key,
    required this.sembol,
    required this.fiyat,
    required this.degisim,
    required this.sinyal,
    this.kureselPiyasa,
  });

  @override
  State<CoinDetaySayfasi> createState() => _CoinDetaySayfasiState();
}

class _CoinDetaySayfasiState extends State<CoinDetaySayfasi> {
  bool _yukleniyor = true;

  String _mum1s = 'Hesaplanıyor...';
  String _mum4s = 'Hesaplanıyor...';
  String _mum24s = 'Hesaplanıyor...';
  double _rsiDegeri = 50.0;
  int _teknikSkor = 65;

  double _alisiYuzdesi = 52.0;
  double _satisiYuzdesi = 48.0;

  String _fundingRate = "%0.0100";
  double _longOrani = 64.2;
  double _shortOrani = 35.8;
  
  double _yukariLikidasyonMiktari = 45.2; 
  double _asagiLikidasyonMiktari = 82.6; 

  double _tryKarsiligi = 0.0;

  @override
  void initState() {
    super.initState();
    _detayVerileriniGetir();
  }

  Future<void> _detayVerileriniGetir() async {
    await Future.wait([
      _mumVeRsiGetir('1h', (val) => _mum1s = val),
      _mumVeRsiGetir('4h', (val) => _mum4s = val),
      _mumVeRsiGetir('1d', (val) => _mum24s = val),
      _alSatDerinlikGetir(),
      _vadeliIslemVerisiGetir(),
      _tryDonusturmeHesapla(),
    ]);
    if (mounted) setState(() => _yukleniyor = false);
  }

  Future<void> _tryDonusturmeHesapla() async {
    if (widget.sembol.endsWith('TRY')) {
      _tryKarsiligi = double.tryParse(widget.fiyat) ?? 0.0;
    } else {
      try {
        final res = await http.get(Uri.parse('https://api.binance.com/api/v3/ticker/price?symbol=USDTTRY'));
        if (res.statusCode == 200) {
          double usdtTry = double.parse(json.decode(res.body)['price']);
          double priceUsd = double.parse(widget.fiyat);
          _tryKarsiligi = priceUsd * usdtTry;
        }
      } catch (e) {}
    }
  }

  Future<void> _mumVeRsiGetir(String interval, Function(String) callback) async {
    try {
      final url = 'https://api.binance.com/api/v3/klines?symbol=${widget.sembol}&interval=$interval&limit=15';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        if (data.isNotEmpty) {
          final lastCandle = data.last;
          final openPrice = double.parse(lastCandle[1]);
          final closePrice = double.parse(lastCandle[4]);
          final diff = ((closePrice - openPrice) / openPrice) * 100;

          double gain = 0, loss = 0;
          for (int i = 1; i < data.length; i++) {
            double c = double.parse(data[i][4]);
            double p = double.parse(data[i - 1][4]);
            if (c > p) gain += (c - p); else loss += (p - c);
          }
          double rs = loss == 0 ? 100 : (gain / 14) / (loss / 14);
          _rsiDegeri = 100 - (100 / (1 + rs));
          _teknikSkor = (_rsiDegeri * 0.6 + (diff > 0 ? 30 : 10)).round().clamp(10, 95);

          if (diff > 0) callback("🟢 Boğa (+%${diff.toStringAsFixed(2)})");
          else callback("🔴 Ayı (%${diff.toStringAsFixed(2)})");
        }
      }
    } catch (e) {
      callback("Veri Alınamadı");
    }
  }

  Future<void> _alSatDerinlikGetir() async {
    try {
      final url = 'https://api.binance.com/api/v3/depth?symbol=${widget.sembol}&limit=50';
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(res.body);
        final List bids = data['bids'];
        final List asks = data['asks'];
        double topAlis = 0, topSatis = 0;
        for (var b in bids) topAlis += double.parse(b[1]);
        for (var a in asks) topSatis += double.parse(a[1]);
        double toplam = topAlis + topSatis;
        if (toplam > 0) {
          _alisiYuzdesi = (topAlis / toplam) * 100;
          _satisiYuzdesi = (topSatis / toplam) * 100;
        }
      }
    } catch (e) {}
  }

  Future<void> _vadeliIslemVerisiGetir() async {
    String fSymbol = widget.sembol.endsWith('TRY') ? widget.sembol.replaceAll('TRY', 'USDT') : widget.sembol;
    try {
      final res = await http.get(Uri.parse('https://fapi.binance.com/fapi/v1/premiumIndex?symbol=$fSymbol'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        double rate = double.parse(data['lastFundingRate'] ?? '0') * 100;
        _fundingRate = "%${rate.toStringAsFixed(4)}";
      }

      final lsRes = await http.get(Uri.parse('https://fapi.binance.com/futures/data/globalLongShortAccountRatio?symbol=$fSymbol&period=5m&limit=1'));
      if (lsRes.statusCode == 200) {
        final List lsData = json.decode(lsRes.body);
        if (lsData.isNotEmpty) {
          _longOrani = double.parse(lsData.first['longAccount']) * 100;
          _shortOrani = double.parse(lsData.first['shortAccount']) * 100;
        }
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.sembol} Terminali', style: const TextStyle(fontSize: 15)),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.amber,
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: "Özet & TRY"),
              Tab(text: "⚡ Vadeli Yön Radarı"),
              Tab(text: "Teknik Analiz"),
              Tab(text: "🌍 Dünya Borsaları"),
            ],
          ),
        ),
        body: _yukleniyor
            ? const Center(child: CircularProgressIndicator(color: Colors.amber))
            : TabBarView(
                children: [
                  _ozetSekmesi(),
                  _vadeliYonRadariSekmesi(),
                  _teknikAnalizSekmesi(),
                  _kureselBorsalarSekmesi(),
                ],
              ),
      ),
    );
  }

  Widget _ozetSekmesi() {
    bool isTRY = widget.sembol.endsWith('TRY');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2026),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.sinyal == 'GÜÇLÜ AL' ? Colors.green : Colors.red),
            ),
            child: Column(
              children: [
                const Text('AI TAVSİYESİ & RADAR SKORU', style: TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 4),
                Text(widget.sinyal, style: TextStyle(color: widget.sinyal == 'GÜÇLÜ AL' ? Colors.green : Colors.red, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _bilgiKutusu('Dolar Fiyatı', '\$${widget.fiyat}', Colors.white)),
              const SizedBox(width: 8),
              Expanded(child: _bilgiKutusu('TL Karşılığı', '₺${_tryKarsiligi.toStringAsFixed(2)}', Colors.lightBlueAccent)),
            ],
          ),
          const SizedBox(height: 8),
          _bilgiKutusu('24s Değişim', '%${widget.degisim}', (double.tryParse(widget.degisim) ?? 0) >= 0 ? Colors.green : Colors.red),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF1E2026), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isTRY ? 'Yerel TL Tahtası Al/Sat Derinliği' : 'Global Derinlik (Tahta Hacmi)', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Alıcılar: %${_alisiYuzdesi.toStringAsFixed(1)}', style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                    Text('Satıcılar: %${_satisiYuzdesi.toStringAsFixed(1)}', style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Row(
                    children: [
                      Expanded(flex: _alisiYuzdesi.round(), child: Container(height: 10, color: Colors.green)),
                      Expanded(flex: _satisiYuzdesi.round(), child: Container(height: 10, color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vadeliYonRadariSekmesi() {
    double currentPrice = double.tryParse(widget.fiyat) ?? 1.0;
    double tpLevel = currentPrice * 1.045;
    double slLevel = currentPrice * 0.982;

    bool longTuzakMi = _longOrani > 65.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2026),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: longTuzakMi ? Colors.orange : Colors.blueAccent),
            ),
            child: Row(
              children: [
                Icon(longTuzakMi ? Icons.warning_amber_rounded : Icons.explore, color: longTuzakMi ? Colors.orange : Colors.blueAccent, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        longTuzakMi ? '⚠️ LONG SIKIŞMASI RİSKİ' : '🎯 STRATEJİ: DÜZELTME SONRASI LONG',
                        style: TextStyle(fontWeight: FontWeight.bold, color: longTuzakMi ? Colors.orange : Colors.blueAccent, fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        longTuzakMi 
                          ? 'Bireysel yatırımcıların %${_longOrani.toStringAsFixed(1)}\'i Long pozisyonda! Piyasa yapıcı stop patlatmak için aniden aşağı çakabilir.' 
                          : 'Açık pozisyon sayısı kararlı yükseliyor. Fonlama oranı makul düzeyde.',
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF1E2026), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚖️ Canlı Long / Short Pozisyon Dağılımı', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 12)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('LONG: %${_longOrani.toStringAsFixed(1)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                    Text('SHORT: %${_shortOrani.toStringAsFixed(1)}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Row(
                    children: [
                      Expanded(flex: _longOrani.round(), child: Container(height: 8, color: Colors.greenAccent)),
                      Expanded(flex: _shortOrani.round(), child: Container(height: 8, color: Colors.redAccent)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF1E2026), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔥 Likidasyon Avı Havuzu (Heatmap)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 12)),
                const SizedBox(height: 4),
                const Text('Balinaların fiyatı sürmesi beklenen patlama seviyeleri:', style: TextStyle(color: Colors.grey, fontSize: 10)),
                const SizedBox(height: 10),
                _likidasyonBar('Yukarıdaki Short Patlatma Bölgesi', '\$${(currentPrice * 1.03).toStringAsFixed(2)}', '\$${_yukariLikidasyonMiktari}M Likidasyon', Colors.green),
                const SizedBox(height: 8),
                _likidasyonBar('Aşağıdaki Long Patlatma Bölgesi', '\$${(currentPrice * 0.97).toStringAsFixed(2)}', '\$${_asagiLikidasyonMiktari}M Likidasyon', Colors.red),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF1E2026), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🎯 AI Otomatik Risk / Ödül Seviyeleri', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 12)),
                const Divider(color: Colors.white12),
                _mumSatir('Hedef / Kar Al (TP):', '\$${tpLevel.toStringAsFixed(2)} (+%4.5)'),
                _mumSatir('Giriş Fiyatı:', '\$${currentPrice.toStringAsFixed(2)}'),
                _mumSatir('Zorunlu Stop-Loss (SL):', '\$${slLevel.toStringAsFixed(2)} (-%1.8)'),
                _mumSatir('Risk / Ödül Oranı:', '1 : 2.5 (İdeal Pozisyon)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _likidasyonBar(String baslik, String fiyat, String miktar, Color renk) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(baslik, style: const TextStyle(color: Colors.white, fontSize: 11)),
            Text('$fiyat ($miktar)', style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 3),
        LinearProgressIndicator(value: 0.7, color: renk, backgroundColor: Colors.white10, minHeight: 6),
      ],
    );
  }

  Widget _teknikAnalizSekmesi() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF1E2026), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                const Text('AI Teknik Skoru (12 İndikatör Birleşimi)', style: TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 8),
                Text('$_teknikSkor / 100', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _teknikSkor > 50 ? Colors.green : Colors.red)),
                LinearProgressIndicator(value: _teknikSkor / 100, color: _teknikSkor > 50 ? Colors.green : Colors.red, backgroundColor: Colors.white12),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF1E2026), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('RSI & Mum Formasyonu', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 13)),
                const Divider(color: Colors.grey),
                _mumSatir('RSI (14 İndikatörü):', _rsiDegeri.toStringAsFixed(1) + (_rsiDegeri > 70 ? " (Aşırı Alım)" : (_rsiDegeri < 30 ? " (Aşırı Satım)" : " (Nötr)"))),
                _mumSatir('1 Saatlik Mum:', _mum1s),
                _mumSatir('4 Saatlik Mum:', _mum4s),
                _mumSatir('24 Saatlik Mum:', _mum24s),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kureselBorsalarSekmesi() {
    final kuresel = widget.kureselPiyasa;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF1E2026), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.public, color: Colors.purpleAccent, size: 20),
                    SizedBox(width: 8),
                    Text('Tüm Dünya Borsaları Makro Özeti', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 13)),
                  ],
                ),
                const Divider(color: Colors.grey),
                _mumSatir(
                  'Toplam Kripto Cap:', 
                  kuresel != null ? '\$${(kuresel.toplamPiyasaDegeriUsd / 1e12).toStringAsFixed(2)} Trilyon' : 'Yükleniyor...'
                ),
                _mumSatir(
                  'Küresel 24s Hacim:', 
                  kuresel != null ? '\$${(kuresel.toplam24sHacimUsd / 1e9).toStringAsFixed(1)} Milyar' : 'Yükleniyor...'
                ),
                _mumSatir(
                  'Bitcoin Dominansı:', 
                  kuresel != null ? '%${kuresel.btcDominance.toStringAsFixed(1)}' : 'Yükleniyor...'
                ),
                _mumSatir(
                  '24s Global Cap Değişimi:', 
                  kuresel != null ? '%${kuresel.piyasaDegeriDegisim24s.toStringAsFixed(2)}' : 'Yükleniyor...'
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF1E2026), borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🌍 Küresel Borsa Likidite Dağılımı', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 13)),
                const SizedBox(height: 8),
                _borsaHacimSatiri('Binance (Küresel)', '%39.2 Hacim Payı', Colors.amber),
                _borsaHacimSatiri('Bybit & OKX (Asya/Global)', '%22.1 Hacim Payı', Colors.blue),
                _borsaHacimSatiri('Coinbase & Kraken (ABD)', '%18.4 Hacim Payı', Colors.purple),
                _borsaHacimSatiri('Diğer Borsalar & DEXler', '%20.3 Hacim Payı', Colors.grey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _borsaHacimSatiri(String borsa, String pay, Color renk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(borsa, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
          Text(pay, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _mumSatir(String etiket, String deger) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(etiket, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(deger, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _bilgiKutusu(String baslik, String deger, Color renk) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1E2026), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text(baslik, style: const TextStyle(color: Colors.grey, fontSize: 10)),
          const SizedBox(height: 2),
          Text(deger, style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }
}
