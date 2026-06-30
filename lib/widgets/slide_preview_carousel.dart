import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_content_service.dart';

class SlideTheme {
  final String name;
  final BoxDecoration decoration;
  final Color textColor;
  final Color titleColor;
  final Color accentColor;
  final List<Color> previewColors;

  const SlideTheme({
    required this.name,
    required this.decoration,
    required this.textColor,
    required this.titleColor,
    required this.accentColor,
    required this.previewColors,
  });
}

final List<SlideTheme> slideThemes = [
  const SlideTheme(
    name: 'Sunset Glow',
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    textColor: Colors.white,
    titleColor: Colors.white,
    accentColor: Color(0xFFFFE16D),
    previewColors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
  ),
  const SlideTheme(
    name: 'Midnight Lavender',
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF654EA3), Color(0xFFEAAFC8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    textColor: Colors.white,
    titleColor: Colors.white,
    accentColor: Color(0xFFFFD166),
    previewColors: [Color(0xFF654EA3), Color(0xFFEAAFC8)],
  ),
  const SlideTheme(
    name: 'Ocean Breeze',
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    textColor: Colors.white,
    titleColor: Colors.white,
    accentColor: Color(0xFF0F2027),
    previewColors: [Color(0xFF11998E), Color(0xFF38EF7D)],
  ),
  const SlideTheme(
    name: 'Cyberpunk Purple',
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0F0C20), Color(0xFF533483)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    textColor: Color(0xFFE0E0E0),
    titleColor: Colors.white,
    accentColor: Color(0xFFE94560),
    previewColors: [Color(0xFF0F0C20), Color(0xFF533483)],
  ),
  const SlideTheme(
    name: 'Minimalist Dark',
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF1E1E24), Color(0xFF121212)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    textColor: Color(0xFFE0E0E0),
    titleColor: Colors.white,
    accentColor: Color(0xFFFFE16D),
    previewColors: [Color(0xFF1E1E24), Color(0xFF121212)],
  ),
];

class SlidePreviewCarousel extends StatefulWidget {
  final String noteTitle;
  final String noteContent;

  const SlidePreviewCarousel({
    super.key,
    required this.noteTitle,
    required this.noteContent,
  });

  @override
  State<SlidePreviewCarousel> createState() => _SlidePreviewCarouselState();
}

class _SlidePreviewCarouselState extends State<SlidePreviewCarousel> {
  int _currentThemeIndex = 0;
  int _currentPageIndex = 0;
  List<String> _pages = [];
  bool _isSharing = false;
  final List<GlobalKey> _repaintKeys = [];

  String _backgroundType = 'preset'; // 'preset', 'gallery', 'unsplash'
  File? _pickedImageFile;
  String? _unsplashImageUrl;
  String? _unsplashPhotoAuthor;
  bool _isModified = false;
  bool _isAiGenerating = false;
  String _selectedFontFamily = 'Lora';
  double _contentFontSize = 42.0;

  @override
  void initState() {
    super.initState();
    _paginate();
  }

