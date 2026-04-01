// lib/widgets/main_container.dart
import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/transaction_passbook_screen.dart';
import '../screens/profile_screen.dart';

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _selectedIndex = 0;

  // Track which pages have been visited to avoid initializing all at once
  final Set<int> _initializedPages = {0};

  // GlobalKey to access HomeScreen's state for refreshing data
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();
  // GlobalKey to access TransactionPassbookScreen's state for refreshing data
  final GlobalKey<TransactionPassbookScreenState> _passbookKey = GlobalKey<TransactionPassbookScreenState>();

  void _switchTab(int index) {
    setState(() {
      _selectedIndex = index;
      _initializedPages.add(index);
    });
    if (index == 0) {
      _homeKey.currentState?.refreshData();
    } else if (index == 1) {
      _passbookKey.currentState?.refreshData();
    }
  }

  late final List<Widget> _pages = [
    HomeScreen(key: _homeKey),
    TransactionPassbookScreen(key: _passbookKey, onTabSwitch: _switchTab),
    ProfileScreen(onTabSwitch: _switchTab),
  ];

  @override
  Widget build(BuildContext context) {
    // Mark current page as initialized
    _initializedPages.add(_selectedIndex);

    // Map display order (History=0, Home=1, Profile=2) to internal order (Home=0, History=1, Profile=2)
    final displayToInternal = [1, 0, 2]; // Display idx -> Internal idx
    final internalToDisplay = [1, 0, 2]; // Internal idx -> Display idx
    final displayIndex = internalToDisplay[_selectedIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFEEF2FF),
      body: IndexedStack(
        index: _selectedIndex,
        children: List.generate(_pages.length, (index) {
          if (_initializedPages.contains(index)) {
            return _pages[index];
          }
          return const SizedBox.shrink();
        }),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // History tab
                _buildNavItem(
                  icon: Icons.history,
                  label: 'History',
                  isSelected: displayIndex == 0,
                  onTap: () {
                    final internal = displayToInternal[0];
                    setState(() => _selectedIndex = internal);
                    _passbookKey.currentState?.refreshData();
                  },
                ),
                // Home tab - elevated circle
                GestureDetector(
                  onTap: () {
                    final internal = displayToInternal[1];
                    setState(() => _selectedIndex = internal);
                    _homeKey.currentState?.refreshData();
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.home_filled,
                        color: displayIndex == 1 ? const Color(0xFF4285F4) : Colors.grey[700],
                        size: 28,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Home',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: displayIndex == 1 ? FontWeight.w600 : FontWeight.w400,
                          color: displayIndex == 1 ? const Color(0xFF4285F4) : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                // Profile tab
                _buildNavItem(
                  icon: Icons.person,
                  label: 'Profile',
                  isSelected: displayIndex == 2,
                  onTap: () {
                    final internal = displayToInternal[2];
                    setState(() => _selectedIndex = internal);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF4285F4) : Colors.grey[500],
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? const Color(0xFF4285F4) : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}