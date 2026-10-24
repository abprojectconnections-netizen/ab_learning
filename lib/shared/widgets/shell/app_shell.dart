import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/role_guard.dart';
import '../../../core/router/route_paths.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../features/auth/presentation/providers/auth_providers.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String path;

  const _NavItem(
    this.label,
    this.icon,
    this.activeIcon,
    this.path,
  );
}

const _logout = '__logout';

List<_NavItem> _itemsFor(UserRole role) => switch (role) {
      UserRole.guest => const [
          _NavItem(
            'หน้าแรก',
            Icons.home_outlined,
            Icons.home_rounded,
            RoutePaths.home,
          ),
          _NavItem(
            'ค้นหา',
            Icons.search_outlined,
            Icons.search_rounded,
            RoutePaths.search,
          ),
          _NavItem(
            'ตรวจใบประกาศ',
            Icons.verified_outlined,
            Icons.verified_rounded,
            RoutePaths.certificateVerify,
          ),
          _NavItem(
            'เข้าสู่ระบบ',
            Icons.login_outlined,
            Icons.login_rounded,
            RoutePaths.login,
          ),
        ],
      UserRole.learner => const [
          _NavItem(
            'หน้าแรก',
            Icons.home_outlined,
            Icons.home_rounded,
            RoutePaths.home,
          ),
          _NavItem(
            'ค้นหา',
            Icons.search_outlined,
            Icons.search_rounded,
            RoutePaths.search,
          ),
          _NavItem(
            'การเรียน',
            Icons.school_outlined,
            Icons.school_rounded,
            RoutePaths.progress,
          ),
          _NavItem(
            'ใบประกาศ',
            Icons.workspace_premium_outlined,
            Icons.workspace_premium,
            RoutePaths.myCertificates,
          ),
          _NavItem(
            'โปรไฟล์',
            Icons.person_outline,
            Icons.person_rounded,
            RoutePaths.profile,
          ),
          _NavItem(
            'ออกจากระบบ',
            Icons.logout_outlined,
            Icons.logout_rounded,
            _logout,
          ),
        ],
      UserRole.corporateAdmin => const [
          _NavItem('Organization', Icons.dashboard_outlined,
              Icons.dashboard_rounded, RoutePaths.corporateDashboard),
          _NavItem('Marketplace', Icons.storefront_outlined,
              Icons.storefront_rounded, RoutePaths.home),
          _NavItem(
              'Sign out', Icons.logout_outlined, Icons.logout_rounded, _logout),
        ],
      UserRole.corporateManager => const [
          _NavItem('My team', Icons.dashboard_outlined, Icons.dashboard_rounded,
              RoutePaths.corporateDashboard),
          _NavItem('Marketplace', Icons.storefront_outlined,
              Icons.storefront_rounded, RoutePaths.home),
          _NavItem(
              'Sign out', Icons.logout_outlined, Icons.logout_rounded, _logout),
        ],
      UserRole.employer => const [
          _NavItem('Recruitment', Icons.dashboard_outlined,
              Icons.dashboard_rounded, RoutePaths.employerDashboard),
          _NavItem('Marketplace', Icons.storefront_outlined,
              Icons.storefront_rounded, RoutePaths.home),
          _NavItem(
              'Sign out', Icons.logout_outlined, Icons.logout_rounded, _logout),
        ],
      UserRole.admin => const [
          _NavItem('Administration', Icons.admin_panel_settings_outlined,
              Icons.admin_panel_settings_rounded, RoutePaths.adminDashboard),
          _NavItem('Marketplace', Icons.storefront_outlined,
              Icons.storefront_rounded, RoutePaths.home),
          _NavItem(
              'Sign out', Icons.logout_outlined, Icons.logout_rounded, _logout),
        ],
      UserRole.superAdmin => const [
          _NavItem('Super Admin', Icons.security_outlined,
              Icons.security_rounded, RoutePaths.superAdminDashboard),
          _NavItem(
              'Sign out', Icons.logout_outlined, Icons.logout_rounded, _logout),
        ],
      UserRole.instructor => const [
          _NavItem(
            'แดชบอร์ด',
            Icons.dashboard_outlined,
            Icons.dashboard_rounded,
            RoutePaths.instructorDashboard,
          ),
          _NavItem(
            'สร้างคอร์ส',
            Icons.add_box_outlined,
            Icons.add_box_rounded,
            RoutePaths.courseCreate,
          ),
          _NavItem(
            'ยอดขาย',
            Icons.bar_chart_outlined,
            Icons.bar_chart_rounded,
            RoutePaths.salesDashboard,
          ),
          _NavItem(
            'รายได้',
            Icons.account_balance_wallet_outlined,
            Icons.account_balance_wallet_rounded,
            RoutePaths.revenueBalance,
          ),
          _NavItem(
            'หน้าแรก',
            Icons.storefront_outlined,
            Icons.storefront_rounded,
            RoutePaths.home,
          ),
          _NavItem(
            'ออกจากระบบ',
            Icons.logout_outlined,
            Icons.logout_rounded,
            _logout,
          ),
        ],
    };

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authStateProvider).role;
    final items = _itemsFor(role);
    final location = GoRouterState.of(context).uri.path;

    int? selected;
    var bestLen = -1;

    for (var i = 0; i < items.length; i++) {
      final path = items[i].path;

      final matches = path == RoutePaths.home
          ? location == path
          : location.startsWith(path);

      if (matches && path.length > bestLen) {
        selected = i;
        bestLen = path.length;
      }
    }

    void onSelect(int index) {
      final path = items[index].path;

      if (path == _logout) {
        ref.read(authRepositoryProvider).signOut();
        context.go(RoutePaths.home);
        return;
      }

      context.go(path);
    }

    final width = MediaQuery.sizeOf(context).width;

    // Desktop และ Tablet
    if (width >= 600) {
      final extended = width >= 1024;

      return Scaffold(
        backgroundColor: AppColors.gray50,
        body: Row(
          children: [
            Container(
              width: extended ? 260 : 80,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(
                    color: AppColors.gray200,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: extended ? 24 : 16,
                      vertical: 24,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        if (extended) ...[
                          const SizedBox(width: 12),
                          Text(
                            'AB Learning',
                            style: AppTextStyles.h3.copyWith(
                              color: AppColors.gray900,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(
                    height: 1,
                    color: AppColors.gray200,
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 12,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isSelected = selected == index;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => onSelect(index),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: extended ? 16 : 12,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: extended
                                      ? MainAxisAlignment.start
                                      : MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isSelected ? item.activeIcon : item.icon,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.gray600,
                                      size: 22,
                                    ),
                                    if (extended) ...[
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          item.label,
                                          style:
                                              AppTextStyles.bodyMedium.copyWith(
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.gray700,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
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
            Expanded(child: child),
          ],
        ),
      );
    }

    // Mobile
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected ?? 0,
        onDestinationSelected: onSelect,
        destinations: items
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.activeIcon),
                label: item.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
