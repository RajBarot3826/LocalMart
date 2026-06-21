import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';

/// AES-CBC decryption for InfinityFree challenge (pure Dart, no external deps)
class _AES {
  // S-Box
  static final List<int> _sBox = [
    0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
    0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
    0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
    0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
    0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
    0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
    0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
    0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
    0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
    0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
    0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
    0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
    0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
    0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
    0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
    0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16,
  ];

  // Inverse S-Box
  static final List<int> _invSBox = [
    0x52,0x09,0x6a,0xd5,0x30,0x36,0xa5,0x38,0xbf,0x40,0xa3,0x9e,0x81,0xf3,0xd7,0xfb,
    0x7c,0xe3,0x39,0x82,0x9b,0x2f,0xff,0x87,0x34,0x8e,0x43,0x44,0xc4,0xde,0xe9,0xcb,
    0x54,0x7b,0x94,0x32,0xa6,0xc2,0x23,0x3d,0xee,0x4c,0x95,0x0b,0x42,0xfa,0xc3,0x4e,
    0x08,0x2e,0xa1,0x66,0x28,0xd9,0x24,0xb2,0x76,0x5b,0xa2,0x49,0x6d,0x8b,0xd1,0x25,
    0x72,0xf8,0xf6,0x64,0x86,0x68,0x98,0x16,0xd4,0xa4,0x5c,0xcc,0x5d,0x65,0xb6,0x92,
    0x6c,0x70,0x48,0x50,0xfd,0xed,0xb9,0xda,0x5e,0x15,0x46,0x57,0xa7,0x8d,0x9d,0x84,
    0x90,0xd8,0xab,0x00,0x8c,0xbc,0xd3,0x0a,0xf7,0xe4,0x58,0x05,0xb8,0xb3,0x45,0x06,
    0xd0,0x2c,0x1e,0x8f,0xca,0x3f,0x0f,0x02,0xc1,0xaf,0xbd,0x03,0x01,0x13,0x8a,0x6b,
    0x3a,0x91,0x11,0x41,0x4f,0x67,0xdc,0xea,0x97,0xf2,0xcf,0xce,0xf0,0xb4,0xe6,0x73,
    0x96,0xac,0x74,0x22,0xe7,0xad,0x35,0x85,0xe2,0xf9,0x37,0xe8,0x1c,0x75,0xdf,0x6e,
    0x47,0xf1,0x1a,0x71,0x1d,0x29,0xc5,0x89,0x6f,0xb7,0x62,0x0e,0xaa,0x18,0xbe,0x1b,
    0xfc,0x56,0x3e,0x4b,0xc6,0xd2,0x79,0x20,0x9a,0xdb,0xc0,0xfe,0x78,0xcd,0x5a,0xf4,
    0x1f,0xdd,0xa8,0x33,0x88,0x07,0xc7,0x31,0xb1,0x12,0x10,0x59,0x27,0x80,0xec,0x5f,
    0x60,0x51,0x7f,0xa9,0x19,0xb5,0x4a,0x0d,0x2d,0xe5,0x7a,0x9f,0x93,0xc9,0x9c,0xef,
    0xa0,0xe0,0x3b,0x4d,0xae,0x2a,0xf5,0xb0,0xc8,0xeb,0xbb,0x3c,0x83,0x53,0x99,0x61,
    0x17,0x2b,0x04,0x7e,0xba,0x77,0xd6,0x26,0xe1,0x69,0x14,0x63,0x55,0x21,0x0c,0x7d,
  ];

  static final List<int> _rcon = [
    0x01,0x02,0x04,0x08,0x10,0x20,0x40,0x80,0x1b,0x36,
    0x6c,0xd8,0xab,0x4d,0x9a,0x2f,0x5e,0xbc,0x63,0xc6,
  ];

  static int _gmul(int a, int b) {
    int p = 0;
    for (int i = 0; i < 8; i++) {
      if ((b & 1) != 0) p ^= a;
      bool hiBit = (a & 0x80) != 0;
      a = (a << 1) & 0xFF;
      if (hiBit) a ^= 0x1B;
      b >>= 1;
    }
    return p;
  }

