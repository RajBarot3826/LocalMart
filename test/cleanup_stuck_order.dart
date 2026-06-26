import 'package:flutter_test/flutter_test.dart';
import 'package:localmart/utils/api_handler.dart';

void main() {
  test('Cleanup stuck order 12', () async {
    final response = await ApiHandler.post('cancel_order.php', {
      'order_id': '12',
    });
    print('Cancel order 12 response: $response');
  });
}
