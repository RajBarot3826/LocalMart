import 'package:flutter_test/flutter_test.dart';
import 'package:localmart/utils/api_handler.dart';

void main() {
  test('Test API GET products', () async {
    final response = await ApiHandler.get('products.php?store_id=1');
    print('RESPONSE: $response');
  });
}
