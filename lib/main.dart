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
      debugShowCheckedModeBanner: false,
      title: 'Crypto Radar',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF161B22)),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _cryptoList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCryptoData();
  }

  Future<void> _fetchCryptoData() async {
    final url = Uri.parse('https://api.binance.com/api/v3/ticker/24hr');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final usdtPairs = data.where((item) => item['symbol'].toString().endsWith('USDT')).toList();
        usdtPairs.sort((a, b) => double.parse(b['quoteVolume']).compareTo(double.parse(a['quoteVolume'])));
        setState(() {
          _cryptoList = usdtPairs.take(30).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('⚡ Crypto Radar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchCryptoData();
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _cryptoList.length,
              itemBuilder: (context, index) {
                final coin = _cryptoList[index];
                final price = double.parse(coin['lastPrice']).toStringAsFixed(2);
                final change = double.parse(coin['priceChangePercent']);
                final isPositive = change >= 0;

                return Card(
                  color: const Color(0xFF161B22),
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    title: Text(coin['symbol'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('24h Hacim: \$${double.parse(coin['quoteVolume']).toStringAsFixed(0)}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('\$$price', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          '${isPositive ? '+' : ''}${change.toStringAsFixed(2)}%',
                          style: TextStyle(color: isPositive ? Colors.green : Colors.red),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
