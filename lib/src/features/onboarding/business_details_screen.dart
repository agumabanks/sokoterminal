import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/onboarding/onboarding_controller.dart';

class BusinessDetailsEnhancedScreen extends ConsumerStatefulWidget {
  const BusinessDetailsEnhancedScreen({super.key});

  @override
  ConsumerState<BusinessDetailsEnhancedScreen> createState() =>
      _BusinessDetailsEnhancedScreenState();
}

class _BusinessDetailsEnhancedScreenState
    extends ConsumerState<BusinessDetailsEnhancedScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();

  LatLng? _selectedLocation;
  double _deliveryRadiusKm = 5.0; // Default 5km
  bool _showMap = false;
  GoogleMapController? _mapController;

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
    _addressController.dispose();
    _phoneController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.black, size: 20),
          onPressed: () => context.go('/onboarding/shop-basics'),
        ),
        title: const Text(
          'Business Details',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressIndicator(3, 5),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Where Are You Located?',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Help customers find you easily',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 32),

                      // Location Picker Card
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
                                  child: const Icon(Icons.location_on,
                                      color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Shop Location',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedLocation != null
                                            ? 'Lat: ${_selectedLocation!.latitude.toStringAsFixed(4)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(4)}'
                                            : 'Not set',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _handleSetLocation,
                                icon: const Icon(Icons.my_location),
                                label: Text(_selectedLocation == null
                                    ? 'Set Location on Map'
                                    : 'Change Location'),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  side: const BorderSide(color: Colors.blue),
                                  foregroundColor: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Delivery Radius
                      if (_selectedLocation != null) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.delivery_dining,
                                        color: Colors.white, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Delivery Radius',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Soko24 delivers within this radius',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Row(
                                children: [
                                  Expanded(
                                    child: Slider(
                                      value: _deliveryRadiusKm,
                                      min: 1,
                                      max: 20,
                                      divisions: 19,
                                      label:
                                          '${_deliveryRadiusKm.toStringAsFixed(0)} km',
                                      activeColor: Colors.green,
                                      onChanged: (value) {
                                        setState(() =>
                                            _deliveryRadiusKm = value);
                                      },
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${_deliveryRadiusKm.toStringAsFixed(0)} km',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      _buildModernField(
                        controller: _addressController,
                        label: 'Business Address (Optional)',
                        icon: Icons.home_outlined,
                        hint: 'Street, City, Country',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),

                      _buildModernField(
                        controller: _phoneController,
                        label: 'Contact Phone (Optional)',
                        icon: Icons.phone_outlined,
                        hint: '+256 700 000 000',
                      ),
                      const SizedBox(height: 24),

                      Text(
                        'Social Media (Optional)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildModernField(
                        controller: _facebookController,
                        label: 'Facebook',
                        icon: Icons.facebook,
                        hint: 'facebook.com/yourpage',
                      ),
                      const SizedBox(height: 16),

                      _buildModernField(
                        controller: _instagramController,
                        label: 'Instagram',
                        icon: Icons.camera_alt_outlined,
                        hint: '@yourbusiness',
                      ),
                      const SizedBox(height: 32),

                      // Continue Button
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _handleContinue,
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextButton(
                        onPressed: () =>
                            context.go('/onboarding/payment-config'),
                        child: Text(
                          'Skip for now',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _applyOnboardingState(OnboardingState onboarding, {bool notify = false}) {
    final data = onboarding.shopData;
    if (data.isEmpty) return;

    bool changed = false;
    final address = data['address']?.toString();
    if (_addressController.text.isEmpty && address != null && address.isNotEmpty) {
      _addressController.text = address;
    }

    final phone = data['phone']?.toString();
    if (_phoneController.text.isEmpty && phone != null && phone.isNotEmpty) {
      _phoneController.text = phone;
    }

    final facebook = data['facebook']?.toString();
    if (_facebookController.text.isEmpty && facebook != null && facebook.isNotEmpty) {
      _facebookController.text = facebook;
    }

    final instagram = data['instagram']?.toString();
    if (_instagramController.text.isEmpty && instagram != null && instagram.isNotEmpty) {
      _instagramController.text = instagram;
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

  Widget _buildProgressIndicator(int current, int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Step $current of $total',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              Text(
                '${((current / total) * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: current / total,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          prefixIcon: Icon(icon, color: Colors.grey[500], size: 22),
          labelText: label,
          hintText: hint,
          floatingLabelStyle: TextStyle(color: Colors.grey[800]),
          labelStyle: TextStyle(color: Colors.grey[500]),
          hintStyle: TextStyle(color: Colors.grey[400]),
        ),
      ),
    );
  }

  Future<void> _handleSetLocation() async {
    // Request location permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }
    }

    // Get current location
    LatLng? initialLocation = _selectedLocation;
    if (initialLocation == null) {
      try {
        final position = await Geolocator.getCurrentPosition();
        initialLocation = LatLng(position.latitude, position.longitude);
      } catch (e) {
        // Default to Kampala if current location fails
        initialLocation = const LatLng(0.3476, 32.5825);
      }
    }

    if (!mounted) return;

    // Show map dialog
    final result = await showDialog<LatLng>(
      context: context,
      builder: (context) => _MapPickerDialog(initialLocation: initialLocation!),
    );

    if (result != null) {
      setState(() => _selectedLocation = result);
    }
  }

  void _handleContinue() {
    final controller = ref.read(onboardingControllerProvider.notifier);
    controller.updateShopData({
      'address': _addressController.text.trim(),
      'phone': _phoneController.text.trim(),
      'facebook': _facebookController.text.trim(),
      'instagram': _instagramController.text.trim(),
      if (_selectedLocation != null) ...{
        'delivery_pickup_latitude': _selectedLocation!.latitude,
        'delivery_pickup_longitude': _selectedLocation!.longitude,
        'delivery_radius_km': _deliveryRadiusKm,
      },
    });
    controller.goToStage(4);

    context.go('/onboarding/payment-config');
  }
}

class _MapPickerDialog extends StatefulWidget {
  const _MapPickerDialog({required this.initialLocation});

  final LatLng initialLocation;

  @override
  State<_MapPickerDialog> createState() => _MapPickerDialogState();
}

class _MapPickerDialogState extends State<_MapPickerDialog> {
  late LatLng _currentLocation;
  GoogleMapController? _controller;

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select Shop Location',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentLocation,
                  zoom: 15,
                ),
                onMapCreated: (controller) => _controller = controller,
                onTap: (location) {
                  setState(() => _currentLocation = location);
                },
                markers: {
                  Marker(
                    markerId: const MarkerId('shop_location'),
                    position: _currentLocation,
                    draggable: true,
                    onDragEnd: (location) {
                      setState(() => _currentLocation = location);
                    },
                  ),
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Tap or drag the marker to set location',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, _currentLocation),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Confirm Location',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
