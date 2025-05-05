import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SocialMediaService {
  // WhatsApp Business API credentials
  static const String whatsappApiUrl = 'https://graph.facebook.com/v20.0';
  static const String whatsappAccessToken = 'YOUR_WHATSAPP_ACCESS_TOKEN';
  static const String whatsappPhoneNumberId = 'YOUR_PHONE_NUMBER_ID';

  // Meta Graph API credentials
  static const String metaApiUrl = 'https://graph.facebook.com/v20.0';
  static const String metaAccessToken = 'YOUR_META_ACCESS_TOKEN';

  // Fetch profile data from Firestore
  Future<Map<String, dynamic>?> _fetchProfileData(String userId, String profileId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('profiles')
          .doc(userId)
          .collection('profiles')
          .doc(profileId)
          .get();
      return doc.exists ? doc.data() as Map<String, dynamic> : null;
    } catch (e) {
      print('Error fetching profile data: $e');
      return null;
    }
  }

  // Post to WhatsApp
  Future<bool> postToWhatsApp(String phoneNumber, String base64Image, String caption) async {
    try {
      final Uint8List imageBytes = base64Decode(base64Image);
      final String mediaUrl = '$whatsappApiUrl/$whatsappPhoneNumberId/media';
      final String messageUrl = '$whatsappApiUrl/$whatsappPhoneNumberId/messages';

      // Upload media
      var request = http.MultipartRequest('POST', Uri.parse(mediaUrl))
        ..headers['Authorization'] = 'Bearer $whatsappAccessToken'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: 'flyer.jpg',
        ));

      final mediaResponse = await request.send();
      final mediaData = jsonDecode(await mediaResponse.stream.bytesToString());

      if (mediaResponse.statusCode != 200 || mediaData['id'] == null) {
        print('Failed to upload media to WhatsApp: ${mediaData['error']}');
        return false;
      }

      // Send message with media
      final response = await http.post(
        Uri.parse(messageUrl),
        headers: {
          'Authorization': 'Bearer $whatsappAccessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'messaging_product': 'whatsapp',
          'to': phoneNumber,
          'type': 'image',
          'image': {'id': mediaData['id'], 'caption': caption},
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['messages'] != null) {
        print('Successfully posted to WhatsApp');
        return true;
      } else {
        print('Failed to post to WhatsApp: ${data['error']}');
        return false;
      }
    } catch (e) {
      print('Error posting to WhatsApp: $e');
      return false;
    }
  }

  // Post to Facebook
  Future<bool> postToFacebook(String pageId, String base64Image, String caption) async {
    try {
      final Uint8List imageBytes = base64Decode(base64Image);
      final String url = '$metaApiUrl/$pageId/photos';

      var request = http.MultipartRequest('POST', Uri.parse(url))
        ..headers['Authorization'] = 'Bearer $metaAccessToken'
        ..fields['message'] = caption
        ..fields['published'] = 'true'
        ..files.add(http.MultipartFile.fromBytes(
          'source',
          imageBytes,
          filename: 'flyer.jpg',
        ));

      final response = await request.send();
      final data = jsonDecode(await response.stream.bytesToString());

      if (response.statusCode == 200 && data['id'] != null) {
        print('Successfully posted to Facebook');
        return true;
      } else {
        print('Failed to post to Facebook: ${data['error']}');
        return false;
      }
    } catch (e) {
      print('Error posting to Facebook: $e');
      return false;
    }
  }

  // Post to Instagram
  Future<bool> postToInstagram(String instagramAccountId, String base64Image, String caption) async {
    try {
      final Uint8List imageBytes = base64Decode(base64Image);
      final String mediaUrl = '$metaApiUrl/$instagramAccountId/media';
      final String publishUrl = '$metaApiUrl/$instagramAccountId/media_publish';

      // Create media object
      var request = http.MultipartRequest('POST', Uri.parse(mediaUrl))
        ..headers['Authorization'] = 'Bearer $metaAccessToken'
        ..fields['image_url'] = '' // Temporary, we'll upload the image
        ..fields['caption'] = caption
        ..files.add(http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'flyer.jpg',
        ));

      final mediaResponse = await request.send();
      final mediaData = jsonDecode(await mediaResponse.stream.bytesToString());

      if (mediaResponse.statusCode != 200 || mediaData['id'] == null) {
        print('Failed to create Instagram media: ${mediaData['error']}');
        return false;
      }

      // Publish media
      final publishResponse = await http.post(
        Uri.parse(publishUrl),
        headers: {
          'Authorization': 'Bearer $metaAccessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'creation_id': mediaData['id']}),
      );

      final publishData = jsonDecode(publishResponse.body);
      if (publishResponse.statusCode == 200 && publishData['id'] != null) {
        print('Successfully posted to Instagram');
        return true;
      } else {
        print('Failed to publish to Instagram: ${publishData['error']}');
        return false;
      }
    } catch (e) {
      print('Error posting to Instagram: $e');
      return false;
    }
  }

  // Main function to handle posting
  Future<void> postFlyer({
    required String userId,
    required String profileId,
    required String base64Image,
    required List<String> platforms,
    required String caption,
    String? scheduledDate,
    String? scheduledTime,
    String? timezone,
  }) async {
    final profileData = await _fetchProfileData(userId, profileId);
    if (profileData == null) {
      print('Profile data not found');
      return;
    }

    final socialMedia = profileData['socialMedia'] as Map<String, dynamic>? ?? {};
    final whatsappNumber = socialMedia['whatsapp']?.toString();
    final facebookUrl = socialMedia['facebook']?.toString();
    final instagramUrl = socialMedia['instagram']?.toString();

    // Extract page/account IDs (you'll need to map URLs to IDs)
    // For simplicity, assume these are page/account IDs (replace with actual logic)
    const String facebookPageId = 'YOUR_FACEBOOK_PAGE_ID';
    const String instagramAccountId = 'YOUR_INSTAGRAM_ACCOUNT_ID';

    for (String platform in platforms) {
      switch (platform.toLowerCase()) {
        case 'whatsapp':
          if (whatsappNumber != null && whatsappNumber.isNotEmpty) {
            final success = await postToWhatsApp(whatsappNumber, base64Image, caption);
            if (!success) {
              print('Failed to post to WhatsApp');
            }
          }
          break;
        case 'facebook':
          if (facebookUrl != null && facebookUrl.isNotEmpty) {
            final success = await postToFacebook(facebookPageId, base64Image, caption);
            if (!success) {
              print('Failed to post to Facebook');
            }
          }
          break;
        case 'instagram':
          if (instagramUrl != null && instagramUrl.isNotEmpty) {
            final success = await postToInstagram(instagramAccountId, base64Image, caption);
            if (!success) {
              print('Failed to post to Instagram');
            }
          }
          break;
      }
    }
  }
}