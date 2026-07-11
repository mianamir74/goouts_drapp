import 'package:flutter/material.dart';

import 'driver_dashboard_screen.dart';
import 'earnings_screen.dart';
import 'order_history_screen.dart';
import 'profile_settings_screen.dart';
import 'support_training_screen.dart';

class MainDeliveryScaffold extends StatefulWidget {
  const MainDeliveryScaffold({super.key});

  @override
  State<MainDeliveryScaffold> createState() => _MainDeliveryScaffoldState();
}

class _MainDeliveryScaffoldState extends State<MainDeliveryScaffold> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DriverDashboardScreen(),
    OrderHistoryScreen(),
    EarningsScreen(),
    SupportTrainingScreen(),
    ProfileSettingsScreen(),
  ];

  static const _navItems = [
    _NavItem(icon: Icons.home_outlined,       activeIcon: Icons.home,         label: 'Home'),
    _NavItem(icon: Icons.receipt_long_outlined,activeIcon: Icons.receipt_long, label: 'Orders'),
    _NavItem(icon: Icons.payments_outlined,   activeIcon: Icons.payments,     label: 'Earnings'),
    _NavItem(icon: Icons.support_agent_outlined,activeIcon: Icons.support_agent,label: 'Support'),
    _NavItem(icon: Icons.person_outline,      activeIcon: Icons.person,       label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF031134),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0b1a3d),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _navItems.asMap().entries.map((e) {
                final i      = e.key;
                final item   = e.value;
                final active = _currentIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => _currentIndex = i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFFf97316)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          active ? item.activeIcon : item.icon,
                          color: active ? Colors.white : Colors.white38,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: active ? Colors.white : Colors.white38,
                          fontWeight: active
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
