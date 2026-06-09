import '../../core/util/haptics.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/util/phone_normalizer.dart';
import '../../core/firebase/firebase_analytics_service.dart';
import 'dart:ui';

import '../../core/app_providers.dart';
import '../../core/db/app_database.dart';
import '../../core/settings/business_profile_cache.dart';
import '../../core/settings/business_setup_prefs.dart';
import '../../core/sync/sync_service.dart';
import '../../core/util/country_codes.dart';
import '../../core/services/places_service.dart';
import 'auth_controller.dart';
import 'post_registration_welcome_provider.dart';

/// Ultra-Premium multi-step seller registration
/// "Steve Jobs" standard: Minimal, Smart, Liquid Animations
class SellerRegistrationScreen extends ConsumerStatefulWidget {
  const SellerRegistrationScreen({super.key, this.initialPhone});

  final String? initialPhone;

  @override
  ConsumerState<SellerRegistrationScreen> createState() =>
      _SellerRegistrationScreenState();
}

class _SellerRegistrationScreenState
    extends ConsumerState<SellerRegistrationScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;
  String? _errorTitle;
  Timer? _errorTimer;

  // Animations
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Step 1: Personal Info
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _pinConfirmController = TextEditingController();
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _pinFocus = FocusNode();
  final _pinConfirmFocus = FocusNode();

  CountryCode _selectedCountry = defaultCountryCode;
  bool _obscurePin = true;

  // Step 2: Shop Info
  final _shopNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _shopNameFocus = FocusNode();
  final _addressFocus = FocusNode();
  String? _selectedCategory;
  bool _loadingPlans = true;
  List<_RegistrationPlan> _plans = const [];
  _RegistrationPlan? _selectedPlan;

  // Smart Address Logic
  final _placesService = PlacesService();
  Timer? _debounce;
  final _addressLayerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  // Step 3: Location (Hybrid)
  bool _useGoogleMaps = false;
  bool _checkingMaps = true;
  LatLng? _location;
  double _deliveryRadiusKm = 5.0;
  bool _isLoadingLocation = false;
  bool _isResolvingAddress = false;
  String? _lastResolvedQuery;
  bool _fallbackTilesFailed = false;
  double _fallbackZoom = 15;
  final fmap.MapController _fallbackMapController = fmap.MapController();
  bool _locationPermissionGranted = false;
  bool _locationServicesEnabled = false;
  bool _mapReady = false;

  GoogleMapController? _mapController;
  Set<Circle> _circles = {};
  Set<Marker> _markers = {};
  String? _gpsLabel;

  static const List<Map<String, dynamic>> _allCategories = [
    {
      'name': 'Supermarket & Groceries',
      'icon': Icons.shopping_cart,
      'group': 'Retail',
    },
    {'name': 'Mini Mart / Duka', 'icon': Icons.store, 'group': 'Retail'},
    {
      'name': 'Wholesale & Distribution',
      'icon': Icons.inventory_2,
      'group': 'Retail',
    },
    {'name': 'Fashion & Clothing', 'icon': Icons.checkroom, 'group': 'Retail'},
    {'name': 'Shoes & Footwear', 'icon': Icons.hiking, 'group': 'Retail'},
    {'name': 'Jewelry & Accessories', 'icon': Icons.diamond, 'group': 'Retail'},
    {
      'name': 'Cosmetics & Beauty',
      'icon': Icons.face_retouching_natural,
      'group': 'Retail',
    },
    {'name': 'Electronics', 'icon': Icons.devices, 'group': 'Retail'},
    {
      'name': 'Phones & Accessories',
      'icon': Icons.phone_android,
      'group': 'Retail',
    },
    {'name': 'Computers & IT', 'icon': Icons.computer, 'group': 'Retail'},
    {'name': 'Home Appliances', 'icon': Icons.kitchen, 'group': 'Retail'},
    {'name': 'Furniture', 'icon': Icons.chair, 'group': 'Retail'},
    {'name': 'Hardware', 'icon': Icons.hardware, 'group': 'Retail'},
    {'name': 'Stationery', 'icon': Icons.edit, 'group': 'Retail'},
    {'name': 'Books', 'icon': Icons.menu_book, 'group': 'Retail'},
    {'name': 'Sports', 'icon': Icons.sports_soccer, 'group': 'Retail'},
    {'name': 'Kids & Toys', 'icon': Icons.child_care, 'group': 'Retail'},
    {'name': 'Pet Supplies', 'icon': Icons.pets, 'group': 'Retail'},
    {'name': 'Gifts', 'icon': Icons.card_giftcard, 'group': 'Retail'},
    {'name': 'Restaurant', 'icon': Icons.restaurant, 'group': 'Food'},
    {'name': 'Fast Food', 'icon': Icons.fastfood, 'group': 'Food'},
    {'name': 'Cafe', 'icon': Icons.coffee, 'group': 'Food'},
    {'name': 'Bakery', 'icon': Icons.cake, 'group': 'Food'},
    {'name': 'Butchery', 'icon': Icons.set_meal, 'group': 'Food'},
    {'name': 'Fresh Produce', 'icon': Icons.eco, 'group': 'Food'},
    {'name': 'Drinks & Liquor', 'icon': Icons.local_drink, 'group': 'Food'},
    {
      'name': 'Street Food / Rolex',
      'icon': Icons.lunch_dining,
      'group': 'Food',
    },
    {
      'name': 'Mobile Money',
      'icon': Icons.account_balance_wallet,
      'group': 'Services',
    },
    {'name': 'Salon & Barber', 'icon': Icons.content_cut, 'group': 'Services'},
    {'name': 'Spa & Beauty', 'icon': Icons.spa, 'group': 'Services'},
    {'name': 'Pharmacy', 'icon': Icons.local_pharmacy, 'group': 'Health'},
    {'name': 'Clinic', 'icon': Icons.local_hospital, 'group': 'Health'},
    {
      'name': 'Dry Cleaning',
      'icon': Icons.local_laundry_service,
      'group': 'Services',
    },
    {'name': 'Tailoring', 'icon': Icons.straighten, 'group': 'Services'},
    {'name': 'Car Wash', 'icon': Icons.local_car_wash, 'group': 'Services'},
    {'name': 'Auto Repair', 'icon': Icons.car_repair, 'group': 'Services'},
    {'name': 'Boda Boda', 'icon': Icons.two_wheeler, 'group': 'Services'},
    {'name': 'Printing', 'icon': Icons.print, 'group': 'Services'},
    {'name': 'Photography', 'icon': Icons.camera_alt, 'group': 'Services'},
    {'name': 'Events', 'icon': Icons.celebration, 'group': 'Services'},
    {'name': 'Cleaning', 'icon': Icons.cleaning_services, 'group': 'Services'},
    {'name': 'Security', 'icon': Icons.security, 'group': 'Services'},
    {
      'name': 'Professional Services',
      'icon': Icons.business_center,
      'group': 'Services',
    },
    {
      'name': 'Internet Cafe',
      'icon': Icons.videogame_asset,
      'group': 'Services',
    },
    {'name': 'Agriculture', 'icon': Icons.agriculture, 'group': 'Other'},
    {'name': 'Construction', 'icon': Icons.construction, 'group': 'Other'},
    {'name': 'Education', 'icon': Icons.school, 'group': 'Other'},
    {'name': 'Hotel & Lodging', 'icon': Icons.hotel, 'group': 'Other'},
    {'name': 'Manufacturing', 'icon': Icons.factory, 'group': 'Other'},
    {'name': 'Entertainment', 'icon': Icons.movie, 'group': 'Other'},
    {'name': 'Religious', 'icon': Icons.church, 'group': 'Other'},
    {'name': 'Other', 'icon': Icons.more_horiz, 'group': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    _requestLocationPermissionEarly();
    _checkGooglePlayServices();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutBack,
    );

    // Listen to address focus to close overlay on blur
    _addressFocus.addListener(() {
      if (!_addressFocus.hasFocus) {
        _removeOverlay();
      }
    });

    if (widget.initialPhone != null) {
      var phone = widget.initialPhone!;
      final codeDigits = _selectedCountry.code.replaceFirst('+', '');
      if (phone.startsWith(codeDigits)) {
        phone = phone.substring(codeDigits.length);
      }
      _phoneController.text = phone;
    }
    _fadeController.forward();
    unawaited(_loadPlans());
  }

  Future<void> _loadPlans() async {
    try {
      final response = await ref
          .read(sellerApiProvider)
          .fetchSellerRegistrationPlans();
      final body = response.data is Map<String, dynamic>
          ? Map<String, dynamic>.from(response.data as Map<String, dynamic>)
          : const <String, dynamic>{};
      final rawPlans = body['data'] is List
          ? List<dynamic>.from(body['data'] as List)
          : body['plans'] is List
          ? List<dynamic>.from(body['plans'] as List)
          : const <dynamic>[];
      final plans =
          rawPlans
              .whereType<Map>()
              .map(
                (e) => _RegistrationPlan.fromJson(Map<String, dynamic>.from(e)),
              )
              .where((plan) => plan.isActive)
              .toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _selectedPlan = plans.isEmpty
            ? null
            : plans.firstWhere(
                (plan) => plan.slug == 'start',
                orElse: () => plans.first,
              );
        _loadingPlans = false;
      });
    } catch (e) {
      debugPrint('[Registration] loadPlans failed: $e');
      if (!mounted) return;
      setState(() {
        _loadingPlans = false;
      });
    }
  }

  Future<void> _checkGooglePlayServices() async {
    // Force OpenStreetMap fallback to avoid native GoogleMap crashes on
    // devices with missing/restricted Google Play Services or API keys.
    // This lets testers use the app immediately without Google Cloud Console setup.
    if (mounted) {
      setState(() {
        _useGoogleMaps = false;
        _checkingMaps = false;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pageController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    _pinConfirmController.dispose();
    _shopNameController.dispose();
    _addressController.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _pinFocus.dispose();
    _pinConfirmFocus.dispose();
    _shopNameFocus.dispose();
    _addressFocus.dispose();
    _mapController?.dispose();
    _fallbackMapController.dispose();
    _debounce?.cancel();
    _errorTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onAddressChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.isEmpty) {
      _removeOverlay();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final predictions = await _placesService.search(query);
        if (mounted && _addressFocus.hasFocus) {
          _showOverlay(predictions);
        }
      } catch (e) {
        debugPrint('[Registration] address search failed: $e');
      }
    });
  }

  void _showOverlay(List<PlacePrediction> predictions) {
    _removeOverlay();
    if (predictions.isEmpty) return;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return;
    final size = renderObject.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width - 48, // Padding adjusted
        child: CompositedTransformFollower(
          link: _addressLayerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 60), // Dropdown offset
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2C).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: predictions.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Colors.white.withOpacity(0.05),
                    ),
                    itemBuilder: (context, index) {
                      final p = predictions[index];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: Color(0xFF6C63FF),
                          size: 20,
                        ),
                        title: Text(
                          p.mainText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          p.secondaryText,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                        onTap: () => _selectSuggestion(p),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _selectSuggestion(PlacePrediction prediction) async {
    _removeOverlay();
    _addressFocus.unfocus();

    // Optimistic UI update
    _addressController.text = prediction.description;
    Haptics.selection();

    try {
      final details = await _placesService.getDetails(prediction.placeId);
      if (details != null) {
        _addressController.text = details.address; // Use full formatted address
        setState(() {
          _lastResolvedQuery = details.address;
        });
        _updateLocationMap(LatLng(details.lat, details.lng));
        if (_useGoogleMaps && _mapController != null) {
          try {
            await _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(_location!, 16),
            );
          } catch (e) {
            debugPrint('[Map] animateCamera failed: $e');
          }
        }
        Haptics.impact();
      }
    } catch (e) {
      debugPrint('[Registration] selectSuggestion failed: $e');
    }
  }

  void _schedulePostRegistrationTasks({
    required LatLng location,
    required String address,
  }) {
    unawaited(_upsertDeliveryProfile(location: location, address: address));
    unawaited(_forceRegistrationResync());
  }

  Future<void> _upsertDeliveryProfile({
    required LatLng location,
    required String address,
  }) async {
    try {
      await ref.read(sellerApiProvider).upsertDeliveryProfile({
        'enabled': true,
        'origin_lat': location.latitude,
        'origin_lng': location.longitude,
        'origin_label': address,
        'radius_km': _deliveryRadiusKm,
        'pricing_mode': 'base_per_km',
        'base_fee': 2000,
        'per_km_fee': 500,
        'min_fee': 2000,
      });
    } catch (e) {
      debugPrint('[Registration] delivery profile update failed: $e');
    }
  }

  Future<void> _forceRegistrationResync() async {
    try {
      await ref.read(syncServiceProvider).forceFullResync();
    } catch (e) {
      debugPrint('[Registration] resync failed: $e');
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      if (!_validateCurrentStep()) return;

      _addressFocus.unfocus();
      _removeOverlay();

      _fadeController.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _currentStep++;
          if (_currentStep == 2) _mapReady = false;
        });
          _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutQuint,
        ).then((_) {
          if (mounted && _currentStep == 2) {
            setState(() => _mapReady = true);
          }
        });
        _fadeController.forward();
        if (_currentStep == 2 && !_useGoogleMaps) {
          _maybeResolveAddressOnEntry();
        }
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _fadeController.reverse().then((_) {
        if (!mounted) return;
        setState(() {
          _currentStep--;
          _mapReady = false;
        });
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutQuint,
        );
        _fadeController.forward();
      });
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_nameController.text.trim().isEmpty)
          return _showError('Can\'t assume your name!');
        if (_phoneController.text.trim().isEmpty)
          return _showError('Phone number required');
        if (!RegExp(r'^\d{6}$').hasMatch(_pinController.text))
          return _showError('PIN must be exactly 6 digits');
        if (_pinController.text != _pinConfirmController.text)
          return _showError('PINs do not match');
        return true;
      case 1:
        if (_shopNameController.text.trim().isEmpty)
          return _showError('Business needs a name');
        if (_selectedCategory == null) return _showError('Select a category');
        if (_plans.isNotEmpty && _selectedPlan == null) {
          return _showError('Choose a Sanaa plan');
        }
        return true;
      default:
        return true;
    }
  }

  bool _showError(
    String message, {
    String title = 'Action needed',
    Duration duration = const Duration(seconds: 5),
  }) {
    _errorTimer?.cancel();
    setState(() {
      _errorTitle = title;
      _errorMessage = message;
    });
    Haptics.warning();
    _errorTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() {
        _errorMessage = null;
        _errorTitle = null;
      });
    });
    return false;
  }

  Future<void> _requestLocationPermissionEarly() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      final servicesEnabled = await Geolocator.isLocationServiceEnabled();
      if (mounted) {
        setState(() {
          _locationPermissionGranted =
              permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always;
          _locationServicesEnabled = servicesEnabled;
        });
      }
    } catch (e) {
      debugPrint('[Registration] location permission request failed: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    Haptics.impact();

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showError('Allow location to proceed');
        setState(() => _isLoadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
        ),
      ).timeout(const Duration(seconds: 10));
      final latLng = LatLng(position.latitude, position.longitude);

      if (_useGoogleMaps && _mapController != null) {
        try {
          await _mapController!.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16));
        } catch (e) {
          debugPrint('[Map] animateCamera failed: $e');
        }
        _updateLocationMap(latLng);
      } else {
        Haptics.impact();
        _updateLocationMap(latLng);
        setState(() {
          _gpsLabel =
              '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
          _lastResolvedQuery = null;
        });
      }
    } catch (e) {
      debugPrint('[Registration] GPS failed: $e');
      // Fallback to Kampala so the user can proceed and adjust manually
      const fallback = LatLng(0.3476, 32.5825);
      _updateLocationMap(fallback);
      setState(() {
        _gpsLabel = 'Kampala (tap map to adjust)';
        _lastResolvedQuery = null;
      });
      _showError('GPS unavailable. Set location manually on the map.');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _updateLocationMap(LatLng location) {
    _updateLocationMapWithOptions(location, withHaptics: true);
  }

  void _updateLocationMapWithOptions(
    LatLng location, {
    required bool withHaptics,
  }) {
    if (withHaptics) Haptics.selection();
    setState(() {
      _location = location;
      _fallbackTilesFailed = false;
      _markers = {
        Marker(
          markerId: const MarkerId('shop'),
          position: location,
          draggable: true,
          onDragEnd: (newPosition) => _updateLocationMap(newPosition),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      };
      _circles = {
        Circle(
          circleId: const CircleId('delivery_radius'),
          center: location,
          radius: _deliveryRadiusKm * 1000,
          fillColor: _deliveryRadiusColor.withOpacity(0.2),
          strokeColor: _deliveryRadiusStrokeColor.withOpacity(0.95),
          strokeWidth: 4,
        ),
      };
    });
    if (!_useGoogleMaps) {
      _fallbackMapController.move(
        latlong.LatLng(location.latitude, location.longitude),
        _fallbackZoom,
      );
    }
  }

  Future<void> _animateMapTo(LatLng location) async {
    if (!_useGoogleMaps || _mapController == null) return;
    try {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(location, 16),
      );
    } catch (e) {
      debugPrint('[Map] animateCamera failed: $e');
    }
  }

  String _normalizePhone(String phone) {
    // Use standard normalizer to ensure consistency with Auth/Backend (e.g. 256xxxx vs +256xxxx)
    if (_selectedCountry.code == '+256') {
      return normalizeUgPhone(phone);
    }
    String digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) digits = digits.substring(1);
    return '${_selectedCountry.code}$digits';
  }

  void _showCategoryPicker() {
    Haptics.soft();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CategoryPickerSheet(
        categories: _allCategories,
        selected: _selectedCategory,
        onSelect: (category) {
          Haptics.impact();
          setState(() => _selectedCategory = category);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _maybeResolveAddressOnEntry() async {
    final query = _addressController.text.trim();
    if (query.isEmpty) return;
    if (_isResolvingAddress) return;
    if (_lastResolvedQuery == query && _location != null) return;
    await _resolveAddressToLocation(query, force: false);
  }

  Future<void> _resolveAddressToLocation(
    String query, {
    required bool force,
  }) async {
    if (query.isEmpty || _isResolvingAddress) return;
    if (!force && _lastResolvedQuery == query && _location != null) return;

    setState(() => _isResolvingAddress = true);

    try {
      final predictions = await _placesService.search(query);
      if (predictions.isEmpty) return;

      final details = await _placesService.getDetails(
        predictions.first.placeId,
      );
      if (details == null) return;

      final nextLocation = LatLng(details.lat, details.lng);
      _addressController.text = details.address;
      setState(() {
        _lastResolvedQuery = details.address;
      });

      _updateLocationMap(nextLocation);
      if (_useGoogleMaps && _mapController != null) {
        try {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(nextLocation, 16),
          );
        } catch (e) {
          debugPrint('[Map] animateCamera failed: $e');
        }
      }
      Haptics.impact();
    } catch (e) {
      debugPrint('[Registration] resolveAddressToLocation failed: $e');
    } finally {
      if (mounted) setState(() => _isResolvingAddress = false);
    }
  }

  Future<void> _handleSubmit() async {
    if (_location == null) {
      _showError(
        _useGoogleMaps ? 'Pin location on map' : 'Tap GPS button first',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _errorTitle = null;
    });
    Haptics.warning();

    try {
      final api = ref.read(sellerApiProvider);
      final name = _nameController.text.trim();
      final phone = _normalizePhone(_phoneController.text.trim());
      final pin = _pinController.text;
      final shopName = _shopNameController.text.trim();
      final address = _addressController.text.trim();
      final location = _location!;
      final category = _selectedCategory;
      final plan = _selectedPlan;

      if (kDebugMode) debugPrint('[Registration] submit initiated');
      debugPrint(
        '[Registration] submit address="$address" location=${location.latitude},${location.longitude}',
      );
      debugPrint(
        '[Registration] submit category=$category radius=${_deliveryRadiusKm.toStringAsFixed(0)}km pinLength=${pin.length}',
      );

      // Get current GPS position for registration location (where user is right now)
      double? registrationLat;
      double? registrationLng;
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        ).timeout(const Duration(seconds: 5));
        registrationLat = position.latitude;
        registrationLng = position.longitude;
        debugPrint(
          '[Registration] GPS at signup: ${registrationLat.toStringAsFixed(5)}, ${registrationLng.toStringAsFixed(5)}',
        );
      } catch (e) {
        // Use the map location as fallback if GPS fails
        registrationLat = location.latitude;
        registrationLng = location.longitude;
        debugPrint(
          '[Registration] GPS failed, using map location for registration: $e',
        );
      }

      final registerResponse = await api.registerSeller(
        name: name,
        email: null,
        phone: phone,
        pin: pin,
        shopName: shopName,
        address: address,
        latitude: location.latitude, // Shop business location (pinned on map)
        longitude: location.longitude, // Shop business location (pinned on map)
        registrationLatitude: registrationLat, // User's GPS at signup
        registrationLongitude: registrationLng, // User's GPS at signup
        category: category,
        deliveryRadiusKm: _deliveryRadiusKm,
        planId: plan?.id,
        planSlug: plan?.slug,
      );

      if (registerResponse.statusCode != 200 &&
          registerResponse.statusCode != 201) {
        throw Exception('Registration Failed');
      }

      final rawData = registerResponse.data;
      if (rawData is! Map<String, dynamic>) {
        throw Exception('Invalid registration response from server');
      }
      final data = Map<String, dynamic>.from(rawData);
      final token =
          data['access_token']?.toString() ?? data['token']?.toString();
      if (token == null) throw Exception('No access token');

      final secureStorage = ref.read(secureStorageProvider);
      final normalizedToken = token.trim();
      if (normalizedToken.isEmpty) {
        throw Exception('Missing access token');
      }
      await secureStorage.writeAccessToken(normalizedToken);
      final persistedToken = await secureStorage.readAccessToken();
      if ((persistedToken ?? '').trim().isEmpty) {
        throw Exception(
          'Unable to persist the access token on this device. Please try again.',
        );
      }
      final user = data['user'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['user'] as Map<String, dynamic>)
          : null;
      final sellerUuid = user?['seller_uuid']?.toString();
      if (sellerUuid != null && sellerUuid.isNotEmpty) {
        await secureStorage.writeSellerUUID(sellerUuid);
      }
      final db = ref.read(appDatabaseProvider);
      await db.clearAllData();
      await _seedLocalBusinessCache(
        registrationData: data,
        sellerName: name,
        phone: phone,
        shopName: shopName,
        address: address,
        location: location,
      );
      await ref
          .read(businessSetupCompletedProvider.notifier)
          .markSetupRequired();
      ref.read(postRegistrationWelcomePendingProvider.notifier).state = true;
      await ref.read(authControllerProvider.notifier).bootstrap();

      _schedulePostRegistrationTasks(
        location: _location!,
        address: _addressController.text.trim(),
      );

      if (!mounted) {
        ref.read(postRegistrationWelcomePendingProvider.notifier).state = false;
        return;
      }
      setState(() => _isLoading = false);
      Haptics.impact();
      debugPrint(
        '[Registration] SUCCESS - showing post-registration welcome dialog',
      );
      await _showPostRegistrationWelcome();
    } on DioException catch (e) {
      debugPrint('[Registration] error: $e');
      if (_shouldFallbackRegistration(e)) {
        final success = await _fallbackRegistrationFlow();
        if (success || !mounted) return;
        return;
      }
      setState(() => _isLoading = false);
      _showError(_extractErrorMessage(e), title: 'Registration failed');
    } catch (e) {
      debugPrint('[Registration] error: $e');
      setState(() => _isLoading = false);
      _showError(
        'Registration failed. Please try again.',
        title: 'Registration failed',
      );
    }
  }

  String _extractErrorMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message']?.toString();
      final detail = data['error']?.toString() ?? data['msg']?.toString();
      final text = _pickBestErrorMessage(message, detail);
      return _humanizeErrorMessage(text);
    }
    return 'Registration failed. Please try again.';
  }

  String _pickBestErrorMessage(String? message, String? detail) {
    final cleanMessage = (message ?? '').trim();
    final cleanDetail = (detail ?? '').trim();
    final isGeneric = _isGenericMessage(cleanMessage);
    if (cleanMessage.isNotEmpty && !isGeneric) return cleanMessage;
    if (cleanDetail.isNotEmpty) return cleanDetail;
    if (cleanMessage.isNotEmpty) return cleanMessage;
    return 'Registration failed. Please try again.';
  }

  bool _isGenericMessage(String message) {
    if (message.isEmpty) return true;
    final lower = message.toLowerCase();
    return lower.contains('registration failed') ||
        lower.contains('server error') ||
        lower.contains('please try again');
  }

  String _humanizeErrorMessage(String message) {
    final column = _extractUnknownColumn(message);
    if (column != null) {
      return 'Server is missing "$column". Please update the backend database.';
    }
    if (message.contains('SQLSTATE') || message.contains('Connection: mysql')) {
      return 'Server error while saving your registration. Please try again or contact support.';
    }
    return message;
  }

  Future<void> _seedLocalBusinessCache({
    required Map<String, dynamic> registrationData,
    required String sellerName,
    required String phone,
    required String shopName,
    required String address,
    required LatLng location,
  }) async {
    final db = ref.read(appDatabaseProvider);
    final existingProfile = await db.getBusinessProfile();
    final user = registrationData['user'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(
            registrationData['user'] as Map<String, dynamic>,
          )
        : const <String, dynamic>{};
    final sellerId = user['id']?.toString() ?? existingProfile?.sellerId;
    final sellerEmail =
        user['email']?.toString() ?? existingProfile?.sellerEmail;
    final outletId =
        registrationData['shop_id']?.toString() ??
        registrationData['outlet_id']?.toString() ??
        existingProfile?.shopId ??
        'primary-outlet';
    final cleanedAddress = address.trim();
    final cleanedPhone = phone.trim();
    final cleanedShopName = shopName.trim().isEmpty
        ? sellerName.trim()
        : shopName.trim();

    await db.upsertOutlet(
      OutletsCompanion.insert(
        id: drift.Value(outletId),
        name: cleanedShopName,
        address: drift.Value(cleanedAddress.isEmpty ? null : cleanedAddress),
        phone: drift.Value(cleanedPhone.isEmpty ? null : cleanedPhone),
        updatedAt: drift.Value(DateTime.now().toUtc()),
        active: const drift.Value(true),
      ),
    );

    await db.upsertBusinessProfile(
      BusinessProfilesCompanion.insert(
        id: kPrimaryBusinessProfileId,
        sellerId: sellerId == null
            ? const drift.Value.absent()
            : drift.Value(sellerId),
        sellerName: drift.Value(sellerName.trim()),
        sellerEmail: sellerEmail == null || sellerEmail.trim().isEmpty
            ? const drift.Value.absent()
            : drift.Value(sellerEmail.trim()),
        sellerPhone: cleanedPhone.isEmpty
            ? const drift.Value.absent()
            : drift.Value(cleanedPhone),
        shopId: drift.Value(outletId),
        shopName: cleanedShopName,
        shopAddress: drift.Value(
          cleanedAddress.isEmpty ? null : cleanedAddress,
        ),
        shopPhone: cleanedPhone.isEmpty
            ? const drift.Value.absent()
            : drift.Value(cleanedPhone),
        selfDeliveryActive: const drift.Value(false),
        deliveryRadiusKm: drift.Value(_deliveryRadiusKm),
        deliveryPickupLatitude: drift.Value(location.latitude),
        deliveryPickupLongitude: drift.Value(location.longitude),
        updatedAt: drift.Value(DateTime.now().toUtc()),
        synced: const drift.Value(false),
      ),
    );
  }

  String? _extractUnknownColumn(String message) {
    final match = RegExp(
      "Unknown column '([^']+)'",
      caseSensitive: false,
    ).firstMatch(message);
    return match?.group(1);
  }

  bool _shouldFallbackRegistration(DioException error) {
    final detail = _extractBackendDetail(error);
    if (detail == null) return false;
    final lower = detail.toLowerCase();
    return lower.contains('unknown column') ||
        lower.contains('sqlstate[42s22]');
  }

  String? _extractBackendDetail(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final text = data['error'] ?? data['message'] ?? data['msg'];
      return text?.toString();
    }
    return error.message;
  }

  bool _looksLikeAccountExists(String message) {
    final lower = message.toLowerCase();
    return lower.contains('already') ||
        lower.contains('exists') ||
        lower.contains('taken');
  }

  Future<bool> _fallbackRegistrationFlow() async {
    final postRegistrationPending = ref.read(
      postRegistrationWelcomePendingProvider.notifier,
    );
    postRegistrationPending.state = true;
    try {
      final name = _nameController.text.trim();
      final phone = _normalizePhone(_phoneController.text.trim());
      final pin = _pinController.text;
      final shopName = _shopNameController.text.trim();
      final address = _addressController.text.trim();
      final category = _selectedCategory;
      final location = _location!;

      debugPrint('[Registration] fallback to /v2/auth/signup');
      final authController = ref.read(authControllerProvider.notifier);
      await authController.register(name: name, phone: phone, pin: pin);

      var authState = ref.read(authControllerProvider);
      if (authState.status != AuthStatus.authenticated) {
        final message =
            authState.message ?? 'Registration failed. Please try again.';
        if (authState.status == AuthStatus.error &&
            _looksLikeAccountExists(message)) {
          debugPrint('[Registration] fallback to /v2/auth/login');
          await authController.login(emailOrPhone: phone, password: pin);
          authState = ref.read(authControllerProvider);
        }
      }

      if (authState.status != AuthStatus.authenticated) {
        postRegistrationPending.state = false;
        final message =
            authState.message ?? 'Registration failed. Please try again.';
        setState(() => _isLoading = false);
        _showError(message, title: 'Registration failed');
        return false;
      }

      await ref
          .read(businessSetupCompletedProvider.notifier)
          .markSetupRequired();

      final api = ref.read(sellerApiProvider);
      final shopPayload = _buildShopLocationPayload(
        shopName: shopName,
        address: address,
        category: category,
        location: location,
      );

      try {
        await api.updateProfile({'name': name});
      } catch (e) {
        debugPrint('[Registration] profile update failed: $e');
      }

      try {
        await api.updateShopInfo(shopPayload);
      } catch (e) {
        debugPrint('[Registration] shop update failed: $e');
      }

      await _seedLocalBusinessCache(
        registrationData: const <String, dynamic>{},
        sellerName: name,
        phone: phone,
        shopName: shopName,
        address: address,
        location: location,
      );

      _schedulePostRegistrationTasks(location: location, address: address);

      if (!mounted) {
        postRegistrationPending.state = false;
        return true;
      }
      setState(() => _isLoading = false);
      Haptics.impact();
      await _showPostRegistrationWelcome();
      return true;
    } catch (e) {
      debugPrint('[Registration] fallback failed: $e');
      postRegistrationPending.state = false;
      if (!mounted) return false;
      setState(() => _isLoading = false);
      _showError(
        'Registration failed. Please try again.',
        title: 'Registration failed',
      );
      return false;
    }
  }

  Map<String, dynamic> _buildShopLocationPayload({
    required String shopName,
    required String address,
    required String? category,
    required LatLng location,
  }) {
    return <String, dynamic>{
      'name': shopName,
      'shop_name': shopName,
      if (address.isNotEmpty) 'address': address,
      if (category != null) 'category': category,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'delivery_pickup_latitude': location.latitude,
      'delivery_pickup_longitude': location.longitude,
      'delivery_radius_km': _deliveryRadiusKm,
      'self_delivery_active': true,
    };
  }

  Future<void> _showPostRegistrationWelcome() async {
    if (!mounted) return;
    final choice = await showDialog<_PostRegistrationChoice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _PostRegistrationDialog(),
    );
    if (!mounted) return;

    final selectedChoice = choice ?? _PostRegistrationChoice.guidedSetup;
    ref.read(postRegistrationWelcomePendingProvider.notifier).state = false;

    // Log analytics event
    try {
      FirebaseAnalyticsService.instance.logCustomEvent(
        name: 'post_registration_choice',
        parameters: {
          'choice': selectedChoice.name,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('[Analytics] post_registration_choice failed: $e');
    }

    // Navigate with error handling
    try {
      switch (selectedChoice) {
        case _PostRegistrationChoice.products:
          context.go('/home/more/items');
          return;
        case _PostRegistrationChoice.services:
          context.go('/home/more/services');
          return;
        case _PostRegistrationChoice.guidedSetup:
          context.go('/home/more/business-setup');
          return;
        case _PostRegistrationChoice.checkout:
          context.go('/home/checkout');
          return;
      }
    } catch (e) {
      debugPrint('[Navigation] post_registration failed: $e');
      if (!mounted) return;
      // Fallback to checkout on navigation error
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to continue. Try again.'),
          duration: Duration(seconds: 2),
        ),
      );
      context.go('/home/checkout');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _mintAccentColor.withOpacity(0.18),
                boxShadow: [
                  BoxShadow(
                    color: _mintAccentColor.withOpacity(0.25),
                    blurRadius: 80,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildPersonalInfoStep(),
                      _buildShopInfoStep(),
                      _buildLocationStep(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 24,
              right: 24,
              child: _buildErrorSnack(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: _currentStep > 0
                ? _previousStep
                : () => context.go('/login'),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _currentStep > 0 ? Icons.arrow_back_ios_new : Icons.close,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Hero(
              tag: 'reg_title',
              child: Material(
                color: Colors.transparent,
                child: Text(
                  _getStepTitle(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
          _buildStepDots(),
        ],
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Account Details';
      case 1:
        return 'Business Profile';
      case 2:
        return 'Location';
      default:
        return '';
    }
  }

  Widget _buildStepDots() {
    return Row(
      children: List.generate(3, (index) {
        final isActive = index <= _currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(left: 6),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildErrorSnack() {
    final title = _errorTitle ?? 'Action needed';
    final message = _errorMessage ?? '';
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        final clamped = value.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, -20.0 * (1.0 - clamped)),
          child: Opacity(opacity: clamped, child: child),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.96),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _macBorderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _errorMessage = null;
                  _errorTitle = null;
                });
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _errorAccentColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_rounded,
                      color: _errorAccentColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: _macTextPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message,
                          style: TextStyle(
                            color: _macTextSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.close,
                    color: _macTextSecondary.withOpacity(0.8),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalInfoStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 20),
          const Text(
            'Let\'s get\nyou started.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w700,
              letterSpacing: -2,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 48),
          _PremiumTextField(
            label: 'Full Name',
            controller: _nameController,
            focusNode: _nameFocus,
            icon: Icons.person_rounded,
            autoFocus: true,
          ),
          const SizedBox(height: 24),
          _buildPhoneField(),
          const SizedBox(height: 24),
          const SizedBox(height: 24),
          _PremiumTextField(
            label: 'Create PIN (6 digits)',
            controller: _pinController,
            focusNode: _pinFocus,
            icon: Icons.pin_rounded,
            obscureText: _obscurePin,
            onToggleObscure: () => setState(() => _obscurePin = !_obscurePin),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
          ),
          const SizedBox(height: 24),
          _PremiumTextField(
            label: 'Confirm PIN',
            controller: _pinConfirmController,
            focusNode: _pinConfirmFocus,
            icon: Icons.pin_rounded,
            obscureText: _obscurePin,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
          ),
          const SizedBox(height: 48),
          _MainButton(text: 'Continue', onTap: _nextStep),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildShopInfoStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 20),
          const Text(
            'Tell us about\nyour business.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.w700,
              letterSpacing: -2,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 48),
          _PremiumTextField(
            label: 'Business Name',
            controller: _shopNameController,
            focusNode: _shopNameFocus,
            icon: Icons.store_rounded,
            autoFocus: true,
          ),
          const SizedBox(height: 24),
          _buildCategorySelector(),
          const SizedBox(height: 24),
          _buildPlanSelector(),
          const SizedBox(height: 24),
          CompositedTransformTarget(
            link: _addressLayerLink,
            child: _PremiumTextField(
              label: 'Address (Type to search)',
              controller: _addressController,
              focusNode: _addressFocus,
              icon: Icons.location_on_rounded,
              onChanged: _onAddressChanged,
              // Address Smartness
            ),
          ),

          const SizedBox(height: 48),
          _MainButton(text: 'Next Step', onTap: _nextStep),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    if (_checkingMaps)
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    return Stack(
      children: [
        Positioned.fill(
          child: _useGoogleMaps
              ? (_mapReady
                  ? _buildGoogleMap()
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ))
              : _buildFallbackMap(),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 160,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.85), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          top: 20,
          left: 24,
          right: 88,
          child: _buildLocationInfoCard(),
        ),
        Positioned(
          top: 20,
          right: 24,
          child: _GlassButton(
            icon: Icons.gps_fixed_rounded,
            isLoading: _isLoadingLocation,
            onTap: _getCurrentLocation,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  border: Border(
                    top: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildRadiusSlider(),
                    const SizedBox(height: 24),
                    _MainButton(
                      text: 'Create Account',
                      isLoading: _isLoading,
                      onTap: _location != null ? _handleSubmit : null,
                    ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanSelector() {
    if (_loadingPlans) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: const [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Loading Sanaa business plans…',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    if (_plans.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sanaa plan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Plans are temporarily unavailable. The default starter plan will be applied.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.72),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Choose your Sanaa plan',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ..._plans.map((plan) {
          final selected = _selectedPlan?.id == plan.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedPlan = plan),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: selected
                      ? _mintAccentColor.withOpacity(0.14)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: selected
                        ? _mintAccentColor
                        : Colors.white.withOpacity(0.08),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            plan.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            plan.priceLabel,
                            style: TextStyle(
                              color: selected ? _mintAccentColor : Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if ((plan.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        plan.description!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PlanTag(
                          'Products ${plan.limitLabel(plan.productLimit)}',
                        ),
                        _PlanTag(
                          'Services ${plan.limitLabel(plan.serviceLimit)}',
                        ),
                        _PlanTag('Staff ${plan.limitLabel(plan.staffLimit)}'),
                        if (plan.trialDays > 0)
                          _PlanTag('${plan.trialDays}-day trial'),
                        if (plan.posEnabled) const _PlanTag('POS'),
                        if (plan.analyticsEnabled) const _PlanTag('Analytics'),
                        if (plan.deliveryEnabled) const _PlanTag('Delivery'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGoogleMap() {
    return GoogleMap(
      style: _darkMapStyle,
      initialCameraPosition: CameraPosition(
        target: _location ?? const LatLng(0.3476, 32.5825),
        zoom: 15,
      ),
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
      },
      onMapCreated: (c) {
        debugPrint('[Map] GoogleMap created. hasLocation=${_location != null}');
        _mapController = c;
        final addressQuery = _addressController.text.trim();
        if (_location != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _updateLocationMap(_location!);
            _animateMapTo(_location!);
          });
        } else if (addressQuery.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _resolveAddressToLocation(addressQuery, force: true);
          });
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _getCurrentLocation();
          });
        }
      },
      onTap: _updateLocationMap,
      markers: _markers,
      circles: _circles,
      myLocationEnabled: _locationPermissionGranted && _locationServicesEnabled,
      myLocationButtonEnabled: false,
      scrollGesturesEnabled: true,
      zoomGesturesEnabled: true,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      zoomControlsEnabled: false,
    );
  }

  Widget _buildFallbackMap() {
    final center = _location != null
        ? latlong.LatLng(_location!.latitude, _location!.longitude)
        : const latlong.LatLng(0.3476, 32.5825);
    final List<fmap.Marker> markers = _location == null
        ? <fmap.Marker>[]
        : <fmap.Marker>[
            fmap.Marker(
              width: 40,
              height: 40,
              point: center,
              child: const Icon(
                Icons.location_on_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ];
    final List<fmap.CircleMarker> circles = _location == null
        ? <fmap.CircleMarker>[]
        : <fmap.CircleMarker>[
            fmap.CircleMarker(
              point: center,
              radius: _deliveryRadiusKm * 1000,
              useRadiusInMeter: true,
              color: _deliveryRadiusColor.withOpacity(0.2),
              borderStrokeWidth: 4,
              borderColor: _deliveryRadiusStrokeColor.withOpacity(0.95),
            ),
          ];

    return Stack(
      fit: StackFit.expand,
      children: [
        fmap.FlutterMap(
          mapController: _fallbackMapController,
          options: fmap.MapOptions(
            initialCenter: center,
            initialZoom: _fallbackZoom,
            onTap: (tapPosition, point) {
              _updateLocationMapWithOptions(
                LatLng(point.latitude, point.longitude),
                withHaptics: true,
              );
            },
            onPositionChanged: (position, hasGesture) {
              _fallbackZoom = position.zoom;
            },
            interactionOptions: const fmap.InteractionOptions(
              flags: fmap.InteractiveFlag.all & ~fmap.InteractiveFlag.rotate,
            ),
          ),
          children: [
            fmap.TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'soko_seller_terminal',
              errorTileCallback: (tile, error, stackTrace) {
                if (_fallbackTilesFailed) return;
                if (!mounted) return;
                setState(() => _fallbackTilesFailed = true);
              },
            ),
            fmap.CircleLayer(circles: circles),
            fmap.MarkerLayer(markers: markers),
          ],
        ),
        if (_fallbackTilesFailed)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Map tiles failed to load. Check your connection or use GPS.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        if (_location == null)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildGpsCard(),
            ),
          ),
      ],
    );
  }

  Widget _buildLocationInfoCard() {
    final address = _addressController.text.trim();
    final hasAddress = address.isNotEmpty;
    final hasLocation = _location != null;
    final title = hasAddress
        ? address
        : (_gpsLabel ?? 'Set your shop location');
    final subtitle = _isResolvingAddress
        ? 'Finding your address on the map...'
        : hasLocation
        ? (hasAddress
              ? 'Drag the pin or adjust the radius below.'
              : 'Pinned from GPS. Adjust the radius below.')
        : hasAddress
        ? 'Use address or GPS to drop a pin.'
        : 'Use GPS or go back to add an address.';

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasAddress)
                TextButton(
                  onPressed: _isResolvingAddress
                      ? null
                      : () => _resolveAddressToLocation(address, force: true),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  child: Text(hasLocation ? 'Recenter' : 'Use address'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGpsCard() {
    final hasLoc = _location != null;
    return GestureDetector(
      onTap: _getCurrentLocation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: hasLoc
              ? const Color(0xFF6C63FF).withOpacity(0.1)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: hasLoc
                ? const Color(0xFF6C63FF).withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hasLoc
                    ? const Color(0xFF6C63FF)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                hasLoc ? Icons.check_rounded : Icons.satellite_alt_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasLoc ? 'Location Secured' : 'Get GPS Location',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _gpsLabel ?? 'Tap to acquire coordinates',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
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

  Widget _buildRadiusSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Delivery Radius',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_deliveryRadiusKm.toStringAsFixed(0)} km',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFF6C63FF),
            inactiveTrackColor: Colors.white.withOpacity(0.1),
            thumbColor: Colors.white,
            overlayColor: const Color(0xFF6C63FF).withOpacity(0.2),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 10,
              pressedElevation: 8,
            ),
          ),
          child: Slider(
            value: _deliveryRadiusKm,
            min: 1,
            max: 50,
            divisions: 49,
            onChanged: (val) {
              setState(() => _deliveryRadiusKm = val);
              if (_location != null) {
                _updateLocationMapWithOptions(_location!, withHaptics: false);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              final s = await showCountryPickerBottomSheet(
                context,
                _selectedCountry,
              );
              if (s != null) setState(() => _selectedCountry = s);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    _selectedCountry.flag,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white.withOpacity(0.5),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 32, color: Colors.white.withOpacity(0.1)),
          Expanded(
            child: TextField(
              controller: _phoneController,
              focusNode: _phoneFocus,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: const Color(0xFF6C63FF),
              decoration: InputDecoration(
                hintText: '700 000 000',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                prefixText: '${_selectedCountry.code} ',
                prefixStyle: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 18,
                ),
                filled: false,
                fillColor: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySelector() {
    final cat = _selectedCategory;
    return GestureDetector(
      onTap: _showCategoryPicker,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cat != null
              ? const Color(0xFF6C63FF).withOpacity(0.1)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: cat != null
                ? const Color(0xFF6C63FF).withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              cat != null ? Icons.category_rounded : Icons.search_rounded,
              color: cat != null
                  ? const Color(0xFF6C63FF)
                  : Colors.white.withOpacity(0.5),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                cat ?? 'Search Categories',
                style: TextStyle(
                  color: cat != null
                      ? Colors.white
                      : Colors.white.withOpacity(0.5),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final IconData icon;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final bool autoFocus;
  final Function(String)? onChanged;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _PremiumTextField({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.icon,
    this.obscureText = false,
    this.onToggleObscure,
    this.autoFocus = false,
    this.onChanged,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  State<_PremiumTextField> createState() => _PremiumTextFieldState();
}

class _PremiumTextFieldState extends State<_PremiumTextField> {
  bool _isFocused = false;

  void _onFocusChange() {
    if (mounted) {
      setState(() => _isFocused = widget.focusNode.hasFocus);
    }
  }

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isFocused ? const Color(0xFF6C63FF) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        autofocus: widget.autoFocus,
        obscureText: widget.obscureText,
        onChanged: widget.onChanged,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: const Color(0xFF6C63FF),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: TextStyle(
            color: _isFocused
                ? const Color(0xFF6C63FF)
                : Colors.white.withOpacity(0.5),
          ),
          icon: Icon(
            widget.icon,
            color: _isFocused
                ? const Color(0xFF6C63FF)
                : Colors.white.withOpacity(0.3),
            size: 20,
          ),
          border: InputBorder.none,
          suffixIcon: widget.onToggleObscure != null
              ? IconButton(
                  icon: Icon(
                    widget.obscureText
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: Colors.white.withOpacity(0.3),
                    size: 20,
                  ),
                  onPressed: widget.onToggleObscure,
                )
              : null,
          filled: false,
          fillColor: Colors.transparent,
        ),
      ),
    );
  }
}

class _MainButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isLoading;
  const _MainButton({required this.text, this.onTap, this.isLoading = false});
  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null || isLoading;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 64,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: isDisabled
              ? null
              : const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF5A52D5)],
                ),
          color: isDisabled ? Colors.white.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isDisabled
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  text,
                  style: TextStyle(
                    color: isDisabled
                        ? Colors.white.withOpacity(0.3)
                        : Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;
  const _GlassButton({
    required this.icon,
    required this.onTap,
    this.isLoading = false,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(icon, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

enum _PostRegistrationChoice { checkout, products, services, guidedSetup }

class _PostRegistrationDialog extends StatefulWidget {
  const _PostRegistrationDialog();

  @override
  State<_PostRegistrationDialog> createState() =>
      _PostRegistrationDialogState();
}

class _PostRegistrationDialogState extends State<_PostRegistrationDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
    Haptics.warning();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Dialog(
          insetPadding: const EdgeInsets.all(20),
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 26,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFFFFF), Color(0xFFF5F6FA)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: _macBorderColor.withOpacity(0.8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _mintAccentColor.withOpacity(0.14),
                        border: Border.all(
                          color: _mintAccentColor.withOpacity(0.5),
                        ),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: _mintAccentColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Welcome',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _macTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Soko 24 Terminal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _macTextPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your account is ready. Choose where to begin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _macTextSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _WelcomeChoiceButton(
                      title: 'Add products',
                      subtitle: 'Items, inventory, menus',
                      icon: null,
                      isPrimary: true,
                      onTap: () {
                        Haptics.impact();
                        Navigator.of(
                          context,
                        ).pop(_PostRegistrationChoice.products);
                      },
                    ),
                    const SizedBox(height: 12),
                    _WelcomeChoiceButton(
                      title: 'Add services',
                      subtitle: 'Appointments and on-demand work',
                      icon: null,
                      isPrimary: false,
                      onTap: () {
                        Haptics.impact();
                        Navigator.of(
                          context,
                        ).pop(_PostRegistrationChoice.services);
                      },
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Need help getting started?',
                      style: TextStyle(
                        color: _macTextSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Semantics(
                      label: 'Show the guided setup',
                      hint:
                          'Opens a step-by-step setup wizard to help you get started',
                      button: true,
                      child: TextButton.icon(
                        onPressed: () {
                          Haptics.soft();
                          Navigator.of(
                            context,
                          ).pop(_PostRegistrationChoice.guidedSetup);
                        },
                        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: const Text(
                          'Start guided setup',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: _macTextSecondary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Semantics(
                      label: 'Continue to Checkout',
                      hint: 'Skip setup and go directly to checkout',
                      button: true,
                      child: GestureDetector(
                        onTap: () {
                          Haptics.soft();
                          Navigator.of(
                            context,
                          ).pop(_PostRegistrationChoice.checkout);
                        },
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          alignment: Alignment.center,
                          child: Text(
                            'Continue to Checkout →',
                            style: TextStyle(
                              color: _macTextSecondary.withOpacity(0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeChoiceButton extends StatelessWidget {
  const _WelcomeChoiceButton({
    required this.title,
    this.subtitle,
    this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isPrimary ? _mintAccentColor : Colors.white;
    final borderColor = isPrimary ? _mintAccentColor : _macBorderColor;
    final titleColor = isPrimary ? Colors.white : _macTextPrimary;
    final subtitleColor = isPrimary
        ? Colors.white.withOpacity(0.85)
        : _macTextSecondary;
    final iconBackground = isPrimary
        ? Colors.white.withOpacity(0.25)
        : const Color(0xFFF2F2F7);
    final iconColor = isPrimary ? Colors.white : _macTextPrimary;
    final arrowColor = isPrimary
        ? Colors.white.withOpacity(0.9)
        : _macTextSecondary;
    final hasIcon = icon != null;
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: isPrimary
                ? LinearGradient(
                    colors: [_mintAccentColor, const Color(0xFF3FB49F)],
                  )
                : null,
            color: isPrimary ? null : backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor.withOpacity(0.8)),
          ),
          child: Row(
            children: [
              if (hasIcon)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
              if (hasIcon) const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (hasSubtitle) const SizedBox(height: 4),
                    if (hasSubtitle)
                      Text(
                        subtitle!,
                        style: TextStyle(color: subtitleColor, fontSize: 12),
                      ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: arrowColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> categories;
  final String? selected;
  final Function(String) onSelect;
  const _CategoryPickerSheet({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });
  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final filtered = widget.categories
        .where(
          (c) =>
              c['name'].toString().toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF16161E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search Categories',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.white.withOpacity(0.3),
                ),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: filtered.length,
              separatorBuilder: (_, __) =>
                  Divider(color: Colors.white.withOpacity(0.05), height: 1),
              itemBuilder: (context, index) {
                final item = filtered[index];
                final isSelected = widget.selected == item['name'];
                return ListTile(
                  onTap: () => widget.onSelect(item['name']),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF6C63FF)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    item['name'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Color(0xFF6C63FF))
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationPlan {
  const _RegistrationPlan({
    required this.id,
    required this.name,
    required this.slug,
    required this.priceMonthly,
    required this.trialDays,
    required this.productLimit,
    required this.serviceLimit,
    required this.staffLimit,
    required this.posEnabled,
    required this.deliveryEnabled,
    required this.analyticsEnabled,
    required this.isActive,
    required this.sortOrder,
    this.description,
  });

  factory _RegistrationPlan.fromJson(Map<String, dynamic> json) {
    return _RegistrationPlan(
      id: _asInt(json['id']),
      name: (json['name'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      priceMonthly: _asDouble(json['price_monthly']),
      trialDays: _asInt(json['trial_days']),
      productLimit: _asInt(json['product_limit']),
      serviceLimit: _asInt(json['service_limit']),
      staffLimit: _asInt(json['staff_limit']),
      posEnabled: _asBool(json['pos_enabled']),
      deliveryEnabled: _asBool(json['delivery_enabled']),
      analyticsEnabled: _asBool(json['analytics_enabled']),
      isActive: !_hasExplicitFalse(json['is_active']),
      sortOrder: _asInt(json['sort_order']),
      description: json['description']?.toString(),
    );
  }

  final int id;
  final String name;
  final String slug;
  final double priceMonthly;
  final int trialDays;
  final int productLimit;
  final int serviceLimit;
  final int staffLimit;
  final bool posEnabled;
  final bool deliveryEnabled;
  final bool analyticsEnabled;
  final bool isActive;
  final int sortOrder;
  final String? description;

  String get priceLabel {
    if (trialDays > 0) {
      return '$trialDays-day free trial';
    }
    if (priceMonthly <= 0) {
      return 'Free';
    }
    return 'UGX ${_compactMoney(priceMonthly)}/mo';
  }

  String limitLabel(int value) {
    if (value < 0 || value == 0) return 'Unlimited';
    return value.toString();
  }
}

class _PlanTag extends StatelessWidget {
  const _PlanTag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.84),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

bool _asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == '1' || text == 'true' || text == 'yes';
}

bool _hasExplicitFalse(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value == false;
  if (value is num) return value == 0;
  final text = value.toString().trim().toLowerCase();
  return text == '0' || text == 'false' || text == 'no';
}

String _compactMoney(double value) {
  final rounded = value.round();
  final digits = rounded.toString().split('').reversed.toList();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && i % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString().split('').reversed.join();
}

const Color _mintAccentColor = Color(0xFF5CC7B5);
const Color _macBorderColor = Color(0xFFE2E3E7);
const Color _macTextPrimary = Color(0xFF1C1C1E);
const Color _macTextSecondary = Color(0xFF636366);
const Color _errorAccentColor = Color(0xFFE53935);
const Color _deliveryRadiusColor = Color(0xFFE53935);
const Color _deliveryRadiusStrokeColor = Color(0xFFFF6B6B);

const String _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#2c2c2c"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#212121"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]}
]
''';
