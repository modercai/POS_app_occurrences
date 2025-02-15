import 'package:flutter/material.dart';
import 'package:occurences_pos/screens/login/login.dart';
import 'package:occurences_pos/screens/products/products.dart';
import 'package:occurences_pos/screens/scan_verify/scan_verify.dart';


class EventPOSDashboard extends StatelessWidget {
  final List<MenuOption> menuItems = [
    MenuOption(
      icon: Icons.confirmation_number_outlined,
      label: 'Sell Tickets',
      color: Colors.blue,
        onTap:(context){

        }
    ),
    MenuOption(
      icon: Icons.qr_code_scanner,
      label: 'Scan & Verify',
      color: Colors.purple, onTap:(context) {
       Navigator.push(context, MaterialPageRoute(builder: (context) => NFCVerificationPage()));
    },
    ),
    MenuOption(
      icon: Icons.event,
      label: 'Stoke',
      color: Colors.green,
        onTap:(context){
        Navigator.push(context, MaterialPageRoute(builder: (context) => VendorLogin()));
        }
    ),

    MenuOption(
      icon: Icons.payment,
      label: 'Products',
      color: Colors.orange,
      onTap:(context){
        Navigator.push(context, MaterialPageRoute(builder: (context) => ProductsPage()));
    }
    ),
    MenuOption(
      icon: Icons.history,
      label: 'Transaction History',
      color: Colors.pink,
        onTap:(context){

        }
    ),
    MenuOption(
      icon: Icons.people,
      label: 'Attendees',
      color: Colors.cyan,
        onTap:(context){

        }
    ),
    MenuOption(
      icon: Icons.bar_chart,
      label: 'Analytics',
      color: Colors.amber,
        onTap:(context){

        }
    ),
    MenuOption(
      icon: Icons.settings,
      label: 'Settings',
      color: Colors.grey,
        onTap:(context){

        }
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF312E81), // indigo-900
              Color(0xFF581C87), // purple-900
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.confirmation_number_outlined,
                          color: Colors.white,
                          size: 32,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'POS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    // Search Bar
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: TextField(
                            style: TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Search events...',
                              hintStyle: TextStyle(color: Colors.white70),
                              prefixIcon: Icon(Icons.search, color: Colors.white70),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                // Grid
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1,
                    ),
                    itemCount: menuItems.length,
                    itemBuilder: (context, index) {
                      return MenuCard(menuOption: menuItems[index]);
                    },
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

class MenuOption {
  final IconData icon;
  final String label;
  final Color color;
  final Function(BuildContext) onTap;

  MenuOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class MenuCard extends StatelessWidget {
  final MenuOption menuOption;

  const MenuCard({Key? key, required this.menuOption}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => menuOption.onTap(context),  // Updated to use the callback
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: menuOption.color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                menuOption.icon,
                color: Colors.white,
                size: 32,
              ),
            ),
            SizedBox(height: 12),
            Text(
              menuOption.label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}