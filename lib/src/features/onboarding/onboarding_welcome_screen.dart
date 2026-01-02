import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_providers.dart';
import '../../core/onboarding/onboarding_controller.dart';
import '../../core/sync/sync_service.dart';

class OnboardingWelcomeScreen extends ConsumerStatefulWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  ConsumerState<OnboardingWelcomeScreen> createState() => _OnboardingWelcomeScreenState();
}

class _OnboardingWelcomeScreenState extends ConsumerState<OnboardingWelcomeScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              
              // Success Icon
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 64,
                ),
              ),
              const SizedBox(height: 32),
              
              const Text(
                'Your Shop is Ready!',
               textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                'Start selling and growing your business',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 48),
              
              // Quick Tips
              _buildTipCard(
                icon: Icons.inventory_2_outlined,
                title: 'Add Your First Product',
                subtitle: 'Start building your catalog',
                color: const Color(0xFF2196F3),
              ),
              const SizedBox(height: 16),
              
              _buildTipCard(
                icon: Icons.point_of_sale_outlined,
                title: 'Make Your First Sale',
                subtitle: 'Use the POS to sell in-store',
                color: const Color(0xFFFF9800),
              ),
              const SizedBox(height: 16),
              
              _buildTipCard(
                icon: Icons.analytics_outlined,
                title: 'Track Your Performance',
                subtitle: 'Monitor sales and inventory',
                color: const Color(0xFF9C27B0),
              ),
              const Spacer(),
              
              // Go to Dashboard Button
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
                  onPressed: _isLoading ? null : _handleGoToDashboard,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Go to Dashboard',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleGoToDashboard() async {
    setState(() => _isLoading = true);
    
    try {
      // Save shop data to backend
      final onboarding = ref.read(onboardingControllerProvider);
      if (onboarding.shopData.isNotEmpty) {
        final api = ref.read(sellerApiProvider);
        await api.updateShopInfo(onboarding.shopData);
      }
      
      // Mark onboarding as complete
      await ref.read(onboardingControllerProvider.notifier).completeOnboarding();
      
      // Start sync service
      ref.read(syncServiceProvider).start();
      
      if (!mounted) return;
      
      // Navigate to dashboard
      context.go('/home/checkout');
    } catch (e) {
      if (!mounted) return;
      
      // Show error but allow proceeding
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save all details: $e'),
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
        setState(() => _isLoading = false);
      }
    }
  }
}
