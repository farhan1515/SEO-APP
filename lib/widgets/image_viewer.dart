import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:saver_gallery/saver_gallery.dart';

class ImageViewer extends StatefulWidget {
  final String imageBase64;
  final String tag;

  const ImageViewer({
    Key? key,
    required this.imageBase64,
    required this.tag,
  }) : super(key: key);

  @override
  _ImageViewerState createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  Color _backgroundColor = Colors.blueGrey;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _extractPaletteColor();
  }

  Future<void> _extractPaletteColor() async {
    try {
      final bytes = base64Decode(widget.imageBase64);
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        MemoryImage(bytes),
        maximumColorCount: 10,
      );

      // Find the most dominant color with good visibility
      final dominantColor = paletteGenerator.dominantColor?.color ??
          paletteGenerator.vibrantColor?.color ??
          Colors.white;

      setState(() {
        _backgroundColor = dominantColor.withOpacity(0.2);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        // Use a gradient or a softer background during loading
        _backgroundColor = Colors.white.withOpacity(0.1);
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadImage(BuildContext context) async {
    try {
      final bytes = base64Decode(widget.imageBase64);
      await SaverGallery.saveImage(
        Uint8List.fromList(bytes),
        quality: 100,
        fileName: "project_${DateTime.now().millisecondsSinceEpoch}",
        skipIfExists: true,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Image saved to gallery successfully!',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save image: $e',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = base64Decode(widget.imageBase64);

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Blurred background
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: MemoryImage(bytes),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          _backgroundColor.withOpacity(0.3),
                          BlendMode.darken,
                        ),
                      ),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        color: Colors.black.withOpacity(0.1),
                      ),
                    ),
                  ),
                ),

                // Close button
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 8,
                          )
                        ],
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),

                // Image
                Center(
                  child: Hero(
                    tag: widget.tag,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 4.0,
                          child: Image.memory(
                            bytes,
                            fit: BoxFit.contain,
                            width: MediaQuery.of(context).size.width * 0.9,
                            height: MediaQuery.of(context).size.height * 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Download button
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 24,
                  left: 24,
                  right: 24,
                  child: ElevatedButton(
                    onPressed: () => _downloadImage(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.3),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.download_rounded,
                          size: 28,
                          color: Colors.white,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Save to Gallery',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
