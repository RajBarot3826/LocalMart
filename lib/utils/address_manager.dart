import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedAddress {
  final String label; // "HOME", "OFFICE", "OTHER"
  final String name;
  final String address;
  final String city;
  final String pincode;
  final String phone;

  SavedAddress({
    required this.label,
    required this.name,
    required this.address,
    required this.city,
    required this.pincode,
    required this.phone,
  });

  String get fullAddress => '$address,\n$city – $pincode, Gujarat';

  Map<String, dynamic> toJson() => {
    'label': label,
    'name': name,
    'address': address,
    'city': city,
    'pincode': pincode,
    'phone': phone,
  };

  factory SavedAddress.fromJson(Map<String, dynamic> json) => SavedAddress(
    label: json['label'] ?? 'HOME',
    name: json['name'] ?? '',
    address: json['address'] ?? '',
    city: json['city'] ?? '',
    pincode: json['pincode'] ?? '',
    phone: json['phone'] ?? '',
  );
}

class AddressManager extends ChangeNotifier {
  static final AddressManager _instance = AddressManager._internal();
  factory AddressManager() => _instance;
  AddressManager._internal();

  List<SavedAddress> _addresses = [];
  int _selectedIndex = 0;
  String _userPhone = '';

  List<SavedAddress> get addresses => _addresses;
  int get selectedIndex => _selectedIndex;
  SavedAddress? get selectedAddress =>
      _addresses.isNotEmpty && _selectedIndex < _addresses.length
          ? _addresses[_selectedIndex]
          : null;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('userPhone') ?? '';
    await loadForUser(phone);
  }

  void clearMemory() {
    _addresses = [];
    _selectedIndex = 0;
    _userPhone = '';
    notifyListeners();
  }

  Future<void> loadForUser(String phone) async {
    _userPhone = phone;
    final prefs = await SharedPreferences.getInstance();
    final suffix = _userPhone.isNotEmpty ? '_$_userPhone' : '';
    
    var data = prefs.getStringList('localmart_addresses$suffix');
    _selectedIndex = prefs.getInt('localmart_selected_address$suffix') ?? 0;
    
    // Fallback to legacy global addresses if user-specific list is empty/null
    if (data == null && _userPhone.isNotEmpty) {
      data = prefs.getStringList('localmart_addresses');
      _selectedIndex = prefs.getInt('localmart_selected_address') ?? 0;
      // Copy to user-specific list immediately so it persists there
      if (data != null) {
        await prefs.setStringList('localmart_addresses$suffix', data);
        await prefs.setInt('localmart_selected_address$suffix', _selectedIndex);
      }
    }

    if (data != null) {
      _addresses = data.map((s) => SavedAddress.fromJson(json.decode(s))).toList();
    } else {
      _addresses = [];
    }
    notifyListeners();
  }

  void selectAddress(int index) {
    _selectedIndex = index;
    _save();
    notifyListeners();
  }

  Future<void> addAddress(SavedAddress addr) async {
    _addresses.add(addr);
    _selectedIndex = _addresses.length - 1;
    await _save();
    notifyListeners();
  }

  Future<void> removeAddress(int index) async {
    _addresses.removeAt(index);
    if (_selectedIndex >= _addresses.length && _addresses.isNotEmpty) {
      _selectedIndex = _addresses.length - 1;
    }
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _addresses.map((a) => json.encode(a.toJson())).toList();
    final suffix = _userPhone.isNotEmpty ? '_$_userPhone' : '';
    await prefs.setStringList('localmart_addresses$suffix', data);
    await prefs.setInt('localmart_selected_address$suffix', _selectedIndex);
  }

  Future<void> clearAddresses() async {
    _addresses.clear();
    _selectedIndex = 0;
    final prefs = await SharedPreferences.getInstance();
    final suffix = _userPhone.isNotEmpty ? '_$_userPhone' : '';
    await prefs.remove('localmart_addresses$suffix');
    await prefs.remove('localmart_selected_address$suffix');
    notifyListeners();
  }
}
