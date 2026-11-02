import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerProfile {
  const CustomerProfile({
    required this.userId,
    required this.fullName,
    required this.phone,
  });

  final String userId;
  final String fullName;
  final String phone;

  factory CustomerProfile.fromJson(Map<String, dynamic> json) =>
      CustomerProfile(
        userId: json['user_id'].toString(),
        fullName: json['full_name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
      );
}

enum AddressLabel {
  home('Home'),
  work('Work'),
  other('Other');

  const AddressLabel(this.label);
  final String label;

  static AddressLabel fromValue(Object? value) =>
      AddressLabel.values.firstWhere(
        (item) => item.label == value,
        orElse: () => AddressLabel.other,
      );
}

class CustomerAddress {
  const CustomerAddress({
    this.id,
    required this.userId,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.houseFlatBuilding,
    required this.streetArea,
    this.landmark = '',
    required this.city,
    required this.state,
    required this.postalCode,
    this.country = 'India',
    this.isDefault = false,
  });

  final String? id;
  final String userId;
  final AddressLabel label;
  final String recipientName;
  final String phone;
  final String houseFlatBuilding;
  final String streetArea;
  final String landmark;
  final String city;
  final String state;
  final String postalCode;
  final String country;
  final bool isDefault;

  factory CustomerAddress.fromJson(Map<String, dynamic> json) =>
      CustomerAddress(
        id: json['id']?.toString(),
        userId: json['user_id'].toString(),
        label: AddressLabel.fromValue(json['address_label']),
        recipientName: json['recipient_name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        houseFlatBuilding: json['house_flat_building']?.toString() ?? '',
        streetArea: json['street_area']?.toString() ?? '',
        landmark: json['landmark']?.toString() ?? '',
        city: json['city']?.toString() ?? '',
        state: json['state']?.toString() ?? '',
        postalCode: json['postal_code']?.toString() ?? '',
        country: json['country']?.toString() ?? 'India',
        isDefault: json['is_default'] == true,
      );

  Map<String, dynamic> toRpcParams({bool? defaultOverride}) => {
    'p_address_id': id,
    'p_address_label': label.label,
    'p_recipient_name': recipientName.trim(),
    'p_phone': phone.trim(),
    'p_house_flat_building': houseFlatBuilding.trim(),
    'p_street_area': streetArea.trim(),
    'p_landmark': landmark.trim(),
    'p_city': city.trim(),
    'p_state': state.trim(),
    'p_postal_code': postalCode.trim(),
    'p_country': country.trim(),
    'p_is_default': defaultOverride ?? isDefault,
  };

  CustomerAddress copyWith({String? id, bool? isDefault}) => CustomerAddress(
    id: id ?? this.id,
    userId: userId,
    label: label,
    recipientName: recipientName,
    phone: phone,
    houseFlatBuilding: houseFlatBuilding,
    streetArea: streetArea,
    landmark: landmark,
    city: city,
    state: state,
    postalCode: postalCode,
    country: country,
    isDefault: isDefault ?? this.isDefault,
  );

  String get firstAddressLine => '$houseFlatBuilding, $streetArea';

  String get secondAddressLine => [
    if (landmark.trim().isNotEmpty) 'Landmark: ${landmark.trim()}',
    country.trim(),
  ].join(' · ');
}

abstract class CustomerDataRepository {
  Future<CustomerProfile?> loadProfile();
  Future<CustomerProfile> saveProfile({
    required String fullName,
    required String phone,
  });
  Future<List<CustomerAddress>> loadAddresses();
  Future<CustomerAddress> saveAddress(CustomerAddress address);
  Future<void> setDefaultAddress(String addressId);
  Future<void> deleteAddress(String addressId);
}

class CustomerDataRepositoryException implements Exception {
  const CustomerDataRepositoryException(this.message);
  final String message;

  @override
  String toString() => message;
}

class SupabaseCustomerDataRepository extends CustomerDataRepository {
  SupabaseCustomerDataRepository(this._client);

  final SupabaseClient? _client;

  @override
  Future<CustomerProfile?> loadProfile() async {
    final userId = _userId;
    final row = await _requireClient()
        .from('customer_profiles')
        .select('user_id,full_name,phone')
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : CustomerProfile.fromJson(row);
  }

  @override
  Future<CustomerProfile> saveProfile({
    required String fullName,
    required String phone,
  }) async {
    final data = await _requireClient().rpc(
      'save_customer_profile',
      params: {'p_full_name': fullName.trim(), 'p_phone': phone.trim()},
    );
    return CustomerProfile.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<List<CustomerAddress>> loadAddresses() async {
    final rows = await _requireClient()
        .from('customer_addresses')
        .select()
        .eq('user_id', _userId)
        .order('is_default', ascending: false)
        .order('created_at');
    return rows
        .map((row) => CustomerAddress.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  @override
  Future<CustomerAddress> saveAddress(CustomerAddress address) async {
    if (address.userId != _userId) {
      throw const CustomerDataRepositoryException(
        'This address does not belong to the signed-in customer.',
      );
    }
    final data = await _requireClient().rpc(
      'save_customer_address',
      params: address.toRpcParams(),
    );
    return CustomerAddress.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<void> setDefaultAddress(String addressId) async {
    await _requireClient().rpc(
      'set_default_customer_address',
      params: {'p_address_id': addressId},
    );
  }

  @override
  Future<void> deleteAddress(String addressId) async {
    await _requireClient().rpc(
      'delete_customer_address',
      params: {'p_address_id': addressId},
    );
  }

  String get _userId {
    final userId = _requireClient().auth.currentUser?.id;
    if (userId == null) {
      throw const CustomerDataRepositoryException(
        'Sign in to manage profile details and addresses.',
      );
    }
    return userId;
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const CustomerDataRepositoryException(
        'Profile and address services are unavailable until Supabase is configured.',
      );
    }
    return client;
  }
}
