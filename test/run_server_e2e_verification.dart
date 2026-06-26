import 'package:flutter_test/flutter_test.dart';
import 'package:localmart/utils/api_handler.dart';

void main() {
  test('E2E Verification of Broadcast and Dialer logic on Live Server', () async {
    print('===========================================================');
    print('      LOCALMART SERVER-SIDE E2E FLOW VERIFICATION');
    print('===========================================================');
    print('Starting automated test run on the database...');

    try {
      final response = await ApiHandler.get('test_flow.php');
      
      expect(response, isNotNull, reason: 'Failed to communicate with test_flow.php on the server');
      
      if (response is Map) {
        if (response['status'] == 'success') {
          print('\n✅ End-to-End Server-Side Verification SUCCEEDED!');
          print('\nDetailed execution log from the server:');
          final logList = response['log'] as List? ?? [];
          for (var step in logList) {
            final msg = step['msg']?.toString() ?? '';
            final success = step['success'] == true;
            print('  ${success ? "✅" : "❌"} $msg');
          }
          expect(response['status'], equals('success'));
        } else {
          print('\n❌ End-to-End Server-Side Verification FAILED!');
          print('Error message: ${response['message']}');
          final logList = response['log'] as List? ?? [];
          if (logList.isNotEmpty) {
            print('\nExecution log before failure:');
            for (var step in logList) {
              final msg = step['msg']?.toString() ?? '';
              final success = step['success'] == true;
              print('  ${success ? "✅" : "❌"} $msg');
            }
          }
          fail('E2E Verification failed on the server: ${response['message']}');
        }
      } else {
        fail('Unexpected response format: $response');
      }
    } catch (e) {
      fail('Network or parser exception occurred: $e');
    }
    
    print('===========================================================');
  });
}
