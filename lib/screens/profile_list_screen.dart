import 'package:flutter/material.dart';
import 'package:seo_app/screens/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:seo_app/theme/text_style.dart';
import 'package:solar_icons/solar_icons.dart';

class ProfileListScreen extends StatelessWidget {
  final String userId;
  final bool showAppBar;
  const ProfileListScreen(
      {super.key, required this.userId, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    final body = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFD3BDFC), Color(0xFFC9DEE7)],
        ),
      ),
      child: Column(
        children: [
          // Header section with illustration
          Container(
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Business Profiles',
                        style: mont.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3E1885),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Manage your business details',
                        style: mont.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF3E1885).withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  SolarIconsOutline.buildings_2,
                  size: 48,
                  color: Color(0xFF3E1885),
                ),
              ],
            ),
          ),

          // Add profile button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      userId: userId,
                      profileId: null, // Indicates adding a new profile
                    ),
                  ),
                );
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Color(0xFF5664F5),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF5664F5).withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        SolarIconsOutline.addCircle,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'ADD PROFILE',
                        style: mont.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Profiles list
          Expanded(
            child: Container(
              margin: EdgeInsets.only(top: 16),
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('profiles')
                    .doc(userId)
                    .collection('profiles')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF3E1885),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            SolarIconsOutline.documentAdd,
                            size: 64,
                            color: Color(0xFF3E1885).withOpacity(0.5),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No profiles found',
                            style: mont.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF3E1885).withOpacity(0.7),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Create a new business profile to get started',
                            textAlign: TextAlign.center,
                            style: mont.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF3E1885).withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final profiles = snapshot.data!.docs;
                  return ListView.builder(
                    physics: BouncingScrollPhysics(),
                    itemCount: profiles.length,
                    itemBuilder: (context, index) {
                      final profile = profiles[index];
                      final businessDetails = profile['businessDetails'] ?? {};
                      final businessName =
                          businessDetails['name'] ?? 'Unnamed Business';
                      final businessType =
                          businessDetails['type'] ?? 'No type specified';

                      // Generate a color based on the index
                      final List<Color> cardColors = [
                        Color(0xFFE0E8FF),
                        Color(0xFFFFE9E0),
                        Color(0xFFE0FFEA),
                        Color(0xFFF5E0FF),
                      ];
                      final List<Color> iconColors = [
                        Color(0xFF5664F5),
                        Color(0xFFF56556),
                        Color(0xFF56F58E),
                        Color(0xFFBF56F5),
                      ];

                      final colorIndex = index % cardColors.length;

                      return Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(
                                  userId: userId,
                                  profileId: profile.id,
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Left color accent
                                Container(
                                  width: 12,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: iconColors[colorIndex],
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      bottomLeft: Radius.circular(16),
                                    ),
                                  ),
                                ),
                                // Content
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // Icon in colored circle
                                        Container(
                                          height: 56,
                                          width: 56,
                                          decoration: BoxDecoration(
                                            color: cardColors[colorIndex],
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Icon(
                                              SolarIconsOutline.shop,
                                              color: iconColors[colorIndex],
                                              size: 28,
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 16),
                                        // Text information
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                businessName,
                                                style: mont.copyWith(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF3E1885),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                businessType,
                                                style: mont.copyWith(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w400,
                                                  color: Color(0xFF3E1885)
                                                      .withOpacity(0.7),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Arrow indicator
                                        Icon(
                                          Icons.arrow_forward_ios,
                                          size: 16,
                                          color: Color(0xFF3E1885)
                                              .withOpacity(0.5),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
    if (showAppBar) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Color(0xFFD3BDFC),
          elevation: 0,
          title: Text(
            'My Profiles',
            style: mont.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3E1885),
            ),
          ),
          centerTitle: true,
          iconTheme: IconThemeData(color: Color(0xFF3E1885)),
        ),
        body: body,
      );
    } else {
      return body;
    }
  }
}
