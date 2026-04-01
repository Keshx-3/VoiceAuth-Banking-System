import 'package:flutter/material.dart';

/// A shimmer effect widget that animates a gradient over its child.
class ShimmerEffect extends StatefulWidget {
  final Widget child;

  const ShimmerEffect({super.key, required this.child});

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFE0E0E0),
                Color(0xFFF5F5F5),
                Color(0xFFE0E0E0),
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Shimmer placeholder for the Recent Contacts grid
class ContactsShimmer extends StatelessWidget {
  const ContactsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: List.generate(
          4,
          (index) => Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFFE0E0E0),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 48,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer placeholder for the Recent Activity transaction list
class TransactionsShimmer extends StatelessWidget {
  final int itemCount;

  const TransactionsShimmer({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Column(
        children: List.generate(
          itemCount,
          (index) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                // Avatar placeholder
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: Color(0xFFE0E0E0),
                ),
                const SizedBox(width: 16),
                // Name and date placeholders
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E0E0),
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 80,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E0E0),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ],
                  ),
                ),
                // Amount placeholder
                Container(
                  width: 60,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shimmer placeholder for the Passbook / History screen
class PassbookShimmer extends StatelessWidget {
  const PassbookShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Balance card placeholder
            Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 20),
            // Stat cards row
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // History header placeholder
            Container(
              width: 100,
              height: 20,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            // Transaction row placeholders
            ...List.generate(5, (index) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 22,
                      backgroundColor: Color(0xFFE0E0E0),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 140,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0E0E0),
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 90,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0E0E0),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}

/// Shimmer placeholder for the Profile screen
class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Avatar placeholder
            const CircleAvatar(
              radius: 60,
              backgroundColor: Color(0xFFE0E0E0),
            ),
            const SizedBox(height: 16),
            // Name placeholder
            Container(
              width: 120,
              height: 22,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            const SizedBox(height: 8),
            // Phone placeholder
            Container(
              width: 100,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
            const SizedBox(height: 28),
            // Balance card placeholder
            Container(
              width: double.infinity,
              height: 170,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 28),
            // Section header placeholder
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 160,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Settings row placeholders
            ...List.generate(2, (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: double.infinity,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: Color(0xFFE0E0E0),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 130,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0E0E0),
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 80,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0E0E0),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }
}
