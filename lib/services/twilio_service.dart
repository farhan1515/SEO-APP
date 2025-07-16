import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class TwilioService {
  final String accountSid;
  final String authToken;
  final String
      fromNumber; // Twilio WhatsApp sandbox number, e.g. 'whatsapp:+14155238886'

  TwilioService({
    required this.accountSid,
    required this.authToken,
    required this.fromNumber,
  });

  Future<void> sendWhatsAppMessage(String toNumber, String message) async {
    final url = Uri.parse(
        'https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json');
    final response = await http.post(
      url,
      headers: {
        'Authorization':
            'Basic ' + base64Encode(utf8.encode('$accountSid:$authToken')),
      },
      body: {
        'From': fromNumber,
        'To': 'whatsapp:$toNumber',
        'Body': message,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to send WhatsApp message: ${response.body}');
    }
  }

  Future<void> sendWhatsAppMessageWithImage(
    String toNumber,
    String message,
    String? flyerBase64, {
    String? postId,
  }) async {
    final url = Uri.parse(
        'https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json');

    Map<String, String> body = {
      'From': fromNumber,
      'To': 'whatsapp:$toNumber',
      'Body': message,
    };

    // If we have a flyer image, upload it to Firebase Storage and get public URL
    if (flyerBase64 != null && flyerBase64.isNotEmpty) {
      try {
        String? mediaUrl = await _uploadImageAndGetUrl(flyerBase64, postId);
        if (mediaUrl != null) {
          body['MediaUrl'] = mediaUrl;
        }
      } catch (e) {
        print('Error uploading image for WhatsApp: $e');
        // Continue sending text message even if image upload fails
      }
    }

    final response = await http.post(
      url,
      headers: {
        'Authorization':
            'Basic ' + base64Encode(utf8.encode('$accountSid:$authToken')),
      },
      body: body,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to send WhatsApp message: ${response.body}');
    }
  }

  Future<String?> _uploadImageAndGetUrl(
      String base64Image, String? postId) async {
    try {
      // Decode base64 image
      Uint8List imageBytes = base64Decode(base64Image);

      // Create a unique filename
      String fileName =
          'whatsapp_flyers/${postId ?? DateTime.now().millisecondsSinceEpoch}_flyer.jpg';

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      final uploadTask = await storageRef.putData(
        imageBytes,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'purpose': 'whatsapp_flyer',
            'postId': postId ?? 'unknown',
          },
        ),
      );

      // Get download URL
      String downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image to Firebase Storage: $e');
      return null;
    }
  }

  // Alternative method using direct base64 data URL (for smaller images)
  Future<void> sendWhatsAppMessageWithBase64Image(
    String toNumber,
    String message,
    String flyerBase64,
  ) async {
    final url = Uri.parse(
        'https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json');

    // Create data URL from base64
    String dataUrl = 'data:image/jpeg;base64,$flyerBase64';

    final response = await http.post(
      url,
      headers: {
        'Authorization':
            'Basic ' + base64Encode(utf8.encode('$accountSid:$authToken')),
      },
      body: {
        'From': fromNumber,
        'To': 'whatsapp:$toNumber',
        'Body': message,
        'MediaUrl': dataUrl,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Failed to send WhatsApp message with image: ${response.body}');
    }
  }

  // Add this method to support sending WhatsApp messages with a public image URL
  Future<void> sendWhatsAppMessageWithImageUrl(
    String toNumber,
    String message,
    String? imageUrl,
  ) async {
    final url = Uri.parse(
        'https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json');
    Map<String, String> body = {
      'From': fromNumber,
      'To': 'whatsapp:$toNumber',
      'Body': message,
    };
    if (imageUrl != null && imageUrl.isNotEmpty) {
      body['MediaUrl'] = imageUrl;
    }
    final response = await http.post(
      url,
      headers: {
        'Authorization':
            'Basic ' + base64Encode(utf8.encode('$accountSid:$authToken')),
      },
      body: body,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to send WhatsApp message: $response.body');
    }
  }
}
