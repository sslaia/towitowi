import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/note.dart';
import '../providers/settings_provider.dart';
import '../services/ai_content_service.dart';
import '../widgets/responsive_builder.dart';
import '../widgets/top_bar.dart';
import 'edit_screen.dart';

class DetailScreen extends StatefulWidget {
  final Note note;
  final VoidCallback? onEditPressed; // Null means we are on mobile (nav push)

  const DetailScreen({super.key, required this.note, this.onEditPressed});

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
  String? _shareSummary;

  // Loading states
  bool _isGeneratingBluesky = false;
  bool _isGeneratingMastodon = false;
  bool _isGeneratingFacebook = false;
  bool _isGeneratingShare = false;

  // Selected tab for the preview card (0: Share, 1: Facebook, 2: Mastodon, 3: Bluesky)
  int _selectedPreviewTab = 0;

  // Expandable FAB state
  bool _isFabExpanded = false;

  @override
  void initState() {
    super.initState();
    _initTts();
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
    super.dispose();
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
        ),
      );
      return;
    }

    setState(() {
      if (tab == 0) _isGeneratingShare = true;
      if (tab == 1) _isGeneratingFacebook = true;
      if (tab == 2) _isGeneratingMastodon = true;
      if (tab == 3) _isGeneratingBluesky = true;
    });

    try {
      final maxChars = tab == 0
          ? 200
          : (tab == 1 ? 300 : (tab == 2 ? 500 : 300));
      final includeHashtags = tab != 0;

      final result = await aiService.generateSocialSummary(
        textContent: widget.note.content,
        userApiKey: settingsProvider.geminiApiKey,
        maxCharacters: maxChars,
        includeHashtags: includeHashtags,
      );

      setState(() {
        if (tab == 0) _shareSummary = result;
        if (tab == 1) _facebookSummary = result;
        if (tab == 2) _mastodonSummary = result;
        if (tab == 3) _blueskySummary = result;
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
          if (tab == 0) _isGeneratingShare = false;
          if (tab == 1) _isGeneratingFacebook = false;
          if (tab == 2) _isGeneratingMastodon = false;
          if (tab == 3) _isGeneratingBluesky = false;
        });
      }
    }
  }

  void _shareToBluesky() async {
    if (_blueskySummary == null) {
      await _generatePreview(3);
    }
    if (_blueskySummary == null) return;

    _showSimulatedShareDialog('Bluesky', _blueskySummary!);
  }

  void _shareToMastodon() async {
    if (_mastodonSummary == null) {
      await _generatePreview(2);
    }
    if (_mastodonSummary == null) return;

    _showSimulatedShareDialog('Mastodon', _mastodonSummary!);
  }

  void _shareToFacebook() async {
    if (_facebookSummary == null) {
      await _generatePreview(1);
    }
    if (_facebookSummary == null) return;

    _showSimulatedShareDialog('Facebook', _facebookSummary!);
  }

  void _shareSystem() async {
    if (_shareSummary == null) {
      await _generatePreview(0);
    }
    if (_shareSummary == null) return;

    SharePlus.instance.share(
      ShareParams(text: _shareSummary!, subject: widget.note.title),
    );
  }

  void _showSimulatedShareDialog(String platform, String text) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => FutureBuilder(
        future: Future.delayed(const Duration(milliseconds: 1500)),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pop(context);
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${'detail.success_posted_to'.tr()} $platform!',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            });
            return const SizedBox.shrink();
          }

          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: theme.colorScheme.primaryContainer,
                ),
                const SizedBox(height: 20.0),
                Text(
                  '${'detail.sharing_to'.tr()} $platform...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12.0),
                Text(
                  text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          );
        },
      ),
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
                        builder: (context) => EditScreen(note: widget.note),
                      ),
                    );
                  } else {
                    widget.onEditPressed?.call();
                  }
                },
              ),
              const SizedBox(width: 8.0),
            ],
            border: true,
          ),
          body: SingleChildScrollView(
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
                          backgroundColor: Colors.white10,
                          color: const Color(0xFFFFE16D),
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: Colors.white10,
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
          // Custom Expandable Speed Dial FAB (located at bottom-right)
          floatingActionButton: _buildSpeedDialFab(context, settingsProvider),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        );
      },
    );
  }

  Widget? _buildSpeedDialFab(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) {
    final theme = Theme.of(context);

    // Only show the sharing FAB once at least one post text has been generated
    final hasAnySummary =
        _blueskySummary != null ||
        _mastodonSummary != null ||
        _facebookSummary != null ||
        _shareSummary != null;

    if (!hasAnySummary) return null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isFabExpanded) ...[
          // Share to... (system share sheet)
          if (_shareSummary != null) ...[
            _buildMiniFab(
              svgPath: 'assets/icon/share-icon.svg',
              label: 'detail.sharing_to'.tr(),
              backgroundColor: theme.colorScheme.primaryContainer,
              onPressed: () {
                setState(() {
                  _isFabExpanded = false;
                });
                _shareSystem();
              },
              theme: theme,
            ),
            const SizedBox(height: 12.0),
          ],

          // Share to Facebook
          if (_facebookSummary != null) ...[
            _buildMiniFab(
              svgPath: 'assets/icon/facebook-icon.svg',
              label: '${'detail.sharing_to'.tr()} Facebook',
              backgroundColor: const Color(0xFF0866FF),
              onPressed: () {
                setState(() {
                  _isFabExpanded = false;
                });
                _shareToFacebook();
              },
              theme: theme,
            ),
            const SizedBox(height: 12.0),
          ],

          // Share to Mastodon
          if (_mastodonSummary != null) ...[
            _buildMiniFab(
              svgPath: 'assets/icon/mastodon-icon.svg',
              label: '${'detail.sharing_to'.tr()} Mastodon',
              backgroundColor: const Color(0xFF6364FF),
              onPressed: () {
                setState(() {
                  _isFabExpanded = false;
                });
                _shareToMastodon();
              },
              theme: theme,
            ),
            const SizedBox(height: 12.0),
          ],

          // Share to Bluesky
          if (_blueskySummary != null) ...[
            _buildMiniFab(
              svgPath: 'assets/icon/bluesky-icon.svg',
              label: '${'detail.sharing_to'.tr()} Bluesky',
              backgroundColor: const Color(0xFF0085FF),
              onPressed: () {
                setState(() {
                  _isFabExpanded = false;
                });
                _shareToBluesky();
              },
              theme: theme,
            ),
            const SizedBox(height: 12.0),
          ],
        ],

        // Main Toggle FAB (Glassmorphic look)
        FloatingActionButton(
          heroTag: 'main_share_fab',
          backgroundColor: _isFabExpanded
              ? theme.colorScheme.errorContainer
              : theme.colorScheme.primaryContainer,
          foregroundColor: _isFabExpanded
              ? theme.colorScheme.onErrorContainer
              : theme.colorScheme.onPrimaryContainer,
          onPressed: () {
            setState(() {
              _isFabExpanded = !_isFabExpanded;
            });
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _isFabExpanded ? Icons.close : Icons.share_rounded,
              key: ValueKey<bool>(_isFabExpanded),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniFab({
    IconData? icon,
    String? svgPath,
    required String label,
    required Color backgroundColor,
    required VoidCallback onPressed,
    required ThemeData theme,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Premium glassmorphic/dark label next to mini FAB
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8.0),
        FloatingActionButton.small(
          heroTag: 'share_mini_$label',
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          onPressed: onPressed,
          child: svgPath != null
              ? SvgPicture.asset(
                  svgPath,
                  width: 24.0,
                  height: 24.0,
                  colorFilter: svgPath.contains('share-icon.svg')
                      ? const ColorFilter.mode(Colors.white, BlendMode.srcIn)
                      : null,
                )
              : Icon(icon),
        ),
      ],
    );
  }

  Widget _buildSocialPreviewCard(
    ThemeData theme,
    SettingsProvider settingsProvider,
  ) {
    final currentTab = _selectedPreviewTab;

    final String title;
    final String? cachedSummary;
    final bool isGenerating;
    final int maxChars;
    final String platformIconPath;
    final Color accentColor;

    if (currentTab == 0) {
      title = 'Share';
      cachedSummary = _shareSummary;
      isGenerating = _isGeneratingShare;
      maxChars = 200;
      platformIconPath = 'assets/icon/share-icon.svg';
      accentColor = const Color(0xFFFFE16D);
    } else if (currentTab == 1) {
      title = 'Facebook';
      cachedSummary = _facebookSummary;
      isGenerating = _isGeneratingFacebook;
      maxChars = 300;
      platformIconPath = 'assets/icon/facebook-icon.svg';
      accentColor = const Color(0xFF0866FF);
    } else if (currentTab == 2) {
      title = 'Mastodon';
      cachedSummary = _mastodonSummary;
      isGenerating = _isGeneratingMastodon;
      maxChars = 500;
      platformIconPath = 'assets/icon/mastodon-icon.svg';
      accentColor = const Color(0xFF6364FF);
    } else {
      title = 'Bluesky';
      cachedSummary = _blueskySummary;
      isGenerating = _isGeneratingBluesky;
      maxChars = 300;
      platformIconPath = 'assets/icon/bluesky-icon.svg';
      accentColor = const Color(0xFF0085FF);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.05,
        ),
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
                  _buildSocialTabButton(0, 'assets/icon/share-icon.svg', theme),
                  const SizedBox(width: 8.0),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 16.0),

          const Divider(height: 1, color: Colors.white10),

          // Content Area
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isGenerating
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
                              'Gemini is crafting your $title post...',
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
                              label: Text('Generate $title Post'),
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
                        // Render the generated post
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: SelectableText(
                            cachedSummary,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                              fontSize: 15.0,
                            ),
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
                                '$title summary',
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

                            // Copy Button
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 18.0),
                              tooltip: 'Copy to Clipboard',
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: cachedSummary!),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Copied post to clipboard!'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                            ),

                            // Regenerate Button
                            IconButton(
                              icon: const Icon(
                                Icons.refresh_rounded,
                                size: 18.0,
                              ),
                              tooltip: 'Regenerate',
                              onPressed: () => _generatePreview(currentTab),
                            ),

                            // Share Button
                            IconButton(
                              icon: const Icon(Icons.send_rounded, size: 18.0),
                              tooltip: 'Share / Post Now',
                              color: accentColor,
                              onPressed: () {
                                if (currentTab == 0) _shareSystem();
                                if (currentTab == 1) _shareToFacebook();
                                if (currentTab == 2) _shareToMastodon();
                                if (currentTab == 3) _shareToBluesky();
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
}
