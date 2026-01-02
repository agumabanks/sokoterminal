import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/app_providers.dart';
import '../../core/onboarding/onboarding_controller.dart';
import '../../core/sync/sync_service.dart';

class QuickOnboardingScreen extends ConsumerStatefulWidget {
  const QuickOnboardingScreen({super.key});

  @override
  ConsumerState<QuickOnboardingScreen> createState() => _QuickOnboardingScreenState();
}

class _QuickOnboardingScreenState extends ConsumerState<QuickOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  
  String? _selectedCategory;
  LatLng? _selectedLocation;
  double _deliveryRadiusKm = 5.0;
  bool _isLoadingLocation = false;
  bool _isSaving = false;
  
  final List<String> _categories = [
    'Fashion & Apparel',
    'Electronics',
    'Food & Beverages',
    'Health & Beauty',
    'Home & Garden',
    'Sports & Outdoors',
    'Books & Media',
    'Toys & Games',
    'Automotive',
    'Services',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _applyOnboardingState(ref.read(onboardingControllerProvider));
    ref.listen<OnboardingState>(onboardingControllerProvider, (_, next) {
      _applyOnboardingState(next, notify: true);
    });
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                
                // Header
                const Text(
                  'Set Up Your Shop',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Just the essentials - you\'re 1 minute away from selling',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 40),
                
                // Shop Name
                _buildModernField(
                  controller: _shopNameController,
                  label: 'Shop Name',
                  icon: Icons.storefront_rounded,
                  hint: 'e.g., Fresh Market Uganda',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Shop name is required';
                    }
                    if (value.trim().length < 3) {
                      return 'Shop name is too short';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                
                // Category
                _buildCategoryDropdown(),
                const SizedBox(height: 24),
                
                // Location Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Shop Location',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedLocation != null
                                      ? 'Location set ✓'
                                      : 'For Soko24 delivery',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isLoadingLocation ? null : _handleQuickLocation,
                          icon: _isLoadingLocation
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.my_location),
                          label: Text(_isLoadingLocation ? 'Getting location...' : 'Use My Current Location'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      if (_selectedLocation != null) ...[
                        const SizedBox(height: 16),
                        
                        // Delivery Radius
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Delivery Radius',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    '${_deliveryRadiusKm.toStringAsFixed(0)} km',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: _deliveryRadiusKm,
                              min: 1,
                              max: 20,
                              divisions: 19,
                              activeColor: Colors.blue,
                              onChanged: (value) => setState(() => _deliveryRadiusKm = value),
                            ),
                            Text(
                              'Soko24 will handle deliveries within this radius',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                
                // Start Selling Button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isSaving ? null : _handleStartSelling,
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Start Selling',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                
                Center(
                  child: Text(
                    'You can add more details later in settings',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedCategory,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          prefixIcon: Icon(Icons.category_outlined, color: Colors.grey[500], size: 22),
          labelText: 'Business Category',
          floatingLabelStyle: TextStyle(color: Colors.grey[800]),
          labelStyle: TextStyle(color: Colors.grey[500]),
        ),
        items: _categories.map((category) {
          return DropdownMenuItem(value: category, child: Text(category));
        }).toList(),
        onChanged: (value) => setState(() => _selectedCategory = value),
        validator: (value) => value == null ? 'Please select a category' : null,
      ),
    );
  }

  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          prefixIcon: Icon(icon, color: Colors.grey[500], size: 22),
          labelText: label,
          hintText: hint,
          floatingLabelStyle: TextStyle(color: Colors.grey[800]),
          labelStyle: TextStyle(color: Colors.grey[500]),
          hintStyle: TextStyle(color: Colors.grey[400]),
        ),
        validator: validator,
      ),
    );
  }

  void _applyOnboardingState(OnboardingState onboarding, {bool notify = false}) {
    final data = onboarding.shopData;
    if (data.isEmpty) return;

    bool changed = false;
    final name = data['name']?.toString();
    if (_shopNameController.text.isEmpty && name != null && name.isNotEmpty) {
      _shopNameController.text = name;
    }

    final category = data['category']?.toString();
    if (_selectedCategory == null &&
        category != null &&
        category.isNotEmpty &&
        _categories.contains(category)) {
      _selectedCategory = category;
      changed = true;
    }

    final latitude = _asDouble(data['delivery_pickup_latitude']);
    final longitude = _asDouble(data['delivery_pickup_longitude']);
    if (_selectedLocation == null && latitude != null && longitude != null) {
      _selectedLocation = LatLng(latitude, longitude);
      changed = true;
    }

    final radius = _asDouble(data['delivery_radius_km']);
    if (radius != null) {
      final clamped = radius.clamp(1, 20).toDouble();
      if (_deliveryRadiusKm != clamped) {
        _deliveryRadiusKm = clamped;
        changed = true;
      }
    }

    if (changed && notify && mounted) {
      setState(() {});
    }
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<void> _handleQuickLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      // Request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied');
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location set successfully ✓'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get location: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<void> _handleStartSelling() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Prepare shop data
      final shopData = {
        'name': _shopNameController.text.trim(),
        'category': _selectedCategory,
        'cash_on_delivery_status': 1, // Enable COD by default
        if (_selectedLocation != null) ...{
          'delivery_pickup_latitude': _selectedLocation!.latitude,
          'delivery_pickup_longitude': _selectedLocation!.longitude,
          'delivery_radius_km': _deliveryRadiusKm,
        },
      };

      // Save to backend
      final controller = ref.read(onboardingControllerProvider.notifier);
      controller.updateShopData(shopData);

      final payload = ref.read(onboardingControllerProvider).shopData;
      final api = ref.read(sellerApiProvider);
      await api.updateShopInfo(payload);

      // Mark onboarding complete
      await controller.completeOnboarding();

      // Start sync
      ref.read(syncServiceProvider).start();

      if (!mounted) return;

      // Navigate to dashboard
      context.go('/home/checkout');
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          action: SnackBarAction(
            label: 'Continue Anyway',
            onPressed: () {
              ref.read(onboardingControllerProvider.notifier).completeOnboarding();
              ref.read(syncServiceProvider).start();
              context.go('/home/checkout');
            },
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
