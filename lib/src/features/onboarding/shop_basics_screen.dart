import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/onboarding/onboarding_controller.dart';

class ShopBasicsScreen extends ConsumerStatefulWidget {
  const ShopBasicsScreen({super.key});

  @override
  ConsumerState<ShopBasicsScreen> createState() => _ShopBasicsScreenState();
}

class _ShopBasicsScreenState extends ConsumerState<ShopBasicsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String? _selectedCategory;
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
    _descriptionController.dispose();
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
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => context.go('/login'),
        ),
        title: const Text(
          'Setup Your Shop',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            _buildProgressIndicator(2, 5),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Shop Basics',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tell us about your business',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 32),
                      
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
                      const SizedBox(height: 16),
                      
                      // Category Dropdown
                      _buildCategoryDropdown(),
                      const SizedBox(height: 16),
                      
                      // Description (Optional)
                      _buildModernField(
                        controller: _descriptionController,
                        label: 'Shop Description (Optional)',
                        icon: Icons.description_outlined,
                        hint: 'What do you sell?',
                        maxLines: 3,
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
                      
                      // Skip Button
                      TextButton(
                        onPressed: _handleSkip,
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
    final name = data['name']?.toString();
    if (_shopNameController.text.isEmpty && name != null && name.isNotEmpty) {
      _shopNameController.text = name;
    }

    final description = data['meta_description']?.toString();
    if (_descriptionController.text.isEmpty &&
        description != null &&
        description.isNotEmpty) {
      _descriptionController.text = description;
    }

    final category = data['category']?.toString();
    if (_selectedCategory == null &&
        category != null &&
        category.isNotEmpty &&
        _categories.contains(category)) {
      _selectedCategory = category;
      changed = true;
    }

    if (changed && notify && mounted) {
      setState(() {});
    }
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
          labelText: 'Category',
          floatingLabelStyle: TextStyle(color: Colors.grey[800]),
          labelStyle: TextStyle(color: Colors.grey[500]),
        ),
        items: _categories.map((category) {
          return DropdownMenuItem(
            value: category,
            child: Text(category),
          );
        }).toList(),
        onChanged: (value) {
          setState(() => _selectedCategory = value);
        },
        validator: (value) {
          if (value == null) {
            return 'Please select a category';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildModernField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
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

  void _handleContinue() {
    if (!_formKey.currentState!.validate()) return;
    
    // Save data to onboarding state
    final controller = ref.read(onboardingControllerProvider.notifier);
    controller.updateShopData({
      'name': _shopNameController.text.trim(),
      'meta_description': _descriptionController.text.trim(),
      'category': _selectedCategory,
    });
    controller.goToStage(3);
    
    // Navigate to next stage
    context.go('/onboarding/business-details');
  }

  void _handleSkip() {
    // For hybrid approach, shop basics is mandatory
    // Show dialog explaining it's required
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shop Name Required'),
        content: const Text(
          'We need at least your shop name to set up your account. This helps customers find and trust your business.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