  /// AES-128 CBC decrypt
  static List<int> decryptCBC(List<int> ciphertext, List<int> key, List<int> iv) {
    // Key expansion
    final expandedKey = _expandKey(key);
    final numRounds = 10; // AES-128

    List<int> result = [];
    List<int> prevBlock = List.from(iv);

    for (int offset = 0; offset < ciphertext.length; offset += 16) {
      List<int> block = ciphertext.sublist(offset, offset + 16);
      List<int> decrypted = _decryptBlock(block, expandedKey, numRounds);

      // XOR with previous ciphertext block (or IV for first block)
      for (int i = 0; i < 16; i++) {
        decrypted[i] ^= prevBlock[i];
      }

      prevBlock = List.from(block);
      result.addAll(decrypted);
    }

    return result;
  }

  static List<List<int>> _expandKey(List<int> key) {
    int nk = 4; // AES-128
    int nr = 10;
    int totalWords = 4 * (nr + 1);

    List<List<int>> w = [];
    for (int i = 0; i < nk; i++) {
      w.add([key[4*i], key[4*i+1], key[4*i+2], key[4*i+3]]);
    }

    for (int i = nk; i < totalWords; i++) {
      List<int> temp = List.from(w[i - 1]);
      if (i % nk == 0) {
        // RotWord
        int first = temp[0];
        temp[0] = temp[1]; temp[1] = temp[2]; temp[2] = temp[3]; temp[3] = first;
        // SubWord
        for (int j = 0; j < 4; j++) temp[j] = _sBox[temp[j]];
        temp[0] ^= _rcon[i ~/ nk - 1];
      }
      List<int> word = List.filled(4, 0);
      for (int j = 0; j < 4; j++) word[j] = w[i - nk][j] ^ temp[j];
      w.add(word);
    }

    return w;
  }

  static List<int> _decryptBlock(List<int> block, List<List<int>> w, int nr) {
    // State is column-major
    List<List<int>> state = List.generate(4, (i) => List.generate(4, (j) => block[j * 4 + i]));

    // AddRoundKey with last round key
    _addRoundKey(state, w, nr * 4);

    for (int round = nr - 1; round >= 1; round--) {
      _invShiftRows(state);
      _invSubBytes(state);
      _addRoundKey(state, w, round * 4);
      _invMixColumns(state);
    }

    _invShiftRows(state);
    _invSubBytes(state);
    _addRoundKey(state, w, 0);

    // Convert state back to bytes (column-major)
    List<int> output = List.filled(16, 0);
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        output[j * 4 + i] = state[i][j];
      }
    }
    return output;
  }

  static void _addRoundKey(List<List<int>> state, List<List<int>> w, int offset) {
    for (int c = 0; c < 4; c++) {
      for (int r = 0; r < 4; r++) {
        state[r][c] ^= w[offset + c][r];
      }
    }
  }

  static void _invSubBytes(List<List<int>> state) {
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        state[r][c] = _invSBox[state[r][c]];
      }
    }
  }

  static void _invShiftRows(List<List<int>> state) {
    // Row 1: shift right 1
    int t = state[1][3];
    state[1][3] = state[1][2]; state[1][2] = state[1][1]; state[1][1] = state[1][0]; state[1][0] = t;
    // Row 2: shift right 2
    int t0 = state[2][0], t1 = state[2][1];
    state[2][0] = state[2][2]; state[2][1] = state[2][3]; state[2][2] = t0; state[2][3] = t1;
    // Row 3: shift right 3 (= left 1)
    t = state[3][0];
    state[3][0] = state[3][1]; state[3][1] = state[3][2]; state[3][2] = state[3][3]; state[3][3] = t;
  }

  static void _invMixColumns(List<List<int>> state) {
    for (int c = 0; c < 4; c++) {
      int s0 = state[0][c], s1 = state[1][c], s2 = state[2][c], s3 = state[3][c];
      state[0][c] = _gmul(s0, 14) ^ _gmul(s1, 11) ^ _gmul(s2, 13) ^ _gmul(s3, 9);
      state[1][c] = _gmul(s0, 9)  ^ _gmul(s1, 14) ^ _gmul(s2, 11) ^ _gmul(s3, 13);
      state[2][c] = _gmul(s0, 13) ^ _gmul(s1, 9)  ^ _gmul(s2, 14) ^ _gmul(s3, 11);
      state[3][c] = _gmul(s0, 11) ^ _gmul(s1, 13) ^ _gmul(s2, 9)  ^ _gmul(s3, 14);
    }
  }
}

