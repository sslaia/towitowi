import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, MethodChannel, PlatformException;
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_content_service.dart';
import '../widgets/responsive_builder.dart';
import '../widgets/top_bar.dart';
import '../widgets/slide_preview_carousel.dart';
import 'edit_screen.dart';
import '../widgets/gemini_setup_dialog.dart';

class DetailScreen extends StatefulWidget {
  final Note note;
  final VoidCallback? onEditPressed; // Null means we are on mobile (nav push)
  final VoidCallback? onSettingsRedirect;

  const DetailScreen({
    super.key,
    required this.note,
    this.onEditPressed,
    this.onSettingsRedirect,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  // Cached AI social summaries
  String? _blueskySummary;
  String? _mastodonSummary;
  String? _facebookSummary;

  // Loading states
  bool _isGeneratingBluesky = false;
  bool _isGeneratingMastodon = false;
  bool _isGeneratingFacebook = false;

  String? _shareSummary;

  // Selected tab for the preview card (0: Share, 1: Facebook, 2: Mastodon, 3: Bluesky, 4: Instagram)
  int _selectedPreviewTab = 1;

  late final TextEditingController _postTextController;

  String _selectedFontFamily = 'Lora';
  final double _contentFontSize = 16.0; // Standard TextField size
  double _slideFontSize = 42.0;   // Slide preview size (matches Instagram defaults)
  TextAlign _selectedTextAlign = TextAlign.center;

  final GlobalKey _repaintKey = GlobalKey();

  String _backgroundType = 'preset'; // 'preset', 'gallery', 'unsplash'
  int _currentThemeIndex = 0;
  File? _pickedImageFile;
  String? _unsplashImageUrl;
  String? _unsplashPhotoAuthor;

  @override
  void initState() {
    super.initState();
    _initTts();
    _postTextController = TextEditingController();
    _updatePostTextController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
        if (settingsProvider.shouldShowGeminiSetupAlert) {
          showGeminiSetupDialog(context);
        }
      }
    });
  }

  void _updatePostTextController() {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final aiService = Provider.of<AiContentService>(context, listen: false);
    final hasAiKey = aiService.hasAnyConfiguredKey(settingsProvider.geminiApiKey);

    if (_selectedPreviewTab == 0) {
      _postTextController.text = _shareSummary ?? widget.note.content;
    } else if (_selectedPreviewTab == 1) {
      _postTextController.text = _facebookSummary ?? (hasAiKey ? '' : widget.note.content);
    } else if (_selectedPreviewTab == 2) {
      _postTextController.text = _mastodonSummary ?? (hasAiKey ? '' : widget.note.content);
    } else if (_selectedPreviewTab == 3) {
      _postTextController.text = _blueskySummary ?? (hasAiKey ? '' : widget.note.content);
    } else {
      _postTextController.text = '';
    }
  }

  void _initTts() {
    _flutterTts.setStartHandler(() {
      setState(() {
        _isSpeaking = true;
      });
    });

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });

    _flutterTts.setCancelHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });

    _flutterTts.setErrorHandler((message) {
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _postTextController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.note.content != widget.note.content ||
        oldWidget.note.title != widget.note.title) {
      _shareSummary = null;
      _facebookSummary = null;
      _mastodonSummary = null;
      _blueskySummary = null;
      _updatePostTextController();
    }
  }

  Future<void> _toggleSpeech() async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() {
        _isSpeaking = false;
      });
    } else {
      try {
        await _flutterTts.setLanguage(context.locale.languageCode);
      } catch (e) {
        debugPrint('Error setting language: $e');
      }
      if (widget.note.content.isNotEmpty) {
        await _flutterTts.speak(widget.note.content);
      }
    }
  }

  Future<void> _generatePreview(int tab) async {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final aiService = Provider.of<AiContentService>(context, listen: false);

    if (!aiService.hasAnyConfiguredKey(settingsProvider.geminiApiKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('detail.gemini_not_configured'.tr()),
          backgroundColor: Colors.redAccent,
          action: SnackBarAction(
            label: 'nav.settings'.tr(),
            textColor: const Color(0xFFFFE16D),
            onPressed: () {
              widget.onSettingsRedirect?.call();
            },
          ),
        ),
      );
      return;
    }

    setState(() {
      if (tab == 1) _isGeneratingFacebook = true;
      if (tab == 2) _isGeneratingMastodon = true;
      if (tab == 3) _isGeneratingBluesky = true;
    });

    try {
      final maxChars = tab == 1 ? 300 : (tab == 2 ? 500 : 300);
      final includeHashtags = true;

      final result = await aiService.generateSocialSummary(
        textContent: widget.note.content,
        userApiKey: settingsProvider.geminiApiKey,
        maxCharacters: maxChars,
        includeHashtags: includeHashtags,
      );

      setState(() {
        if (tab == 1) _facebookSummary = result;
        if (tab == 2) _mastodonSummary = result;
        if (tab == 3) _blueskySummary = result;
        _updatePostTextController();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${'detail.failed_to_generate_summary:'.tr()} ${e.toString()}',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (tab == 1) _isGeneratingFacebook = false;
          if (tab == 2) _isGeneratingMastodon = false;
          if (tab == 3) _isGeneratingBluesky = false;
        });
      }
    }
  }





  Future<void> _launchIntent(String url, String fallbackText) async {
    try {
      final Uri uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await Share.share(fallbackText);
      }
    } catch (e) {
      debugPrint('Error launching intent: $e');
      await Share.share(fallbackText);
    }
  }

  void _shareToBluesky() async {
    if (_blueskySummary == null) {
      await _generatePreview(3);
    }
    if (_blueskySummary == null) return;

    final url = 'https://bsky.app/intent/compose?text=${Uri.encodeComponent(_blueskySummary!)}';
    await _launchIntent(url, _blueskySummary!);
  }

  void _shareToMastodon() async {
    if (_mastodonSummary == null) {
      await _generatePreview(2);
    }
    if (_mastodonSummary == null) return;

    final url = 'https://mastodonshare.org/?text=${Uri.encodeComponent(_mastodonSummary!)}';
    await _launchIntent(url, _mastodonSummary!);
  }

  void _shareToFacebook() async {
    if (_facebookSummary == null) {
      await _generatePreview(1);
    }
    if (_facebookSummary == null) return;

    final url = 'https://www.facebook.com/sharer/sharer.php?quote=${Uri.encodeComponent(_facebookSummary!)}';
    await _launchIntent(url, _facebookSummary!);
  }

  void _shareSystem() async {
    final String title = widget.note.title;
    final String dateStr = widget.note.formattedDate;
    final String noteContent = _shareSummary ?? widget.note.content;
    final String footer = 'detail.share_footer'.tr();
    final String sharedText = '$title\n$dateStr\n\n$noteContent\n\n$footer';

    Share.share(
      sharedText,
      subject: title,
    );
  }

  void _confirmDeleteNote() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text(
            'detail.delete_confirm_title'.tr(),
            style: TextStyle(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'detail.delete_confirm_message'.tr(),
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'detail.cancel'.tr(),
                style: TextStyle(color: theme.colorScheme.secondaryContainer),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              onPressed: () async {
                Navigator.pop(context); // pop dialog
                
                final notesProvider = Provider.of<NotesProvider>(context, listen: false);
                await notesProvider.deleteNote(widget.note.id);
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'detail.delete_success'.tr(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                      backgroundColor: theme.colorScheme.primaryContainer,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  );

                  if (Navigator.canPop(context)) {
                    Navigator.pop(context); // pop DetailScreen (on mobile)
                  }
                }
              },
              child: Text('detail.delete'.tr()),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return ResponsiveBuilder(
      builder: (context, layout) {
        final isMobile = layout.isMobile;

        return Scaffold(
          appBar: TopBar(
            title: 'app_title'.tr(),
            leading: isMobile
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  )
                : null,
            actions: [
              IconButton(
                icon: Icon(
                  settingsProvider.isBookmarked(widget.note.id)
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: settingsProvider.isBookmarked(widget.note.id)
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.onSurface,
                ),
                tooltip: settingsProvider.isBookmarked(widget.note.id)
                    ? 'detail.unbookmarked'.tr()
                    : 'detail.bookmarked'.tr(),
                onPressed: () async {
                  final wasBookmarked = settingsProvider.isBookmarked(
                    widget.note.id,
                  );
                  await settingsProvider.toggleBookmark(widget.note.id);

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        !wasBookmarked
                            ? 'detail.bookmarked'.tr()
                            : 'detail.unbookmarked'.tr(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                      backgroundColor: theme.colorScheme.primaryContainer,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8.0),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'detail.edit_note_tooltip'.tr(),
                onPressed: () {
                  if (isMobile) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditScreen(
                          note: widget.note,
                          onSettingsRedirect: () {
                            Navigator.pop(context); // Pop EditScreen
                            widget.onSettingsRedirect?.call();
                          },
                        ),
                      ),
                    );
                  } else {
                    widget.onEditPressed?.call();
                  }
                },
              ),
              const SizedBox(width: 8.0),
              IconButton(
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: theme.colorScheme.error,
                ),
                tooltip: 'detail.delete_note_tooltip'.tr(),
                onPressed: _confirmDeleteNote,
              ),
              const SizedBox(width: 8.0),
            ],
            border: true,
          ),
          body: Stack(
            clipBehavior: Clip.none,
            children: [
              // Offscreen render area for image export capturing
              Positioned(
                left: -2000.0,
                top: 0.0,
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: SizedBox(
                    width: 1080.0,
                    child: _buildSingleSlidePreview(
                      content: _postTextController.text,
                      theme: slideThemes[_currentThemeIndex],
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 800.0),
                    padding: EdgeInsets.symmetric(
                      horizontal: layout.margin,
                      vertical: 48.0,
                    ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Metadata row
                    Row(
                      children: [
                        Container(
                          width: 6.0,
                          height: 6.0,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Text(
                          widget.note.label.toUpperCase(),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontSize: 12.0,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            '/',
                            style: TextStyle(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                        Text(
                          widget.note.formattedDate,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                            fontSize: 12.0,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32.0),

                    // Title
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            widget.note.title,
                            style: theme.textTheme.displayLarge?.copyWith(
                              fontSize: isMobile ? 36.0 : 56.0,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16.0),
                        IconButton(
                          icon: Icon(
                            _isSpeaking
                                ? Icons.stop_rounded
                                : Icons.volume_up_rounded,
                            color: theme.colorScheme.primaryContainer,
                            size: isMobile ? 28.0 : 36.0,
                          ),
                          tooltip: _isSpeaking
                              ? 'detail.stop_tooltip'.tr()
                              : 'detail.listen_tooltip'.tr(),
                          onPressed: _toggleSpeech,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),

                    // Word count
                    Text(
                      'detail.word_count'.tr(
                        args: [widget.note.wordCount.toString()],
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 48.0),

                    // Body Content (Markdown)
                    MarkdownBody(
                      data: widget.note.content,
                      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                        p: theme.textTheme.bodyLarge?.copyWith(
                          height: 1.8,
                          fontSize: 18.0,
                        ),
                        h1: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primaryContainer,
                        ),
                        h2: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primaryContainer,
                        ),
                        h3: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primaryContainer,
                        ),
                        listBullet: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.primaryContainer,
                        ),
                        code: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          backgroundColor: theme.colorScheme.surfaceContainerHigh,
                          color: theme.brightness == Brightness.dark
                              ? const Color(0xFFFFE16D)
                              : theme.colorScheme.secondary,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48.0),
                    _buildSocialPreviewCard(theme, settingsProvider),
                  ],
                ),
              ),
            ),
          ),
            ],
          ),
        );
      },
    );
  }


  Widget _buildSocialPreviewCard(
    ThemeData theme,
    SettingsProvider settingsProvider,
  ) {
    final aiService = Provider.of<AiContentService>(context, listen: false);
    final hasAiKey = aiService.hasAnyConfiguredKey(settingsProvider.geminiApiKey);
    final currentTab = _selectedPreviewTab;

    final String title;
    final String? cachedSummary;
    final bool isGenerating;
    final int maxChars;
    final String platformIconPath;
    final Color accentColor;

    if (currentTab == 0) {
      title = 'detail.tab_share'.tr();
      cachedSummary = _shareSummary ?? widget.note.content;
      isGenerating = false;
      maxChars = (_shareSummary ?? widget.note.content).length;
      platformIconPath = 'assets/icon/share-icon.svg';
      accentColor = const Color(0xFFFFE16D);
    } else if (currentTab == 1) {
      title = 'detail.tab_facebook'.tr();
      cachedSummary = _facebookSummary ?? (hasAiKey ? null : widget.note.content);
      isGenerating = _isGeneratingFacebook;
      maxChars = 300;
      platformIconPath = 'assets/icon/facebook-icon.svg';
      accentColor = const Color(0xFF0866FF);
    } else if (currentTab == 2) {
      title = 'detail.tab_mastodon'.tr();
      cachedSummary = _mastodonSummary ?? (hasAiKey ? null : widget.note.content);
      isGenerating = _isGeneratingMastodon;
      maxChars = 500;
      platformIconPath = 'assets/icon/mastodon-icon.svg';
      accentColor = const Color(0xFF6364FF);
    } else if (currentTab == 3) {
      title = 'detail.tab_bluesky'.tr();
      cachedSummary = _blueskySummary ?? (hasAiKey ? null : widget.note.content);
      isGenerating = _isGeneratingBluesky;
      maxChars = 300;
      platformIconPath = 'assets/icon/bluesky-icon.svg';
      accentColor = const Color(0xFF0085FF);
    } else {
      title = 'detail.tab_instagram'.tr();
      cachedSummary = '';
      isGenerating = false;
      maxChars = 0;
      platformIconPath = 'assets/icon/instagram-icon.svg';
      accentColor = const Color(0xFFE1306C);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header of Social Preview Card
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 12.0),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: theme.colorScheme.primaryContainer,
                  size: 20.0,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    'detail.social_preview'.tr(),
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: 12.0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Custom Tab Bar for Platforms (Scrollable horizontally to prevent overflow)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSocialTabButton(
                    1,
                    'assets/icon/facebook-icon.svg',
                    theme,
                  ),
                  const SizedBox(width: 8.0),
                  _buildSocialTabButton(
                    2,
                    'assets/icon/mastodon-icon.svg',
                    theme,
                  ),
                  const SizedBox(width: 8.0),
                  _buildSocialTabButton(
                    3,
                    'assets/icon/bluesky-icon.svg',
                    theme,
                  ),
                  const SizedBox(width: 8.0),
                  _buildSocialTabButton(
                    4,
                    'assets/icon/instagram-icon.svg',
                    theme,
                  ),
                  const SizedBox(width: 8.0),
                  _buildSocialTabButton(0, 'assets/icon/share-icon.svg', theme),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16.0),

          Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),

          // Content Area
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: currentTab == 4
                  ? SlidePreviewCarousel(
                      key: ValueKey('instagram_${widget.note.id}'),
                      noteTitle: widget.note.title,
                      noteContent: widget.note.content,
                    )
                  : isGenerating
                      ? Center(
                          key: ValueKey('loading_$currentTab'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32.0),
                            child: Column(
                              children: [
                                const CircularProgressIndicator(
                                  color: Color(0xFFFFE16D),
                                ),
                                const SizedBox(height: 16.0),
                                Text(
                                  'detail.gemini_crafting'.tr(args: [title]),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: theme.colorScheme.onSurface.withValues(
                                      alpha: 0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : cachedSummary == null
                          ? Center(
                              key: ValueKey('empty_$currentTab'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24.0),
                                child: Column(
                                  children: [
                                    Text(
                                      'detail.no_preview'.tr(args: [title]),
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurface.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16.0),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            theme.colorScheme.primaryContainer,
                                        foregroundColor:
                                            theme.colorScheme.onPrimaryContainer,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8.0),
                                        ),
                                      ),
                                      icon: const Icon(Icons.auto_awesome, size: 16.0),
                                      label: Text('detail.generate_post'.tr(args: [title])),
                                      onPressed: () => _generatePreview(currentTab),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Column(
                              key: ValueKey('content_$currentTab'),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (currentTab != 0) ...[
                                  // Visual card preview container (FittedBox fits 1080w dynamic h cleanly on screen)
                                  Center(
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
                                        child: FittedBox(
                                          fit: BoxFit.contain,
                                          child: SizedBox(
                                            width: 1080.0,
                                            child: _buildSingleSlidePreview(
                                              content: _postTextController.text,
                                              theme: slideThemes[_currentThemeIndex],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20.0),

                                  // Background Style Selector (Presets + gallery + unsplash)
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
                                        onTap: () {
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
                                      onTap: _pickCustomImage,
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
                                      onTap: _showUnsplashSearchDialog,
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
                                const SizedBox(height: 16.0),

                                // Typography controls for Facebook, Mastodon, Bluesky, Share
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
                                      '${_slideFontSize.toInt()} px',
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
                                        value: _slideFontSize,
                                        min: 28.0,
                                        max: 56.0,
                                        divisions: 14,
                                        activeColor: theme.colorScheme.primaryContainer,
                                        onChanged: (val) {
                                          setState(() {
                                            _slideFontSize = val;
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
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'detail.text_align'.tr(),
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 6.0),
                                    Row(
                                      children: ['left', 'center', 'right'].map((align) {
                                        final isSelected = (align == 'left' && _selectedTextAlign == TextAlign.left) ||
                                            (align == 'center' && _selectedTextAlign == TextAlign.center) ||
                                            (align == 'right' && _selectedTextAlign == TextAlign.right);
                                        return Padding(
                                          padding: const EdgeInsets.only(right: 8.0),
                                          child: IconButton(
                                            icon: Icon(
                                              align == 'left'
                                                  ? Icons.format_align_left_rounded
                                                  : align == 'center'
                                                      ? Icons.format_align_center_rounded
                                                      : Icons.format_align_right_rounded,
                                              color: isSelected ? theme.colorScheme.primaryContainer : theme.colorScheme.onSurfaceVariant,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                if (align == 'left') _selectedTextAlign = TextAlign.left;
                                                if (align == 'center') _selectedTextAlign = TextAlign.center;
                                                if (align == 'right') _selectedTextAlign = TextAlign.right;
                                              });
                                            },
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16.0),
                                  ],

                                // Render the generated post editor
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16.0),
                                  decoration: BoxDecoration(
                                    color: theme.brightness == Brightness.dark
                                        ? Colors.black38
                                        : theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12.0),
                                    border: Border.all(
                                      color: accentColor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _postTextController,
                                    maxLines: null,
                                    selectAllOnFocus: false,
                                    style: currentTab == 0
                                        ? theme.textTheme.bodyMedium?.copyWith(
                                            height: 1.5,
                                            fontSize: 15.0,
                                          )
                                        : GoogleFonts.getFont(
                                            _selectedFontFamily,
                                            fontSize: _contentFontSize,
                                            height: 1.5,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                    cursorColor: theme.colorScheme.primaryContainer,
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        if (currentTab == 0) {
                                          _shareSummary = val;
                                        } else if (currentTab == 1) {
                                          _facebookSummary = val;
                                        } else if (currentTab == 2) {
                                          _mastodonSummary = val;
                                        } else if (currentTab == 3) {
                                          _blueskySummary = val;
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16.0),

                                // Stats & Action buttons row
                                Row(
                                  children: [
                                    // Platform indicator and count
                                    SvgPicture.asset(
                                      platformIconPath,
                                      width: 24.0,
                                      height: 24.0,
                                      colorFilter:
                                          platformIconPath.contains('share-icon.svg')
                                          ? ColorFilter.mode(
                                              accentColor,
                                              BlendMode.srcIn,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 6.0),
                                    Expanded(
                                      child: Text(
                                        currentTab == 0
                                            ? 'detail.whole_note'.tr()
                                            : 'detail.platform_summary'.tr(args: [title]),
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurface.withValues(
                                            alpha: 0.6,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8.0),

                                    // Character count
                                    if (currentTab != 0) ...[
                                      Text(
                                        '${cachedSummary.length}/$maxChars',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: cachedSummary.length <= maxChars
                                              ? Colors.green
                                              : Colors.redAccent,
                                        ),
                                      ),
                                      const SizedBox(width: 16.0),
                                    ] else ...[
                                      Text(
                                        '${cachedSummary.length}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                      const SizedBox(width: 16.0),
                                    ],

                                    // Copy Button
                                    IconButton(
                                      icon: const Icon(Icons.copy_rounded, size: 18.0),
                                      tooltip: 'detail.copy_tooltip'.tr(),
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: cachedSummary!),
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              currentTab == 0
                                                  ? 'detail.copied_whole_note'.tr()
                                                  : 'detail.copied_post'.tr(),
                                            ),
                                            duration: const Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                    ),

                                    // Regenerate Button
                                    if (currentTab != 0 && hasAiKey)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.refresh_rounded,
                                          size: 18.0,
                                        ),
                                        tooltip: 'detail.regenerate_tooltip'.tr(),
                                        onPressed: () => _generatePreview(currentTab),
                                      ),

                                    // Share Button
                                    IconButton(
                                      icon: const Icon(Icons.send_rounded, size: 18.0),
                                      tooltip: 'detail.share_tooltip'.tr(),
                                      color: accentColor,
                                      onPressed: () {
                                        if (currentTab == 0) {
                                          _shareSystem();
                                        } else {
                                          _showShareOptionsDialog(
                                            onShareText: () {
                                              if (currentTab == 1) {
                                                _shareToFacebook();
                                              } else if (currentTab == 2) {
                                                _shareToMastodon();
                                              } else if (currentTab == 3) {
                                                _shareToBluesky();
                                              }
                                            },
                                            onShareImage: _shareSocialAsImage,
                                            onSaveDisk: _saveSocialAsImageToDisk,
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialTabButton(int tab, String svgPath, ThemeData theme) {
    final isSelected = _selectedPreviewTab == tab;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPreviewTab = tab;
          _updatePostTextController();
        });
      },
      borderRadius: BorderRadius.circular(20.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : Colors.transparent,
          ),
        ),
        child: Opacity(
          opacity: isSelected ? 1.0 : 0.4,
          child: SvgPicture.asset(
            svgPath,
            width: 24.0,
            height: 24.0,
            colorFilter: svgPath.contains('share-icon.svg')
                ? ColorFilter.mode(
                    isSelected
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    BlendMode.srcIn,
                  )
                : null,
          ),
        ),
      ),
    );
  }

  // --- NEW HELPERS FOR BACKGROUND STYLES & IMAGE SHARING ---

  Widget _buildSingleSlidePreview({
    required String content,
    required SlideTheme theme,
  }) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 100.0, vertical: 80.0),
        decoration: _getSlideDecoration(theme),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: _selectedTextAlign == TextAlign.left
              ? CrossAxisAlignment.start
              : _selectedTextAlign == TextAlign.right
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.center,
          children: [
            // Slide Title Header
            Text(
              widget.note.title.toUpperCase(),
              textAlign: _selectedTextAlign,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.getFont(
                _selectedFontFamily,
                fontSize: _slideFontSize + 12.0,
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

            const SizedBox(height: 48.0),

            // Content text area - dynamic height
            Text(
              content,
              textAlign: _selectedTextAlign,
              style: GoogleFonts.getFont(
                _selectedFontFamily,
                fontSize: _slideFontSize,
                height: 1.7,
                fontWeight: FontWeight.w400,
                color: theme.textColor,
              ),
            ),

            const SizedBox(height: 48.0),

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
            selectAllOnFocus: false,
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('detail.searching_web'.tr()),
        duration: const Duration(seconds: 1),
      ),
    );

    final result = await searchUnsplashImage(query);

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

  static const MethodChannel _saveFileChannel = MethodChannel('io.github.sslaia.towitowi/save_file');

  Future<bool> _saveToDownloadsAndroid(String filePath, String fileName) async {
    try {
      final bool success = await _saveFileChannel.invokeMethod('saveToDownloads', {
        'filePath': filePath,
        'fileName': fileName,
      });
      return success;
    } on PlatformException catch (e) {
      debugPrint('Error saving file to downloads: $e');
      return false;
    }
  }

  Future<File?> _captureAndSaveImageHelper() async {
    final tempDir = await getTemporaryDirectory();

    // Give a tiny frame delay to make sure the offscreen boundary is laid out
    await Future.delayed(const Duration(milliseconds: 150));

    final RenderRepaintBoundary? boundary =
        _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

    if (boundary == null) {
      throw Exception("Render boundary not found");
    }

    final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception("Failed to generate image bytes");
    }

    final Uint8List pngBytes = byteData.buffer.asUint8List();
    final String fileName =
        'towitowi_post_${_selectedPreviewTab}_${DateTime.now().millisecondsSinceEpoch}.png';

    // Write to temporary directory first
    final File tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(pngBytes);

    // Save persistently to local storage in background
    if (Platform.isAndroid) {
      await _saveToDownloadsAndroid(tempFile.path, fileName);
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
        await tempFile.copy(file.path);
      }
    }

    return tempFile;
  }

  Future<void> _shareSocialAsImage() async {
    try {
      final file = await _captureAndSaveImageHelper();
      if (file != null) {
        // Trigger system share sheet with the file
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'detail.share_slides_text'.tr(),
        );
      }
    } catch (e) {
      debugPrint('Error sharing post as image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('detail.error_msg'.tr(args: [e.toString()])),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _saveSocialAsImageToDisk() async {
    try {
      final file = await _captureAndSaveImageHelper();
      if (file != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('detail.slides_saved_count'.tr(args: ["1"])),
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception("Failed to save image");
      }
    } catch (e) {
      debugPrint('Error saving post as image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('detail.failed_to_save'.tr()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showShareOptionsDialog({
    required VoidCallback onShareText,
    required VoidCallback onShareImage,
    required VoidCallback onSaveDisk,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'detail.share_options_title'.tr(),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20.0),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
                  icon: const Icon(Icons.text_fields_rounded),
                  label: Text('detail.share_as_text'.tr()),
                  onPressed: () {
                    Navigator.pop(context);
                    onShareText();
                  },
                ),
                const SizedBox(height: 12.0),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.primaryContainer,
                    side: BorderSide(color: theme.colorScheme.primaryContainer),
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
                  icon: const Icon(Icons.image_rounded),
                  label: Text('detail.share_as_image'.tr()),
                  onPressed: () {
                    Navigator.pop(context);
                    onShareImage();
                  },
                ),
                const SizedBox(height: 12.0),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.primaryContainer,
                    side: BorderSide(color: theme.colorScheme.primaryContainer),
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: Text('detail.share_save_disk'.tr()),
                  onPressed: () {
                    Navigator.pop(context);
                    onSaveDisk();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
