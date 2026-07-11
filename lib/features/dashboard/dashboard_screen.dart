import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <DashboardItem>[
      const DashboardItem(
        title: 'Referral Link',
        icon: Icons.link_rounded,
        route: '/referral-link',
      ),
      const DashboardItem(
        title: 'Referrals',
        icon: Icons.group_rounded,
        route: '/referrals',
      ),
      const DashboardItem(
        title: 'Messages',
        icon: Icons.mail_outline_rounded,
        route: '/messages',
      ),
      const DashboardItem(
        title: 'Profile',
        icon: Icons.person_outline_rounded,
        route: '/profile',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goouts'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Driver Dashboard',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'This is your first starter screen. We will connect real data later.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];

                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => context.go(item.route),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: const Color(0xFFE8F0FE),
                              child: Icon(
                                item.icon,
                                size: 28,
                                color: const Color(0xFF1A73E8),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              item.title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardItem {
  final String title;
  final IconData icon;
  final String route;

  const DashboardItem({
    required this.title,
    required this.icon,
    required this.route,
  });
}