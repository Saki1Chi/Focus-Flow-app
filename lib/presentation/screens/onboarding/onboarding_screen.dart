import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/app_blocker_service.dart';
import '../../../services/installed_apps_service.dart';
import '../../providers/settings_provider.dart';
import '../../shell/app_shell.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  final _blocker = AppBlockerService();

  // Page 3 state
  List<InstalledApp> _installedApps = [];
  final Set<String> _selectedPackages = {};
  bool _loadingApps = false;
  bool _accessibilityEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkAccessibility();
  }

  Future<void> _checkAccessibility() async {
    final enabled = await _blocker.isAccessibilityEnabled();
    if (mounted) setState(() => _accessibilityEnabled = enabled);
  }

  Future<void> _loadApps() async {
    setState(() => _loadingApps = true);
    final apps = await InstalledAppsService.getInstalledApps();
    if (mounted) setState(() { _installedApps = apps; _loadingApps = false; });
  }

  @override
  Widget build(BuildContext context) {
    final accent = ref.watch(settingsProvider).accentColor;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) {
                  setState(() => _currentPage = i);
                  if (i == 2) _loadApps();
                },
                children: [
                  _buildPage1(accent),
                  _buildPage2(accent),
                  _buildPage3(accent),
                ],
              ),
            ),
            _buildIndicator(accent),
            _buildNavButtons(accent),
          ],
        ),
      ),
    );
  }

  Widget _buildPage1(Color accent) => _PageLayout(
    icon: Icons.track_changes_rounded,
    accent: accent,
    title: 'Stay Focused,\nGet Things Done',
    subtitle: 'FocusFlow helps you build deep work habits by organizing your tasks intelligently and blocking distractions until you earn a break.',
    extra: _modeCard(accent, 'Calendar Mode', 'Manually schedule tasks at specific times', Icons.calendar_month_rounded),
    extra2: _modeCard(accent, 'Smart Mode', 'Just add tasks and let FocusFlow schedule them for you', Icons.auto_awesome_rounded),
  );

  Widget _buildPage2(Color accent) => _PageLayout(
    icon: Icons.lock_rounded,
    accent: accent,
    title: 'App Blocker',
    subtitle: 'FocusFlow can block distracting apps while you have pending tasks. Complete 3 task blocks to earn a break and unlock them.',
    extra: _permissionCard(
      accent: accent,
      icon: Icons.accessibility_new_rounded,
      title: 'Accessibility Service',
      subtitle: _accessibilityEnabled
          ? 'Enabled — app blocking is ready!'
          : 'Required to detect and block apps',
      enabled: _accessibilityEnabled,
      onTap: () async {
        await _blocker.openAccessibilitySettings();
        await Future.delayed(const Duration(seconds: 2));
        await _checkAccessibility();
      },
    ),
  );

  Widget _buildPage3(Color accent) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Icon(Icons.apps_rounded, size: 48, color: accent),
          const SizedBox(height: 16),
          Text('Select Apps to Block', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('Choose which apps you want FocusFlow to block during focus sessions.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          Expanded(
            child: _loadingApps
                ? Center(child: CircularProgressIndicator(color: accent))
                : ListView.builder(
                    itemCount: _installedApps.length,
                    itemBuilder: (ctx, i) {
                      final app = _installedApps[i];
                      final selected = _selectedPackages.contains(app.packageName);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (v) => setState(() {
                          if (v == true) _selectedPackages.add(app.packageName);
                          else _selectedPackages.remove(app.packageName);
                        }),
                        title: Text(app.appName, style: const TextStyle(fontSize: 14)),
                        subtitle: Text(app.packageName,
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                        secondary: const CircleAvatar(child: Icon(Icons.android_rounded, size: 18)),
                        activeColor: accent,
                        controlAffinity: ListTileControlAffinity.trailing,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _modeCard(Color accent, String title, String desc, IconData icon) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: accent.withValues(alpha: 0.2)),
    ),
    child: Row(children: [
      Icon(icon, color: accent, size: 28),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ])),
    ]),
  );

  Widget _permissionCard({
    required Color accent,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: enabled ? null : onTap,
    child: Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: enabled ? Colors.green.withValues(alpha: 0.08) : accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: enabled ? Colors.green.withValues(alpha: 0.3) : accent.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: enabled ? Colors.green : accent, size: 28),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 12, color: enabled ? Colors.green : Colors.grey)),
        ])),
        if (!enabled) Icon(Icons.arrow_forward_ios_rounded, size: 14, color: accent),
        if (enabled) const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
      ]),
    ),
  );

  Widget _buildIndicator(Color accent) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: _currentPage == i ? 24 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: _currentPage == i ? accent : accent.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
        ),
      )),
    ),
  );

  Widget _buildNavButtons(Color accent) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    child: Row(
      children: [
        if (_currentPage > 0)
          TextButton(
            onPressed: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
            child: const Text('Back'),
          ),
        const Spacer(),
        ElevatedButton(
          onPressed: _currentPage < 2
              ? () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
              : _finish,
          child: Text(_currentPage < 2 ? 'Next' : 'Get Started'),
        ),
      ],
    ),
  );

  Future<void> _finish() async {
    final notifier = ref.read(settingsProvider.notifier);
    await notifier.setBlockedApps(_selectedPackages.toList());
    await notifier.setOnboardingDone(true);

    final blocker = AppBlockerService();
    await blocker.setBlockedApps(_selectedPackages.toList());
    await blocker.enableBlocking();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    }
  }
}

class _PageLayout extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final Widget? extra;
  final Widget? extra2;

  const _PageLayout({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    this.extra,
    this.extra2,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Icon(icon, size: 52, color: accent),
        const SizedBox(height: 20),
        Text(title, style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 12),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 28),
        if (extra != null) extra!,
        if (extra2 != null) extra2!,
      ],
    ),
  );
}
