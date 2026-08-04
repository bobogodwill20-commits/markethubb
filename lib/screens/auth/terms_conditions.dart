import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Terms & Conditions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? Colors.grey.shade800 : Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [Colors.blue.shade900, Colors.purple.shade900]
                      : [Colors.blue.shade600, Colors.purple.shade700],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.gavel,
                    color: Colors.white,
                    size: 50,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'MarketHub Terms & Conditions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last Updated: June 2024',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 1: Introduction
            _buildSection(
              '1. Introduction',
              'Welcome to MarketHub! By using our platform, you agree to comply with and be bound by the following terms and conditions. Please read them carefully before using our services.',
              isDark,
            ),
            const SizedBox(height: 16),

            // Section 2: Account Registration
            _buildSection(
              '2. Account Registration',
              '• You must be at least 18 years old to create an account.\n'
              '• You must provide accurate and complete information during registration.\n'
              '• You are responsible for maintaining the confidentiality of your account credentials.\n'
              '• You agree to notify us immediately of any unauthorized use of your account.\n'
              '• We reserve the right to suspend or terminate accounts that violate these terms.',
              isDark,
            ),
            const SizedBox(height: 16),

            // Section 3: User Roles
            _buildSection(
              '3. User Roles',
              '3.1 Buyers:\n'
              '• Can browse and purchase products listed on the platform.\n'
              '• Must provide accurate shipping information.\n'
              '• Agree to pay for products they order.\n\n'
              '3.2 Sellers:\n'
              '• Must be verified by the admin before listing products.\n'
              '• Are responsible for the accuracy of product listings.\n'
              '• Must fulfill orders in a timely manner.\n'
              '• Agree to the platform\'s commission structure.\n\n'
              '3.3 Admins:\n'
              '• Have full control over the platform.\n'
              '• Can validate seller accounts.\n'
              '• Manage disputes and enforce policies.',
              isDark,
            ),
            const SizedBox(height: 16),

            // Section 4: Payments
            _buildSection(
              '4. Payments and Fees',
              '• All payments are processed through secure third-party payment gateways.\n'
              '• Prices are listed in XAF (CFA Franc).\n'
              '• Sellers agree to pay a commission fee on each successful transaction.\n'
              '• Buyers are responsible for any applicable taxes or delivery fees.\n'
              '• Refunds are handled on a case-by-case basis.',
              isDark,
            ),
            const SizedBox(height: 16),

            // Section 5: Shipping and Delivery
            _buildSection(
              '5. Shipping and Delivery',
              '• Sellers are responsible for shipping products to buyers.\n'
              '• Delivery times may vary depending on location.\n'
              '• Buyers should provide accurate shipping addresses.\n'
              '• Tracking numbers will be provided once the order is shipped.\n'
              '• Risk of loss transfers to the buyer upon delivery.',
              isDark,
            ),
            const SizedBox(height: 16),

            // Section 6: Returns and Refunds
            _buildSection(
              '6. Returns and Refunds',
              '• Buyers may request returns within 7 days of delivery.\n'
              '• Products must be in original condition for return eligibility.\n'
              '• Refunds will be processed after the returned item is inspected.\n'
              '• Shipping costs for returns are the responsibility of the buyer.\n'
              '• Digital products are non-refundable.',
              isDark,
            ),
            const SizedBox(height: 16),

            // Section 7: Privacy and Data Protection
            _buildSection(
              '7. Privacy and Data Protection',
              '• We collect and process personal data in accordance with our Privacy Policy.\n'
              '• Your information is used to provide and improve our services.\n'
              '• We do not share your personal data with third parties without consent.\n'
              '• You have the right to access, modify, or delete your personal data.',
              isDark,
            ),
            const SizedBox(height: 16),

            // Section 8: Intellectual Property
            _buildSection(
              '8. Intellectual Property',
              '• All content on the platform is protected by copyright laws.\n'
              '• You may not reproduce, distribute, or modify any content without permission.\n'
              '• Sellers retain ownership of their product images and descriptions.\n'
              '• MarketHub owns the platform\'s design, logos, and trademarks.',
              isDark,
            ),
            const SizedBox(height: 16),

            // Section 9: Prohibited Activities
            _buildSection(
              '9. Prohibited Activities',
              '• You may not use the platform for any illegal or unauthorized purpose.\n'
              '• You may not attempt to hack, disrupt, or damage the platform.\n'
              '• You may not impersonate others or provide false information.\n'
              '• You may not upload malware or malicious code.\n'
              '• You may not engage in fraudulent activities.',
              isDark,
            ),
            const SizedBox(height: 16),

            // Section 10: Termination
            _buildSection(
              '10. Termination',
              '• We reserve the right to suspend or terminate accounts that violate these terms.\n'
              '• You may delete your account at any time.\n'
              '• Upon termination, you must cease using the platform.\n'
              '• Termination does not affect any rights or obligations that have arisen.',
              isDark,
            ),
            const SizedBox(height: 16),

            // Section 11: Limitation of Liability
            _buildSection(
              '11. Limitation of Liability',
              '• The platform is provided "as is" without warranties.\n'
              '• We are not liable for any damages arising from your use of the platform.\n'
              '• We do not guarantee the accuracy of product listings.\n'
              '• Our liability is limited to the maximum extent permitted by law.',
              isDark,
            ),
            const SizedBox(height: 16),

            // Section 12: Governing Law
            _buildSection(
              '12. Governing Law',
              '• These terms are governed by the laws of Cameroon.\n'
              '• Any disputes shall be resolved in the courts of Cameroon.\n'
              '• You agree to submit to the jurisdiction of these courts.',
              isDark,
            ),
            const SizedBox(height: 16),

            // Section 13: Changes to Terms
            _buildSection(
              '13. Changes to Terms',
              '• We may update these terms from time to time.\n'
              '• You will be notified of significant changes.\n'
              '• Continued use of the platform constitutes acceptance of the new terms.\n'
              '• The latest version of these terms is always available on this page.',
              isDark,
            ),
            const SizedBox(height: 16),

            // Section 14: Contact Us
            _buildSection(
              '14. Contact Us',
              'If you have any questions about these terms, please contact us:\n\n'
              '📧 Email: support@markethub.com\n'
              '📞 Phone: +237 670 000 000\n'
              '📍 Address: Douala, Cameroon',
              isDark,
            ),
            const SizedBox(height: 24),

            // Accept Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'I Agree',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}