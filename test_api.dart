// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    print('Fetching products API...');
    final response = await http.get(Uri.parse('https://localmart.free.nf/api/products.php'));
    print('Status Code: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      print('API Response successfully parsed.');
      
      if (json['products'] != null) {
        final products = json['products'] as List;
        for (var product in products) {
          if (product['name'].toString().toLowerCase().contains('bread')) {
            print('\nFound Bread Product:');
            product.forEach((key, value) {
              print('  $key: $value');
            });
          }
        }
      } else {
        print('No products key found. Raw response:');
        print(response.body);
      }
    } else {
      print('Failed to load. Response body:');
      print(response.body);
    }
  } catch (e) {
    print('Error: $e');
  }
}

