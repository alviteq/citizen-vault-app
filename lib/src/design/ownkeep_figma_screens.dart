import 'package:citizen_vault_app/src/design/ownkeep_theme.dart';
import 'package:flutter/material.dart';

/// Flutter implementation of the 5 Figma UIs for OwnKeep (Mobile & Desktop).
abstract final class OwnKeepFigmaScreens {
  /// Renders a responsive preview switcher containing all 5 screens.
  static Widget buildPreviewShell({required BuildContext context}) {
    return const _OwnKeepFigmaPreviewShell();
  }
}

class _OwnKeepFigmaPreviewShell extends StatefulWidget {
  const _OwnKeepFigmaPreviewShell();

  @override
  State<_OwnKeepFigmaPreviewShell> createState() =>
      __OwnKeepFigmaPreviewShellState();
}

class __OwnKeepFigmaPreviewShellState extends State<_OwnKeepFigmaPreviewShell> {
  int _selectedScreenIndex = 0;
  bool _isDesktopView = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _isDesktopView = size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFF060A17),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1023),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: OwnKeepTheme.blue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'OwnKeep',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Keep What Matters. Own Your Data.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ToggleButtons(
              isSelected: [
                _selectedScreenIndex == 0,
                _selectedScreenIndex == 1,
                _selectedScreenIndex == 2,
                _selectedScreenIndex == 3,
                _selectedScreenIndex == 4,
              ],
              onPressed: (index) {
                setState(() => _selectedScreenIndex = index);
              },
              borderRadius: BorderRadius.circular(10),
              fillColor: OwnKeepTheme.blue,
              selectedColor: Colors.white,
              color: const Color(0xFF94A3B8),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('1. Splash'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('2. Onboard'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('3. Vault'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('4. Lock'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('5. Dash'),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: _isDesktopView ? 1200 : 380,
            maxHeight: _isDesktopView ? 800 : 750,
          ),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF080D1E),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0xFF1E2942), width: 3),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 30,
                offset: Offset(0, 15),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildSelectedScreen(),
        ),
      ),
    );
  }

  Widget _buildSelectedScreen() {
    switch (_selectedScreenIndex) {
      case 0:
        return const OwnKeepFigmaSplashScreen();
      case 1:
        return const OwnKeepFigmaOnboardingScreen();
      case 2:
        return const OwnKeepFigmaCreateVaultScreen();
      case 3:
        return const OwnKeepFigmaLockScreen();
      case 4:
      default:
        return OwnKeepFigmaDashboardScreen(isDesktop: _isDesktopView);
    }
  }
}