class ApiHandler {
  static const String baseUrl = 'https://localmartbhavnagar.infinityfreeapp.com/localmart/api';

  // Persistent cookie store
  static final Map<String, String> _cookies = {};
  static bool _challengePassed = false;

  /// Main GET method
  static Future<dynamic> get(String endpoint) async {
    final targetUrl = '$baseUrl/$endpoint';

    // If challenge was already passed, try with saved cookies
    if (_challengePassed) {
      final result = await _fetchWithCookies(targetUrl);
      if (result != null) return result;
      _challengePassed = false; // cookie expired, re-solve
    }

    // Solve InfinityFree challenge
    final result = await _solveAndFetch(targetUrl);
    if (result != null) return result;

    // Fallback: try proxies
    final proxyResult = await _tryAllOriginsProxy(targetUrl);
    if (proxyResult != null) return proxyResult;

    // All failed
    debugPrint("📴 ALL attempts failed for $endpoint");
    return getOfflineData(endpoint);
  }

  /// Main POST method (sends application/x-www-form-urlencoded)
  static Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final targetUrl = '$baseUrl/$endpoint';
    
    // Check challenge first with a simple GET to ensure cookies are set
    if (!_challengePassed) {
      await get('stores.php'); // Dummy call to solve challenge if needed
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);
      client.userAgent = 'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.6422.165 Mobile Safari/537.36';