  @override
  void didUpdateWidget(covariant SlidePreviewCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noteContent != widget.noteContent ||
        oldWidget.noteTitle != widget.noteTitle) {
      _paginate();
    }
  }

  void _paginate() {
    if (widget.noteContent.trim().isEmpty) {
      _pages = ['(Empty Note)'];
    } else {
      _pages = paginateText(
        text: widget.noteContent,
        style: GoogleFonts.getFont(
          _selectedFontFamily,
          fontSize: _contentFontSize,
          height: 1.7,
          fontWeight: FontWeight.w400,
        ),
        maxWidth: 880.0,
        maxHeight: 600.0,
      );
    }

    // Limit text slides to at most 4
    if (_pages.length > 4) {
      _pages = _pages.sublist(0, 4);
    }

    _repaintKeys.clear();
    for (int i = 0; i < _pages.length; i++) {
      _repaintKeys.add(GlobalKey());
    }

    if (_currentPageIndex >= _pages.length) {
      _currentPageIndex = 0;
    }

    _isModified = false;
  }

  static const _channel = MethodChannel('io.github.sslaia.towitowi/save_file');

  Future<void> _pickCustomImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _backgroundType = 'gallery';
          _pickedImageFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      debugPrint('Error picking custom image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showUnsplashSearchDialog() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('detail.unsplash_search_title'.tr()),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'detail.unsplash_search_hint'.tr(),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('detail.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                final query = controller.text.trim();
                Navigator.pop(context);
                if (query.isNotEmpty) {
                  _searchAndApplyUnsplashImage(query);
                }
              },
              child: Text('detail.search'.tr()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _searchAndApplyUnsplashImage(String query) async {
    setState(() {
      _isSharing = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('detail.searching_web'.tr()),
        duration: const Duration(seconds: 1),
      ),
    );

    final result = await searchUnsplashImage(query);

    setState(() {
      _isSharing = false;
    });

    if (result != null) {
      setState(() {
        _backgroundType = 'unsplash';
        _unsplashImageUrl = result['url'];
        _unsplashPhotoAuthor = result['author'];
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('detail.image_search_failed'.tr()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<bool> _saveToDownloadsAndroid(String filePath, String fileName) async {
    try {
      final bool success = await _channel.invokeMethod('saveToDownloads', {
        'filePath': filePath,
        'fileName': fileName,
      });
      return success;
    } on PlatformException catch (e) {
      debugPrint('Error saving file to downloads: $e');
      return false;
    }
  }

  Future<void> _shareSlides() async {
    if (_isSharing) return;

    setState(() {
      _isSharing = true;
    });

    try {
      final List<XFile> filesToShare = [];
      final tempDir = await getTemporaryDirectory();

      // Give a tiny frame delay to make sure the offscreen boundaries are laid out
      await Future.delayed(const Duration(milliseconds: 150));

      for (int i = 0; i < _pages.length; i++) {
        final key = _repaintKeys[i];
        final RenderRepaintBoundary? boundary =
            key.currentContext?.findRenderObject() as RenderRepaintBoundary?;

        if (boundary == null) continue;

        // Scale factor 1.0 yields exactly 1080x1080 image because boundary is sized 1080x1080
        final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
        final ByteData? byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);

        if (byteData == null) continue;

        final Uint8List pngBytes = byteData.buffer.asUint8List();
        final String fileName =
            'towitowi_slide_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.png';

        // Write to temporary directory first
        final File tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(pngBytes);
        filesToShare.add(XFile(tempFile.path));
      }

      if (filesToShare.isNotEmpty) {
        // Save persistently to local storage in background
        for (final xFile in filesToShare) {
          final fileName = xFile.path.split('/').last;
          if (Platform.isAndroid) {
            await _saveToDownloadsAndroid(xFile.path, fileName);
          } else {
            String? downloadsPath;
            if (Platform.isIOS) {
              final dir = await getApplicationDocumentsDirectory();
              downloadsPath = dir.path;
            } else {
              final dir = await getDownloadsDirectory();
              downloadsPath = dir?.path;
            }

            if (downloadsPath != null) {
              final File file = File('$downloadsPath/$fileName');
              await File(xFile.path).copy(file.path);
            }
          }
        }

        // Trigger system share sheet with the files
        await Share.shareXFiles(
          filesToShare,
          text: 'detail.share_slides_text'.tr(),
        );
      }
    } catch (e) {
      debugPrint('Error sharing slides: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('detail.error_msg'.tr(args: [e.toString()])),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  void _copySlidesText() {
    final text = _pages
        .where((p) => p != 'OUTRO_SLIDE')
        .join('\n---\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('detail.copied_slides_text'.tr()),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _deleteCurrentSlide() {
    if (_pages.length <= 2) {
      // Keep at least 1 content slide + 1 outro slide
      return;
    }

    setState(() {
      _pages.removeAt(_currentPageIndex);
      _repaintKeys.removeAt(_currentPageIndex);
      _isModified = true;

      if (_currentPageIndex >= _pages.length) {
        _currentPageIndex = _pages.length - 1;
      }
    });
  }

  void _resetSlides() {
    setState(() {
      _paginate();
      _isModified = false;
      _currentPageIndex = 0;
    });
  }

  Future<void> _craftSlidesWithAi() async {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final aiService = Provider.of<AiContentService>(context, listen: false);

    if (!aiService.hasAnyConfiguredKey(settingsProvider.geminiApiKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('detail.gemini_not_configured'.tr()),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isAiGenerating = true;
    });

    try {
      final generatedText = await aiService.generateInstagramSlides(
        textContent: widget.noteContent,
        userApiKey: settingsProvider.geminiApiKey,
      );

      // Split by '---' to get individual slides
      List<String> rawSlides = generatedText
          .split('---')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (rawSlides.isEmpty) {
        throw Exception('detail.failed_to_generate_summary'.tr());
      }

      setState(() {
        _pages = rawSlides;
        
        // Limit to at most 4
        if (_pages.length > 4) {
          _pages = _pages.sublist(0, 4);
        }

        _repaintKeys.clear();
        for (int i = 0; i < _pages.length; i++) {
          _repaintKeys.add(GlobalKey());
        }

        _currentPageIndex = 0;
        _isModified = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'detail.failed_to_generate_summary'.tr()}: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAiGenerating = false;
        });
      }
    }
  }

  void _editCurrentSlide() {
    final textController = TextEditingController(text: _pages[_currentPageIndex]);
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(
            'detail.edit_slide_title'.tr(args: [(_currentPageIndex + 1).toString()]),
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: textController,
            maxLines: 8,
            minLines: 3,
            decoration: InputDecoration(
              hintText: 'detail.edit_slide_hint'.tr(),
              border: const OutlineInputBorder(),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: theme.colorScheme.primaryContainer,
                  width: 2.0,
                ),
              ),
            ),
            style: theme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'detail.cancel'.tr(),
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
              ),
              onPressed: () {
                final newText = textController.text.trim();
                Navigator.pop(context);
                if (newText.isNotEmpty && newText != _pages[_currentPageIndex]) {
                  setState(() {
                    _pages[_currentPageIndex] = newText;
                    _isModified = true;
                  });
                }
              },
              child: Text(
                'detail.save'.tr(),
                style: TextStyle(color: theme.colorScheme.onPrimary),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeTheme = slideThemes[_currentThemeIndex];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Offscreen render area for image export capturing
        Positioned(
          left: -2000.0,
          top: 0.0,
          child: SizedBox(
            width: 1080.0,
            height: 1080.0,
            child: Stack(
              children: List.generate(_pages.length, (index) {
                return RepaintBoundary(
                  key: _repaintKeys[index],
                  child: SizedBox(
                    width: 1080.0,
                    height: 1080.0,
                    child: _buildSingleSlide(
                      pageIndex: index,
                      content: _pages[index],
                      theme: activeTheme,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),

        // Main Carousel Layout Column
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Visual square card preview container (FittedBox fits 1080x1080 cleanly on screen)
            Center(
              child: GestureDetector(
                onDoubleTap: _editCurrentSlide,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10.0,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.0),
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: SizedBox(
                                width: 1080.0,
                                height: 1080.0,
                                child: _buildSingleSlide(
                                  pageIndex: _currentPageIndex,
                                  content: _pages[_currentPageIndex],
                                  theme: activeTheme,
                                ),
                              ),
                            ),
                          ),
                          if (_isAiGenerating)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.7),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const CircularProgressIndicator(
                                        color: Color(0xFFFFE16D),
                                      ),
                                      const SizedBox(height: 16.0),
                                      Text(
                                        'detail.gemini_crafting'.tr(args: ['detail.tab_instagram'.tr()]),
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16.0),

            // Carousel controls row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left page navigator
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: _currentPageIndex > 0
                      ? () {
                          setState(() {
                            _currentPageIndex--;
                          });
                        }
                      : null,
                ),

                // Middle: Indicator dots (Scrollable horizontally if needed)
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_pages.length, (index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4.0),
                            width: 8.0,
                            height: 8.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentPageIndex == index
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),

                // Right page navigator
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded),
                  onPressed: _currentPageIndex < _pages.length - 1
                      ? () {
                          setState(() {
                            _currentPageIndex++;
                          });
                        }
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12.0),

            // Theme Preset Selector row
            Text(
              'detail.background_style'.tr(),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8.0),
            Wrap(
              spacing: 12.0,
              runSpacing: 8.0,
              children: [
                // Presets
                ...List.generate(slideThemes.length, (index) {
                  final preset = slideThemes[index];
                  final isSelected = _backgroundType == 'preset' && _currentThemeIndex == index;
                  return GestureDetector(
                    onTap: _isAiGenerating
                        ? null
                        : () {
                            setState(() {
                              _backgroundType = 'preset';
                              _currentThemeIndex = index;
                            });
                          },
                    child: Container(
                      width: 32.0,
                      height: 32.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primaryContainer
                              : Colors.transparent,
                          width: 2.0,
                        ),
                      ),
                      padding: const EdgeInsets.all(2.0),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: preset.decoration.gradient,
                          color: preset.decoration.color,
                        ),
                      ),
                    ),
                  );
                }),

                // Gallery Image Selector
                GestureDetector(
                  onTap: _isAiGenerating ? null : _pickCustomImage,
                  child: Container(
                    width: 32.0,
                    height: 32.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _backgroundType == 'gallery'
                          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
                          : theme.colorScheme.surfaceContainerHigh,
                      border: Border.all(
                        color: _backgroundType == 'gallery'
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.outlineVariant,
                        width: 2.0,
                      ),
                    ),
                    child: Icon(
                      Icons.photo_library_rounded,
                      size: 16.0,
                      color: _backgroundType == 'gallery'
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

                // Unsplash Search Selector
                GestureDetector(
                  onTap: _isAiGenerating ? null : _showUnsplashSearchDialog,
                  child: Container(
                    width: 32.0,
                    height: 32.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _backgroundType == 'unsplash'
                          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
                          : theme.colorScheme.surfaceContainerHigh,
                      border: Border.all(
                        color: _backgroundType == 'unsplash'
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.outlineVariant,
                        width: 2.0,
                      ),
                    ),
                    child: Icon(
                      Icons.search_rounded,
                      size: 16.0,
                      color: _backgroundType == 'unsplash'
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20.0),

            // Font Style Section
            Text(
              'detail.font_style'.tr(),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8.0),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  'Lora',
                  'Outfit',
                  'Playfair Display',
                  'Inter',
                  'Montserrat',
                ].map((fontName) {
                  final isSelected = _selectedFontFamily == fontName;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      label: Text(
                        fontName,
                        style: GoogleFonts.getFont(
                          fontName,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12.0,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedFontFamily = fontName;
                            if (!_isModified) {
                              _paginate();
                            }
                          });
                        }
                      },
                      selectedColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                      checkmarkColor: theme.colorScheme.primaryContainer,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12.0),

            // Font Size Section
            Row(
              children: [
                Text(
                  'detail.font_size'.tr(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8.0),
                Text(
                  '${_contentFontSize.toInt()} px',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Icon(
                  Icons.format_size_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                Expanded(
                  child: Slider(
                    value: _contentFontSize,
                    min: 28.0,
                    max: 56.0,
                    divisions: 14,
                    activeColor: theme.colorScheme.primaryContainer,
                    onChanged: (val) {
                      setState(() {
                        _contentFontSize = val;
                        if (!_isModified) {
                          _paginate();
                        }
                      });
                    },
                  ),
                ),
                Icon(
                  Icons.format_size_rounded,
                  size: 24,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ],
            ),
            const SizedBox(height: 16.0),

            const Divider(height: 1),
            const SizedBox(height: 8.0),

            // Actions: Copy, Share Slides
            Row(
              children: [
                Text(
                  'detail.instagram_slides'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4.0),
            Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.auto_awesome_rounded, size: 20.0),
                  tooltip: 'detail.craft_ai_slides'.tr(),
                  color: const Color(0xFFFFE16D),
                  onPressed: _isAiGenerating ? null : _craftSlidesWithAi,
                ),
                if (_isModified)
                  IconButton(
                    icon: const Icon(Icons.settings_backup_restore_rounded, size: 20.0),
                    tooltip: 'detail.reset_slides_tooltip'.tr(),
                    onPressed: _isAiGenerating ? null : _resetSlides,
                  ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 20.0),
                  tooltip: 'detail.edit_slide_tooltip'.tr(),
                  onPressed: _isAiGenerating ? null : _editCurrentSlide,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20.0),
                  tooltip: 'detail.delete_slide_tooltip'.tr(),
                  color: theme.colorScheme.error,
                  onPressed: _isAiGenerating ? null : _deleteCurrentSlide,
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 20.0),
                  tooltip: 'detail.copy_all_tooltip'.tr(),
                  onPressed: _isAiGenerating ? null : _copySlidesText,
                ),
                _isSharing
                    ? const SizedBox(
                        width: 24.0,
                        height: 24.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.0,
                          color: Color(0xFFFFE16D),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send_rounded, size: 20.0),
                        tooltip: 'detail.share_tooltip'.tr(),
                        color: activeTheme.accentColor,
                        onPressed: _isAiGenerating ? null : _shareSlides,
                      ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSingleSlide({
    required int pageIndex,
    required String content,
    required SlideTheme theme,
  }) {
    if (content == 'OUTRO_SLIDE') {
      return _buildOutroSlide(theme);
    }
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 100.0, vertical: 80.0),
        decoration: _getSlideDecoration(theme),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Slide Title Header
            Text(
              widget.noteTitle.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.getFont(
                _selectedFontFamily,
                fontSize: _contentFontSize + 12.0,
                fontWeight: FontWeight.bold,
                color: theme.titleColor,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 24.0),

            // Divider line
            Container(
              width: 160.0,
              height: 4.0,
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),

            const Spacer(),

            // Content text area
            SizedBox(
              height: 600.0,
              child: Center(
                child: Text(
                  content,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.getFont(
                    _selectedFontFamily,
                    fontSize: _contentFontSize,
                    height: 1.7,
                    fontWeight: FontWeight.w400,
                    color: theme.textColor,
                  ),
                ),
              ),
            ),

            const Spacer(),

            // Footer brand & attribution
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left Brand
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: theme.accentColor,
                      size: 28.0,
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      'TowiTowi',
                      style: GoogleFonts.outfit(
                        fontSize: 28.0,
                        fontWeight: FontWeight.bold,
                        color: theme.titleColor.withValues(alpha: 0.8),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),

                // Right Attribution (aligned right to balance layout)
                if (_backgroundType == 'unsplash' && _unsplashPhotoAuthor != null)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Text(
                        'detail.unsplash_attribution'.tr(args: [_unsplashPhotoAuthor!]),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 20.0,
                          fontWeight: FontWeight.w400,
                          color: theme.titleColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  )
                else
                  const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutroSlide(SlideTheme theme) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 100.0, vertical: 100.0),
        decoration: _getSlideDecoration(theme),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Spacer(),
            // App Logo with premium border and shadow
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20.0,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40.0),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  width: 240.0,
                  height: 240.0,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 50.0),

            // Outro title
            Text(
              'TowiTowi',
              style: GoogleFonts.getFont(
                _selectedFontFamily,
                fontSize: _contentFontSize + 22.0,
                fontWeight: FontWeight.bold,
                color: theme.titleColor,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 30.0),

            // Main Outro Text
            Text(
              'detail.outro_text'.tr(),
              textAlign: TextAlign.center,
              style: GoogleFonts.getFont(
                _selectedFontFamily,
                fontSize: _contentFontSize,
                height: 1.6,
                fontWeight: FontWeight.w400,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 50.0),

            // Play Store CTA Badge / Button style
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
              decoration: BoxDecoration(
                color: theme.accentColor,
                borderRadius: BorderRadius.circular(50.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10.0,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'detail.outro_badge'.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 28.0,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0F2027),
                ),
              ),
            ),
            const Spacer(),

            // Outro footer for attribution
            if (_backgroundType == 'unsplash' && _unsplashPhotoAuthor != null) ...[
              const SizedBox(height: 24.0),
              Text(
                'detail.unsplash_attribution'.tr(args: [_unsplashPhotoAuthor!]),
                style: GoogleFonts.outfit(
                  fontSize: 22.0,
                  fontWeight: FontWeight.w400,
                  color: theme.titleColor.withValues(alpha: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  BoxDecoration _getSlideDecoration(SlideTheme theme) {
    if (_backgroundType == 'gallery' && _pickedImageFile != null) {
      return BoxDecoration(
        color: Colors.black,
        image: DecorationImage(
          image: FileImage(_pickedImageFile!),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.55),
            BlendMode.darken,
          ),
        ),
      );
    } else if (_backgroundType == 'unsplash' && _unsplashImageUrl != null) {
      return BoxDecoration(
        color: Colors.black,
        image: DecorationImage(
          image: NetworkImage(_unsplashImageUrl!),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.55),
            BlendMode.darken,
          ),
        ),
      );
    }
    return theme.decoration;
  }
}

Future<Map<String, String>?> searchUnsplashImage(String query) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse('https://unsplash.com/napi/search/photos?query=${Uri.encodeComponent(query)}&per_page=15');
    final request = await client.getUrl(uri);
    request.headers.set('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    request.headers.set('Accept', 'application/json, text/plain, */*');
    request.headers.set('Accept-Language', 'en-US,en;q=0.9');
    request.headers.set('Referer', 'https://unsplash.com/');
    final response = await request.close();
    if (response.statusCode == 200) {
      final responseBody = await response.transform(utf8.decoder).join();
      final json = jsonDecode(responseBody);
      final results = json['results'] as List<dynamic>;
      if (results.isNotEmpty) {
        final randomIndex = DateTime.now().millisecondsSinceEpoch % results.length;
        final photo = results[randomIndex];
        final urls = photo['urls'] as Map<String, dynamic>;
        final rawUrl = urls['regular'] as String;
        final user = photo['user'] as Map<String, dynamic>;
        final authorName = user['name'] as String;
        return {
          'url': '$rawUrl&w=1080&h=1080&fit=crop',
          'author': authorName,
        };
      }
    }
  } catch (e) {
    debugPrint('Error searching Unsplash: $e');
  } finally {
    client.close();
  }
  return null;
}

List<String> paginateText({
  required String text,
  required TextStyle style,
  required double maxWidth,
  required double maxHeight,
}) {
  final List<String> pages = [];
  final List<String> paragraphs = text.split('\n');

  StringBuffer currentPageText = StringBuffer();

  for (final paragraph in paragraphs) {
    if (paragraph.trim().isEmpty) {
      if (currentPageText.isNotEmpty) {
        currentPageText.write('\n\n');
      }
      continue;
    }

    final candidateText = currentPageText.isEmpty
        ? paragraph
        : '${currentPageText.toString()}\n\n$paragraph';

    final textPainter = TextPainter(
      text: TextSpan(text: candidateText, style: style),
      textDirection: ui.TextDirection.ltr,
    );

    textPainter.layout(maxWidth: maxWidth);

    if (textPainter.height > maxHeight) {
      if (currentPageText.isNotEmpty) {
        pages.add(currentPageText.toString());
        currentPageText = StringBuffer()..write(paragraph);
      } else {
        // If a single paragraph exceeds the page height, split it by words
        final words = paragraph.split(' ');
        StringBuffer currentWordBuffer = StringBuffer();
        for (final word in words) {
          final wordCandidate = currentWordBuffer.isEmpty
              ? word
              : '${currentWordBuffer.toString()} $word';
          final wordPainter = TextPainter(
            text: TextSpan(text: wordCandidate, style: style),
            textDirection: ui.TextDirection.ltr,
          );
          wordPainter.layout(maxWidth: maxWidth);
          if (wordPainter.height > maxHeight) {
            if (currentWordBuffer.isNotEmpty) {
              pages.add(currentWordBuffer.toString());
              currentWordBuffer = StringBuffer()..write(word);
            } else {
              currentWordBuffer.write(word);
            }
          } else {
            if (currentWordBuffer.isNotEmpty) {
              currentWordBuffer.write(' ');
            }
            currentWordBuffer.write(word);
          }
        }
        if (currentWordBuffer.isNotEmpty) {
          currentPageText = StringBuffer()..write(currentWordBuffer.toString());
        }
      }
    } else {
      if (currentPageText.isNotEmpty) {
        currentPageText.write('\n\n');
      }
      currentPageText.write(paragraph);
    }
  }

  if (currentPageText.isNotEmpty) {
    pages.add(currentPageText.toString());
  }

  return pages;
}
