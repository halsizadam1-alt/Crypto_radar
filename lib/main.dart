import 'package:flutter/material.dart';

// Assuming these variables are defined in the class scope where this method resides:
// String _fearGreedIndex = "50";
// String _fearGreedText = "Neutral";
// var _kureselPiyasa; 

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
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.psychology, color: Colors.amber, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Piyasa Duygusu', style: TextStyle(color: Colors.grey, fontSize: 10), overflow: TextOverflow.ellipsis),
                      Text('$_fearGreedText ($indexVal)', style: TextStyle(color: indexColor, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 25, width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 8)),
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.public, color: Colors.purpleAccent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Küresel Piyasa Cap', style: TextStyle(color: Colors.grey, fontSize: 10), overflow: TextOverflow.ellipsis),
                      Text(globalCapText, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
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
