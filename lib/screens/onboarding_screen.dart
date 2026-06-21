import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {

  final PageController controller = PageController();

  bool lastPage = false;

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AppTheme.background,

      body: Stack(
        children: [

          PageView(
            controller: controller,

            onPageChanged: (index) {
              setState(() {
                lastPage = index == 2;
              });
            },

            children: [

              buildPage(
                icon: Icons.storefront,
                title: "Discover Nearby Stores",
                subtitle:
                "Find groceries, bakeries, medical stores and more around you.",
              ),

              buildPage(
                icon: Icons.shopping_cart,
                title: "Browse Products",
                subtitle:
                "Explore thousands of products from local stores.",
              ),

              buildPage(
                icon: Icons.local_offer,
                title: "Best Deals & Offers",
                subtitle:
                "Get exciting discounts and exclusive offers everyday.",
              ),
            ],
          ),

          Container(
            alignment: const Alignment(0, 0.78),

            child: SmoothPageIndicator(
              controller: controller,
              count: 3,

              effect: ExpandingDotsEffect(
                activeDotColor: AppTheme.dark,
                dotColor: Colors.grey.shade400,
                dotHeight: 10,
                dotWidth: 10,
              ),
            ),
          ),

          Container(
            alignment: const Alignment(0, 0.93),

            child: lastPage
                ? ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(220, 55),
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginScreen(),
                  ),
                );
              },
              child: const Text(
                "Get Started",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            )
                : TextButton(
              onPressed: () {
                controller.nextPage(
                  duration:
                  const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              },
              child: const Text(
                "Next",
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(25),

      child: Column(
        children: [

          const SizedBox(height: 70),

          Container(
            height: 300,

            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppTheme.dark,
                  AppTheme.primary,
                ],
              ),

              borderRadius: BorderRadius.circular(40),
            ),

            child: Center(
              child: Icon(
                icon,
                size: 140,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 50),

          Text(
            title,
            textAlign: TextAlign.center,

            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            subtitle,
            textAlign: TextAlign.center,

            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}