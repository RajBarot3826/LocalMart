// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:localmart/utils/api_handler.dart';

void main() {
  test('Test Live Rider Map Location Tracking APIs', () async {
    print('--- STARTING LIVE MAP TRACKING API TEST ---');

    // 0. Trigger DB migration and file creation
    print('Running DB migration patch via patch_backend_v6.php...');
    await ApiHandler.get('patch_backend_v6.php');
    print('Patch completed.');

    // 1. Send live coordinates update
    final testRiderId = 1; // Existing test rider raj
    final testLat = 21.76450000;
    final testLng = 72.15190000;

    print('Updating location for rider $testRiderId to ($testLat, $testLng)...');
    final updateRes = await ApiHandler.post('update_live_location.php', {
      'rider_id': testRiderId.toString(),
      'lat': testLat.toString(),
      'lng': testLng.toString(),
    });

    print('Update response: $updateRes');
    expect(updateRes, isNotNull);
    expect(updateRes['status'] == true || updateRes['status'] == 'success' || updateRes['success'] == true, isTrue);

    // 2. Fetch live coordinates
    print('Fetching location for rider $testRiderId...');
    final getRes = await ApiHandler.get('get_rider_location.php?rider_id=$testRiderId');
    print('Get response: $getRes');

    expect(getRes, isNotNull);
    expect(getRes['status'], isTrue);
    expect(getRes['rider'], isNotNull);
    
    final double retrievedLat = double.parse(getRes['rider']['current_lat'].toString());
    final double retrievedLng = double.parse(getRes['rider']['current_lng'].toString());

    print('Sent: ($testLat, $testLng) -> Retrieved: ($retrievedLat, $retrievedLng)');
    expect(retrievedLat, closeTo(testLat, 0.0001));
    expect(retrievedLng, closeTo(testLng, 0.0001));
    
    print('--- LIVE MAP TRACKING API TEST PASSED! ---');
  });
}
