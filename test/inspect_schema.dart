import 'package:flutter_test/flutter_test.dart';
import 'package:localmart/utils/api_handler.dart';

void main() {
  test('Inspect DB Schema on Live Server', () async {
    print('===========================================================');
    print('          LOCALMART DATABASE SCHEMA INSPECTOR');
    print('===========================================================');
    
    try {
      final response = await ApiHandler.get('inspect.php');
      if (response == null) {
        print('❌ Failed to get response. The inspect.php script might not be uploaded yet.');
        return;
      }
      
      print('Detected Shop/Store Table Name: ${response['detected_shop_table']}');
      print('\nAvailable Columns in the Shop/Store Table:');
      final cols = response['shop_table_columns'] as List? ?? [];
      for (var col in cols) {
        print('  - Field: ${col['Field']}, Type: ${col['Type']}');
      }
    } catch (e) {
      print('Error querying inspect.php: $e');
    }
    
    print('===========================================================');
  });
}