/// ---------------------------------------------------------------------------
/// SCREEN 1: SPLASH SCREEN
/// ---------------------------------------------------------------------------
class OwnKeepFigmaSplashScreen extends StatelessWidget {
  const OwnKeepFigmaSplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.3),
          radius: 0.9,
          colors: [Color(0xFF0F1C3F), Color(0xFF060B18)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Status Bar Simulation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    '9:41',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text('📶 🔋', style: TextStyle(color: Colors.white)),
                ],
              ),

              // Hero Shield
              Column(
                children: [
                  Container(
                    width: 110,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1329),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: OwnKeepTheme.blue, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: OwnKeepTheme.blue.withOpacity(0.5),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: OwnKeepTheme.blue,
                      size: 56,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'OwnKeep',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Keep What Matters.\nOwn Your Data.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  ),
                ],
              ),

              // Bottom Loading & Tags
              Column(
                children: [
                  const SizedBox(
                    width: 80,
                    child: LinearProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        OwnKeepTheme.blue,
                      ),
                      backgroundColor: Color(0x22FFFFFF),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '100% Private  •  Encrypted  •  Offline First',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// SCREEN 2: ONBOARDING
/// ---------------------------------------------------------------------------
class OwnKeepFigmaOnboardingScreen extends StatelessWidget {
  const OwnKeepFigmaOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF080D1E),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.topRight,
            child: TextButton(
              onPressed: () {},
              child: const Text(
                'Skip',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.25,
              ),
              children: [
                TextSpan(text: 'Your life,\norganized and\nalways '),
                TextSpan(
                  text: 'secure.',
                  style: TextStyle(color: Color(0xFF10B981)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'OwnKeep helps you store, organize and protect what matters most to you.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
          Expanded(
            child: Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2A52),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: OwnKeepTheme.blue, strokeAlign: 1),
                  boxShadow: [
                    BoxShadow(
                      color: OwnKeepTheme.blue.withOpacity(0.3),
                      blurRadius: 25,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.vpn_key_rounded,
                  color: OwnKeepTheme.blue,
                  size: 64,
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == 0 ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color:
                      i == 0 ? OwnKeepTheme.blue : const Color(0x33FFFFFF),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: OwnKeepTheme.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {},
              child: const Text(
                'Next →',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// SCREEN 3: CREATE VAULT
/// ---------------------------------------------------------------------------
class OwnKeepFigmaCreateVaultScreen extends StatefulWidget {
  const OwnKeepFigmaCreateVaultScreen({super.key});

  @override
  State<OwnKeepFigmaCreateVaultScreen> createState() =>
      _OwnKeepFigmaCreateVaultScreenState();
}

class _OwnKeepFigmaCreateVaultScreenState
    extends State<OwnKeepFigmaCreateVaultScreen> {
  bool _biometrics = true;
  int _selectedColorIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF080D1E),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          const SizedBox(height: 16),
          const Text(
            'Create Your Vault',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your vault is encrypted and stored only on your device.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 24),
          const Text(
            'Vault Name',
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            initialValue: 'My Personal Vault',
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF111A33),
              suffixIcon: const Icon(
                Icons.lock_outline,
                color: Color(0xFF64748B),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1E2942)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Choose a Theme Color',
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _colorDot(0, const Color(0xFF3B82F6)),
              _colorDot(1, const Color(0xFF8B5CF6)),
              _colorDot(2, const Color(0xFF06B6D4)),
              _colorDot(3, const Color(0xFFF97316)),
              _colorDot(4, const Color(0xFFEC4899)),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Security',
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _securityCard(
            icon: Icons.fingerprint,
            title: 'Biometric Unlock',
            subtitle: 'Use fingerprint or face to unlock',
            trailing: Switch(
              value: _biometrics,
              onChanged: (v) => setState(() => _biometrics = v),
              activeColor: OwnKeepTheme.blue,
            ),
          ),
          const SizedBox(height: 8),
          _securityCard(
            icon: Icons.key,
            title: 'PIN Protection',
            subtitle: 'Add a 6-digit PIN for extra security',
            trailing: const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF64748B),
              size: 14,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: OwnKeepTheme.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.lock_rounded, color: Colors.white),
              label: const Text(
                'Create Vault',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _colorDot(int index, Color color) {
    final selected = _selectedColorIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedColorIndex = index),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 16)
            : null,
      ),
    );
  }

  Widget _securityCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xB3111A33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x10FFFFFF)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF93C5FD), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// SCREEN 4: LOCK SCREEN
/// ---------------------------------------------------------------------------
class OwnKeepFigmaLockScreen extends StatelessWidget {
  const OwnKeepFigmaLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E1B4B), Color(0xFF0F172A), Color(0xFF080D1E)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: const [
                  Icon(Icons.lock_rounded, color: Color(0xFF93C5FD), size: 20),
                  SizedBox(height: 8),
                  Text(
                    'Good Evening, Arjun 👋',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Welcome back to your vault',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ],
              ),

              // Biometric Fingerprint Trigger
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: OwnKeepTheme.blue.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: OwnKeepTheme.blue, width: 2),
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  color: OwnKeepTheme.blue,
                  size: 40,
                ),
              ),

              // Keypad
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                childAspectRatio: 1.5,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  for (var i = 1; i <= 9; i++) _keyBtn('$i'),
                  _keyBtn('🖐'),
                  _keyBtn('0'),
                  _keyBtn('⌫'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _keyBtn(String val) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      alignment: Alignment.center,
      child: Text(
        val,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// SCREEN 5: HOME DASHBOARD (MOBILE & DESKTOP DUAL-PANE)
/// ---------------------------------------------------------------------------
class OwnKeepFigmaDashboardScreen extends StatelessWidget {
  const OwnKeepFigmaDashboardScreen({required this.isDesktop, super.key});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return Row(
        children: [
          // Navigation Rail Sidebar for Desktop
          NavigationRail(
            backgroundColor: const Color(0xFF060A17),
            selectedIndex: 0,
            labelType: NavigationRailLabelType.all,
            unselectedIconTheme: const IconThemeData(color: Color(0xFF64748B)),
            selectedIconTheme: const IconThemeData(color: OwnKeepTheme.blue),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_rounded),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.folder_rounded),
                label: Text('Collections'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.shield_rounded),
                label: Text('Vault'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_rounded),
                label: Text('Settings'),
              ),
            ],
          ),
          const VerticalDivider(width: 1, color: Color(0xFF1E2942)),
          Expanded(child: _buildDashboardContent(context)),
        ],
      );
    }

    return _buildDashboardContent(context);
  }

  Widget _buildDashboardContent(BuildContext context) {
    return Container(
      color: const Color(0xFF080D1E),
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.menu_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Good Evening, Arjun 👋',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Everything is safe and organized',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.search_rounded, color: Colors.white),
              const SizedBox(width: 12),
              const Icon(Icons.notifications_none_rounded, color: Colors.white),
            ],
          ),
          const SizedBox(height: 16),

          // Search Box
          TextField(
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search anything...',
              hintStyle: const TextStyle(color: Color(0xFF64748B)),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF64748B),
              ),
              filled: true,
              fillColor: const Color(0xFF111A33),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Quick Action Cards
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _quickAction('Scan', Icons.qr_code_scanner, const Color(0xFF2563EB)),
              _quickAction('Add New', Icons.add_rounded, const Color(0xFF059669)),
              _quickAction('AI Assistant', Icons.auto_awesome, const Color(0xFF7C3AED)),
              _quickAction('Quick Note', Icons.edit_note, const Color(0xFFEA580C)),
            ],
          ),
          const SizedBox(height: 20),

          // Recent Items
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Recent Items',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'View All',
                style: TextStyle(color: OwnKeepTheme.blue, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _recentItem(
                  'Passport',
                  'Today',
                  Icons.picture_as_pdf,
                  const Color(0xFFEF4444),
                ),
                _recentItem(
                  'Insurance',
                  'Yesterday',
                  Icons.description,
                  const Color(0xFF3B82F6),
                ),
                _recentItem(
                  'License',
                  '2 days ago',
                  Icons.badge,
                  const Color(0xFF10B981),
                ),
                _recentItem(
                  'Aadhaar',
                  '3 days ago',
                  Icons.credit_card,
                  const Color(0xFF06B6D4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Smart Collections
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Smart Collections',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'View All',
                style: TextStyle(color: OwnKeepTheme.blue, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2.8,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              _collectionCard(
                'Personal',
                '28 items',
                Icons.person,
                const Color(0xFF3B82F6),
              ),
              _collectionCard(
                'Finance',
                '16 items',
                Icons.account_balance_wallet,
                const Color(0xFF10B981),
              ),
              _collectionCard(
                'Health',
                '12 items',
                Icons.favorite,
                const Color(0xFFEC4899),
              ),
              _collectionCard(
                'Property',
                '9 items',
                Icons.home,
                const Color(0xFFF97316),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Today's Reminder Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: OwnKeepTheme.blue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: OwnKeepTheme.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.calendar_today_rounded,
                  color: OwnKeepTheme.blue,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Reminder",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        'Vehicle Insurance expires in 15 days',
                        style: TextStyle(
                          color: Color(0xFF93C5FD),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF93C5FD),
                  size: 14,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Storage Overview Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xB3111A33),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Storage Overview',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                    Text(
                      '2.4 GB of 10 GB used (24%)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const LinearProgressIndicator(
                  value: 0.24,
                  valueColor: AlwaysStoppedAnimation<Color>(OwnKeepTheme.blue),
                  backgroundColor: Color(0x22FFFFFF),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction(String label, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
        ),
      ],
    );
  }

  Widget _recentItem(
    String title,
    String time,
    IconData icon,
    Color accentColor,
  ) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xB3111A33),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accentColor, size: 20),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            time,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _collectionCard(
    String title,
    String count,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xB3111A33),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                count,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
