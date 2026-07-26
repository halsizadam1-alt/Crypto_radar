import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const CryptoRadarApp());
}

class CryptoRadarApp extends StatelessWidget {
  const CryptoRadarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Crypto Radar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F141C),
        primaryColor: const Color(0xFF1E2638),
        cardColor: const Color(0xFF182030),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> allTickers = [];
  bool isLoading = true;
  String selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    fetchBinanceData();
  }

  Future<void> fetchBinanceData() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.binance.com/api/v3/ticker/24hr'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final usdtPairs = data.where((item) {
          final symbol = item['symbol'].toString();
          return symbol.endsWith('USDT') &&
              !symbol.contains('UP') &&
              !symbol.contains('DOWN');
        }).toList();

        usdtPairs.sort((a, b) => (double.parse(b['priceChangePercent']))
            .compareTo(double.parse(a['priceChangePercent'])));

        if (mounted) {
          setState(() {
            allTickers = usdtPairs;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  List<dynamic> get filteredTickers {
    if (selectedFilter == 'BUY') {
      return allTickers
          .where((item) => double.parse(item['priceChangePercent']) < -5.0)
          .toList();
    } else if (selectedFilter == 'SELL') {
      return allTickers
          .where((item) => double.parse(item['priceChangePercent']) > 10.0)
          .toList();
    } else if (selectedFilter == 'RISK') {
      return allTickers
          .where((item) => double.parse(item['priceChangePercent']) < -15.0)
          .toList();
    }
    return allTickers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF182030),
        elevation: 0,
        title: const Row(
          children: [
            Text('📡 ', style: TextStyle(fontSize: 18)),
            Text(
              'AI Sinyal & Risk Radarı',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF182030),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _filterButton('Tüm Coinler', 'ALL', Icons.list),
                _filterButton('🚀 Güçlü AL', 'BUY', Icons.check_circle_outline),
                _filterButton('🚫 Güçlü SAT', 'SELL', Icons.highlight_off),
                _filterButton('⚠️ Yüksek Risk', 'RISK', Icons.warning_amber),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.amber))
                : RefreshIndicator(
                    onRefresh: fetchBinanceData,
                    child: ListView.builder(
                      itemCount: filteredTickers.length,
                      itemBuilder: (context, index) {
                        final item = filteredTickers[index];
                        final String symbol = item['symbol'];
                        final String pair =
                            '${symbol.replaceAll('USDT', '')} / USDT';
                        final double change =
                            double.parse(item['priceChangePercent']);
                        final double price = double.parse(item['lastPrice']);

                        return Card(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          color: const Color(0xFF182030),
                          child: ListTile(
                            title: Text(
                              pair,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            subtitle: Text(
                              '24s Değişim: ${change.toStringAsFixed(2)}%',
                              style: TextStyle(
                                color: change >= 0
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Text(
                              '\$${price.toStringAsFixed(price < 1 ? 4 : 2)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.white),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _filterButton(String title, String filterKey, IconData icon) {
    final isSelected = selectedFilter == filterKey;
    return InkWell(
      onTap: () {
        setState(() {
          selectedFilter = filterKey;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.amber.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.amber, width: 1) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.amber : Colors.grey),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.amber : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
