// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:localmart/utils/api_handler.dart';

void main() {
  test('fetch and print products api', () async {
    print('Testing products.php...');
    final data = await ApiHandler.get('products.php');
    if (data != null && data is Map && data['products'] != null) {
      final products = data['products'] as List;
      for (var product in products) {
        if (product['name'].toString().toLowerCase().contains('bread')) {
          print('\n========== FOUND BREAD ==========');
          print(jsonEncode(product));
          print('=================================\n');
        }
      }
    } else {
      print('Failed or returned unexpected data: $data');
    }
  });
}

