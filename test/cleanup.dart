import 'package:flutter_test/flutter_test.dart';
import 'package:localmart/utils/api_handler.dart';

void main() {
  test('Cleanup dummy riders', () async {
    for (int i = 1; i <= 20; i++) {
      if (i != 3248) { // Don't turn off the user's rider
        await ApiHandler.post('toggle_rider_status.php', {
          'rider_id': i.toString(),
          'status': 'offline',
        });
      }
    }
    print('All test riders turned offline!');
  });
}