      final request = await client.postUrl(Uri.parse(targetUrl));
      request.headers.set('Accept', 'application/json, */*');
      request.headers.set('Content-Type', 'application/x-www-form-urlencoded');
      if (_cookies.isNotEmpty) {
        request.headers.set('Cookie', _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '));
      }

      // Convert body to url-encoded format
      final encodedBody = body.entries
          .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value.toString())}')
          .join('&');

      request.write(encodedBody);

      final response = await request.close().timeout(const Duration(seconds: 15));
      final responseBody = await response.transform(utf8.decoder).join();
      
      _extractCookiesFromHeaders(response.headers);
      client.close();

      if (_isJson(responseBody)) {
        return json.decode(responseBody);
      }
      
      debugPrint("⚠️ POST to $endpoint returned non-JSON: ${responseBody.substring(0, responseBody.length > 100 ? 100 : responseBody.length)}");
      return {"status": "error", "message": "Invalid response from server"};
    } catch (e) {
      debugPrint("❌ POST request failed: $e");
      return {"status": "error", "message": "Network error"};
    }
  }

  /// Solve InfinityFree AES challenge and fetch real data
  static Future<dynamic> _solveAndFetch(String url) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    client.userAgent = 'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.6422.165 Mobile Safari/537.36';

    try {
      // STEP 1: Get the challenge page
      debugPrint("🔗 STEP 1: Getting challenge page → $url");
      final request1 = await client.getUrl(Uri.parse(url));
      request1.headers.set('Accept', 'text/html,application/json,*/*');
      request1.headers.set('Accept-Language', 'en-US,en;q=0.9');

      final response1 = await request1.close().timeout(const Duration(seconds: 15));
      final body1 = await response1.transform(utf8.decoder).join();

      // Capture Set-Cookie headers
      _extractCookiesFromHeaders(response1.headers);

      debugPrint("📡 STEP 1: Status ${response1.statusCode}, Body: ${body1.length} bytes");

      // Check if we got JSON directly (no challenge)
      if (_isJson(body1)) {
        _challengePassed = true;
        debugPrint("✅ Got JSON directly — no challenge needed!");
        client.close();
        return json.decode(body1);
      }

      // STEP 2: Solve the AES challenge from HTML
      final cookieValue = _solveAesChallenge(body1);
      if (cookieValue != null) {
        _cookies['__test'] = cookieValue;
        debugPrint("🔑 Solved AES challenge: __test=$cookieValue");
      } else {
        debugPrint("⚠️ Could not solve AES challenge from HTML");
        client.close();
        return null;
      }

      // STEP 3: Make second request with the computed cookie + ?i=1
      final urlWithParam = url.contains('?') ? '$url&i=1' : '$url?i=1';
      debugPrint("🔗 STEP 2: Fetching with solved cookie → $urlWithParam");

      final request2 = await client.getUrl(Uri.parse(urlWithParam));
      request2.headers.set('Accept', 'application/json, text/html, */*');
      request2.headers.set('Accept-Language', 'en-US,en;q=0.9');
      request2.headers.set('Referer', url);
      request2.headers.set('Cookie', _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '));

      final response2 = await request2.close().timeout(const Duration(seconds: 15));
      final body2 = await response2.transform(utf8.decoder).join();

      _extractCookiesFromHeaders(response2.headers);

      debugPrint("📡 STEP 2: Status ${response2.statusCode}, Body: ${body2.length} bytes");

      if (_isJson(body2)) {
        _challengePassed = true;
        debugPrint("✅ Got real JSON data after solving challenge!");
        client.close();
        return json.decode(body2);
      }

      // If still HTML, try the original URL (without ?i=1) with cookies
      debugPrint("🔗 STEP 3: Retrying original URL with cookies...");
      final request3 = await client.getUrl(Uri.parse(url));
      request3.headers.set('Accept', 'application/json, */*');
      request3.headers.set('Cookie', _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '));

      final response3 = await request3.close().timeout(const Duration(seconds: 15));
      final body3 = await response3.transform(utf8.decoder).join();

      debugPrint("📡 STEP 3: Status ${response3.statusCode}, Body: ${body3.length} bytes");

      if (_isJson(body3)) {
        _challengePassed = true;
        debugPrint("✅ Got JSON on third attempt!");
        client.close();
        return json.decode(body3);
      }

      debugPrint("⚠️ Still getting HTML after challenge. Preview: ${body3.substring(0, body3.length > 200 ? 200 : body3.length)}");
      client.close();
    } on TimeoutException {
      debugPrint("⏰ Challenge solve timed out");
    } catch (e) {
      debugPrint("❌ Challenge solve error: $e");
    }

    return null;
  }

  /// Parse the AES challenge from InfinityFree HTML and compute the cookie
  static String? _solveAesChallenge(String html) {
    try {
      // Extract: var a=toNumbers("..."), b=toNumbers("..."), c=toNumbers("...")
      final aMatch = RegExp(r'var a=toNumbers\("([0-9a-f]+)"\)').firstMatch(html);
      final bMatch = RegExp(r'b=toNumbers\("([0-9a-f]+)"\)').firstMatch(html);
      final cMatch = RegExp(r'c=toNumbers\("([0-9a-f]+)"\)').firstMatch(html);

      if (aMatch == null || bMatch == null || cMatch == null) {
        debugPrint("⚠️ Could not find AES parameters in HTML");
        return null;
      }

      final key = _hexToBytes(aMatch.group(1)!);     // a = key
      final iv = _hexToBytes(bMatch.group(1)!);       // b = IV
      final ciphertext = _hexToBytes(cMatch.group(1)!); // c = ciphertext

      debugPrint("🔐 AES params: key=${aMatch.group(1)}, iv=${bMatch.group(1)}, ct=${cMatch.group(1)}");

      // Decrypt: slowAES.decrypt(c, 2, a, b) where 2 = CBC mode
      final decrypted = _AES.decryptCBC(ciphertext, key, iv);

      // Convert to hex string
      final hexResult = decrypted.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

      debugPrint("🔓 Decrypted cookie value: $hexResult");
      return hexResult;
    } catch (e) {
      debugPrint("❌ AES solve error: $e");
      return null;
    }
  }

  /// Convert hex string to byte list
  static List<int> _hexToBytes(String hex) {
    List<int> bytes = [];
    for (int i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  /// Fetch with already-saved cookies
  static Future<dynamic> _fetchWithCookies(String url) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      client.userAgent = 'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.6422.165 Mobile Safari/537.36';

      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('Accept', 'application/json, */*');
      if (_cookies.isNotEmpty) {
        request.headers.set('Cookie', _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '));
      }

      final response = await request.close().timeout(const Duration(seconds: 10));
      final body = await response.transform(utf8.decoder).join();

      if (_isJson(body)) {
        debugPrint("✅ Cached cookie still valid → got JSON");
        client.close();
        return json.decode(body);
      }

      client.close();
    } catch (e) {
      debugPrint("❌ Cached cookie request failed: $e");
    }
    return null;
  }

  /// Extract cookies from Set-Cookie headers
  static void _extractCookiesFromHeaders(HttpHeaders headers) {
    final setCookies = headers['set-cookie'];
    if (setCookies != null) {
      for (final cookie in setCookies) {
        final parts = cookie.split(';')[0].split('=');
        if (parts.length >= 2) {
          _cookies[parts[0].trim()] = parts.sublist(1).join('=').trim();
        }
      }
    }
  }

  /// AllOrigins proxy fallback
  static Future<dynamic> _tryAllOriginsProxy(String targetUrl) async {
    try {
      debugPrint("🔗 Trying allorigins proxy...");
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 15);

      final proxyUrl = 'https://api.allorigins.win/get?url=${Uri.encodeComponent(targetUrl)}';
      final request = await client.getUrl(Uri.parse(proxyUrl));
      final response = await request.close().timeout(const Duration(seconds: 15));
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final proxyData = json.decode(body);
        final String content = (proxyData['contents'] ?? '').toString().trim();

        if (content.isNotEmpty && _isJson(content)) {
          debugPrint("✅ AllOrigins proxy SUCCESS");
          client.close();
          return json.decode(content);
        }
      }
      client.close();
    } on TimeoutException {
      debugPrint("⏰ AllOrigins timed out");
    } catch (e) {
      debugPrint("❌ AllOrigins error: $e");
    }
    return null;
  }

  /// Check if string is valid JSON
  static bool _isJson(String body) {
    if (body.isEmpty) return false;
    final trimmed = body.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed[0] != '{' && trimmed[0] != '[') return false;
    if (trimmed.contains('<html') || trimmed.contains('<!DOCTYPE')) return false;
    try {
      json.decode(trimmed);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Offline data matching real API format
  static dynamic getOfflineData(String endpoint) {
    if (endpoint.contains('stores') || endpoint.contains('store')) {
      return {
        "status": true,
        "stores": [
          {
            "id": 1,
            "shop_name": "kariyanu (Offline)",
            "owner_name": "Raj Barot",
            "email": "raj03082006@gmail.com",
            "shop_description": "Connect to internet for real data",
            "address": "Chandralok flats, Bhavnagar",
            "store_type": "Other",
            "contact_number": "8866088172",
            "qr_code_token": "shop_084f4036ae2a",
          }
        ]
      };
    } else if (endpoint.contains('products') || endpoint.contains('product')) {
      return {
        "status": true,
        "products": [
          {
            "id": 4,
            "vendor_id": 1,
            "name": "Apple mobile (Offline)",
            "description": "Connect to internet for real data",
            "price": "53000.00",
          }
        ]
      };
    }
    return {"status": false, "data": []};
  }
}
