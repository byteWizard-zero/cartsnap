import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controllers/billing_controller.dart';
import 'scanner_view.dart';
import 'cart_view.dart';
import 'sales_history_view.dart';
import 'printer_link_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> with SingleTickerProviderStateMixin {
  late AnimationController _spinningController;

  @override
  void initState() {
    super.initState();
    _spinningController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
  }

  @override
  void dispose() {
    _spinningController.dispose();
    super.dispose();
  }

  Future<void> _redirectToPlatform(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Redirection link exception: $e");
    }
  }

  void _triggerGadgetSpin() {
    if (!_spinningController.isAnimating) {
      _spinningController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final billingController = Provider.of<BillingController>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      drawer: _buildDeveloperDrawer(context),
      body: Builder(
        builder: (innerContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Scaffold.of(innerContext).openDrawer(),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black12, width: 1),
                          ),
                          child: const CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.black,
                            child: Icon(Icons.bolt_rounded, color: Colors.yellow, size: 24),
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _triggerGadgetSpin,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE8EBF0)),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: RotationTransition(
                            turns: CurvedAnimation(
                              parent: _spinningController,
                              curve: Curves.decelerate,
                            ),
                            child: const Icon(
                              Icons.hourglass_empty_rounded,
                              color: Colors.black87,
                              size: 26,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 28),

                  const Text(
                    'Hi Partner! 👋',
                    style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'What are we\nselling today?',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, height: 1.2, letterSpacing: -1),
                  ),
                  const SizedBox(height: 16),
                  _buildUpdateBanner(billingController),
                  const SizedBox(height: 16),

                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.9,
                      children: [
                        _buildBentoCard(
                          title: "Current Cart",
                          value: "₹${billingController.totalCartAmount.toStringAsFixed(2)}",
                          subtitle: "${billingController.cartItems.length} Items pending",
                          backgroundColor: const Color(0xFFE3F2FD),
                          icon: Icons.account_balance_wallet_outlined,
                          iconColor: Colors.blue,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const CartView()));
                          },
                        ),
                        _buildBentoCard(
                          title: "Scanner Engine",
                          value: "Ready",
                          subtitle: "Hardware online",
                          backgroundColor: const Color(0xFFE8F5E9),
                          icon: Icons.qr_code_scanner_rounded,
                          iconColor: Colors.green,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerView()));
                          },
                        ),
                        _buildBentoCard(
                          title: "Today's Sales",
                          value: "₹${billingController.totalSalesToday.toStringAsFixed(2)}",
                          subtitle: "${billingController.checkoutCountToday} Checkouts completed",
                          backgroundColor: const Color(0xFFF3E5F5),
                          icon: Icons.analytics_outlined,
                          iconColor: Colors.purple,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesHistoryView()));
                          },
                        ),
                        _buildBentoCard(
                          title: "Device Links",
                          value: billingController.isPrinterConnected ? "Printer Connected" : "Printer",
                          subtitle: billingController.isPrinterConnected ? "Ready to print 🧾" : "Pool Offline",
                          backgroundColor: billingController.isPrinterConnected ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                          icon: billingController.isPrinterConnected ? Icons.print_rounded : Icons.print_disabled_rounded,
                          iconColor: billingController.isPrinterConnected ? Colors.green : Colors.orange,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const PrinterLinkView()));
                          },
                        ),
                      ],
                    ),
                  ),

                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () => _openInventoryExplorerSheet(context),
                            child: const Icon(Icons.grid_view_rounded, color: Colors.black87, size: 24)
                          ),
                          const SizedBox(width: 24),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerView()));
                            },
                            child: const CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.black,
                              child: Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                          const SizedBox(width: 24),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const SalesHistoryView()));
                            },
                            child: const Icon(Icons.history_rounded, color: Colors.black38, size: 24),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ));
          }
      ),
    );
  }

  Widget _buildDeveloperDrawer(BuildContext context) {
    final double drawerWidth = MediaQuery.of(context).size.width * 0.76;
    return SizedBox(
      width: drawerWidth,
      child: Drawer(
        backgroundColor: const Color(0xFFF5F7FB),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const CircleAvatar(
                radius: 36,
                backgroundColor: Colors.black,
                child: Icon(Icons.code_rounded, color: Colors.white, size: 34),
              ),
              const SizedBox(height: 16),
              const Text(
                'Soumya Ranjan Jana',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
              const Text(
                'IoT & Systems Engineer • ITER Student',
                style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text(
                '“Building real-world distributed architectures, manual sorting loops, and AI-driven workflows.”',
                style: TextStyle(fontSize: 12, color: Colors.black54, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.black12),
              const SizedBox(height: 12),
              
              const Text(
                'LAUNCH REDIRECTIONS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black45, letterSpacing: 1.5),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildSocialCard(
                      label: "WhatsApp",
                      icon: Icons.chat_bubble_outline_rounded,
                      bgColor: const Color(0xFFE8F5E9),
                      textColor: const Color(0xFF2E7D32),
                      url: "https://wa.me/917854041120",
                    ),
                    _buildSocialCard(
                      label: "Instagram",
                      icon: Icons.camera_alt_outlined,
                      bgColor: const Color(0xFFFCE4EC),
                      textColor: const Color(0xFFC2185B),
                      url: "https://www.instagram.com/zenith.soumya?igsh=MXhoMmVxbDZsNjVjYw==",
                    ),
                    _buildSocialCard(
                      label: "GitHub Engine",
                      icon: Icons.terminal_rounded,
                      bgColor: const Color(0xFFECEFF1),
                      textColor: const Color(0xFF37474F),
                      url: "https://github.com/byteWizard-zero",
                    ),
                    _buildSocialCard(
                      label: "LinkedIn Pipeline",
                      icon: Icons.work_outline_rounded,
                      bgColor: const Color(0xFFE3F2FD),
                      textColor: const Color(0xFF1565C0),
                      url: "https://www.linkedin.com/in/soumya-ranjan-jana-414586370?utm_source=share_via&utm_content=profile&utm_medium=member_android",
                    ),
                  ],
                ),
              ),

              Center(
                child: Column(
                  children: [
                    const Text(
                      'Made by Soumya with 🧠',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'v1.2.0 Stable • Cloud Configured',
                      style: TextStyle(fontSize: 11, color: Colors.black38, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialCard({
    required String label,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
    required String url,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: InkWell(
        onTap: () => _redirectToPlatform(url),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: textColor, size: 22),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded, color: textColor.withOpacity(0.4), size: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _openInventoryExplorerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      ),
      builder: (ctx) {
        return Consumer<BillingController>(
          builder: (context, controller, child) {
            final registry = controller.localDatabaseRegistry;
            final barcodesList = registry.keys.toList();

            return Container(
              padding: const EdgeInsets.all(28),
              height: MediaQuery.of(context).size.height * 0.65,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Store Inventory 📂",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          "${barcodesList.length} Registered",
                          style: const TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text("Swipe any item card left to delete it from storage, or tap the pencil icon to modify local market pricing.", style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.3)),
                  const SizedBox(height: 20),
                  
                  Expanded(
                    child: barcodesList.isEmpty
                    ? const Center(child: Text("Inventory database is empty. Go scan some barcodes! 📦", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: barcodesList.length,
                        itemBuilder: (context, i) {
                          final barcode = barcodesList[i];
                          final productData = registry[barcode]!;

                          return Dismissible(
                            key: Key(barcode),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(16)),
                              child: const Icon(Icons.delete_forever_rounded, color: Colors.white, size: 26),
                            ),
                            onDismissed: (direction) {
                              controller.deleteItemFromInventory(barcode);
                            },
                            child: Card(
                              color: const Color(0xFFF5F7FB),
                              elevation: 0,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: ListTile(
                                leading: const Icon(Icons.inventory_2_outlined, color: Colors.black54),
                                title: Text(productData['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                subtitle: Text('Code: $barcode', style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.grey)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '₹${(productData['price'] as num).toStringAsFixed(2)}', 
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15)
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.mode_edit_outline_rounded, color: Colors.blueAccent, size: 18),
                                      onPressed: () => _showInlinePriceEditDialog(context, controller, barcode, productData['name']),
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
            );
          }
        );
      },
    );
  }

  void _showInlinePriceEditDialog(BuildContext context, BillingController controller, String barcode, String name) {
    double? updatedPrice;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Modify Price: $name"),
        content: TextField(
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "New Value (₹)", prefixText: "₹ "),
          onChanged: (value) => updatedPrice = double.tryParse(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (updatedPrice != null && updatedPrice! > 0) {
                controller.updateInventoryPrice(barcode, updatedPrice!);
                Navigator.pop(ctx);
              }
            },
            child: const Text("Update"),
          )
        ],
      ),
    );
  }

  Widget _buildUpdateBanner(BillingController controller) {
    if (!controller.hasUpdate) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2F80ED), Color(0xFF56CCF2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2F80ED).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Update Available! (${controller.latestVersion})",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  "New features are ready. Tap to download.",
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _redirectToPlatform(controller.updateDownloadUrl),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2F80ED),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Get", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
            onPressed: () => controller.dismissUpdateNotification(),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoCard({
    required String title,
    required String value,
    required String subtitle,
    required Color backgroundColor,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: iconColor, size: 28),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black26, size: 14),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            )
          ],
        ),
      ),
    );
  }
}