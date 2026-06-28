import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/settings_provider.dart';
import '../widgets/responsive_builder.dart';

class OnboardingScreen extends StatefulWidget {
  final bool isReplay;
  const OnboardingScreen({super.key, this.isReplay = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _numPages = 4;

  // Controllers for API key and sample text
  late final TextEditingController _apiKeyController;
  late final TextEditingController _sampleController;

  // Animations
  late final AnimationController _floatingController;
  late final AnimationController _birdChirpController;
  late final Animation<double> _birdScaleAnimation;
  late final Animation<double> _birdRotateAnimation;

  // List of active chirp messages floating on screen
  final List<_FloatingChirp> _floatingChirps = [];
  final List<String> _chirpPhrasesEn = [
    'Chirp Chirp! 🐦',
    'Towi Towi! 🎵',
    'Good News! 🌟',
    'Have you Towi-ed? 📝',
    'Happiness! ✨',
    'Start Writing! ✍️',
  ];
  final List<String> _chirpPhrasesId = [
    'Kicau Kicau! 🐦',
    'Towi Towi! 🎵',
    'Kabar Baik! 🌟',
    'Sudah Ber-towi? 📝',
    'Kebahagiaan! ✨',
    'Mulai Menulis! ✍️',
  ];
  int _chirpIndex = 0;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _apiKeyController = TextEditingController(text: settings.geminiApiKey);

    // Get sample text of active language
    final initialSamples = settings.getWritingStyleSamples(settings.isOnboardingCompleted ? 'en' : 'en');
    _sampleController = TextEditingController(
      text: initialSamples.isNotEmpty ? initialSamples.first : '',
    );

    // Floating micro-animation for page elements
    _floatingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    // Bird chirp recoil/bounce animation
    _birdChirpController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _birdScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.15), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _birdChirpController, curve: Curves.easeInOut));

    _birdRotateAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.15), weight: 40),
      TweenSequenceItem(tween: Tween(begin: -0.15, end: 0.15), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.15, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _birdChirpController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _apiKeyController.dispose();
    _sampleController.dispose();
    _floatingController.dispose();
    _birdChirpController.dispose();
    super.dispose();
  }

  void _onLanguageSelected(BuildContext context, String langCode) {
    context.setLocale(Locale(langCode));
    // Synchronize writing style sample field with selected language default/existing sample
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final samples = settings.getWritingStyleSamples(langCode);
    setState(() {
      _sampleController.text = samples.isNotEmpty ? samples.first : '';
    });
  }

  void _handleGeminiKeyChange(String key) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    settings.setGeminiApiKey(key);
  }

  void _handleSampleChange(String text) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final langCode = context.locale.languageCode;
    final currentSamples = List<String>.from(settings.getWritingStyleSamples(langCode));
    if (currentSamples.isEmpty) {
      currentSamples.add(text);
    } else {
      currentSamples[0] = text;
    }
    settings.setWritingStyleSamples(langCode, currentSamples);
  }

  void _completeOnboarding() {
    if (widget.isReplay) {
      Navigator.pop(context);
    } else {
      Provider.of<SettingsProvider>(context, listen: false).completeOnboarding();
    }
  }

  void _triggerBirdChirp() {
    _birdChirpController.forward(from: 0.0);

    // Get phrase in active language
    final phrases = context.locale.languageCode == 'id' ? _chirpPhrasesId : _chirpPhrasesEn;
    final phrase = phrases[_chirpIndex % phrases.length];
    _chirpIndex++;

    final random = math.Random();
    final newChirp = _FloatingChirp(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: phrase,
      leftOffset: random.nextDouble() * 160.0 - 80.0, // centered relative horizontal drift
      startBottom: 120.0,
      targetBottom: 220.0 + random.nextDouble() * 60.0,
    );

    setState(() {
      _floatingChirps.add(newChirp);
    });

    // Remove chirp from tree after 1.5 seconds
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _floatingChirps.removeWhere((c) => c.id == newChirp.id);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ResponsiveBuilder(
      builder: (context, layout) {
        final double contentWidth = layout.isMobile ? double.infinity : 600.0;
        final double contentHeight = layout.isMobile ? double.infinity : 750.0;

        return Scaffold(
          body: Container(
            color: theme.scaffoldBackgroundColor,
            child: Stack(
              children: [
                // Diagonal background accent glows
                Positioned(
                  top: -150,
                  right: -150,
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.03),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -150,
                  left: -150,
                  child: Container(
                    width: 450,
                    height: 450,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.03),
                    ),
                  ),
                ),

                // Main Page Content centered on Desktop, full screen on Mobile
                Center(
                  child: Container(
                    width: contentWidth,
                    height: contentHeight,
                    margin: layout.isMobile ? EdgeInsets.zero : const EdgeInsets.all(32.0),
                    decoration: layout.isMobile
                        ? null
                        : BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(24.0),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: theme.brightness == Brightness.dark ? 0.5 : 0.1,
                                ),
                                blurRadius: 40.0,
                                spreadRadius: 10.0,
                              ),
                            ],
                          ),
                    child: SafeArea(
                      child: Column(
                        children: [
                          // Top bar with App Logo (Page 1-3) / Replay Close button
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: Image.asset(
                                        'assets/icon/app_icon.png',
                                        width: 32.0,
                                        height: 32.0,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 12.0),
                                    Text(
                                      'app_title'.tr(),
                                      style: theme.textTheme.headlineMedium?.copyWith(
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                if (widget.isReplay)
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    onPressed: () => Navigator.pop(context),
                                    tooltip: 'Close Tutorial',
                                  )
                                else
                                  TextButton(
                                    onPressed: _completeOnboarding,
                                    child: Text(
                                      'onboarding.skip'.tr().toUpperCase(),
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.0,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2), height: 1.0),

                          // Pages Scrollview
                          Expanded(
                            child: PageView(
                              controller: _pageController,
                              onPageChanged: (pageIndex) {
                                setState(() {
                                  _currentPage = pageIndex;
                                });
                              },
                              children: [
                                _buildIntroPage(theme, layout),
                                _buildGeminiPage(theme),
                                _buildCustomizePage(theme, layout),
                                _buildLorePage(theme, layout),
                              ],
                            ),
                          ),

                          // Bottom navigation and indicators
                          Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2), height: 1.0),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Back button
                                SizedBox(
                                  width: 80.0,
                                  child: _currentPage > 0
                                      ? TextButton(
                                          onPressed: () {
                                            _pageController.previousPage(
                                              duration: const Duration(milliseconds: 300),
                                              curve: Curves.easeInOut,
                                            );
                                          },
                                          child: Text(
                                            'onboarding.back'.tr().toUpperCase(),
                                            style: theme.textTheme.labelLarge?.copyWith(
                                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.0,
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ),

                                // Page Indicator dots
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: List.generate(_numPages, (index) {
                                    final isActive = _currentPage == index;
                                    return AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      margin: const EdgeInsets.symmetric(horizontal: 5.0),
                                      height: 6.0,
                                      width: isActive ? 24.0 : 6.0,
                                      decoration: BoxDecoration(
                                        color: isActive
                                            ? theme.colorScheme.primaryContainer
                                            : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(3.0),
                                      ),
                                    );
                                  }),
                                ),

                                // Next / Get Started button
                                SizedBox(
                                  width: 80.0,
                                  child: TextButton(
                                    onPressed: () {
                                      if (_currentPage < _numPages - 1) {
                                        _pageController.nextPage(
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        );
                                      } else {
                                        _completeOnboarding();
                                      }
                                    },
                                    child: Text(
                                      (_currentPage == _numPages - 1
                                              ? 'onboarding.start'
                                              : 'onboarding.next')
                                          .tr()
                                          .toUpperCase(),
                                      style: theme.textTheme.labelLarge?.copyWith(
                                        color: theme.colorScheme.primaryContainer,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
        );
      },
    );
  }

  // --- SLIDE 1: INTRO & LANGUAGE ---
  Widget _buildIntroPage(ThemeData theme, ResponsiveLayout layout) {
    final currentLocale = context.locale;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        children: [
          const SizedBox(height: 24.0),
          // Float Animation wrapper for main graphic
          AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 8.0 * math.sin(_floatingController.value * 2 * math.pi)),
                child: child,
              );
            },
            child: Container(
              width: 130.0,
              height: 130.0,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28.0),
                border: Border.all(
                  color: theme.colorScheme.primaryContainer,
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
                    blurRadius: 30.0,
                    spreadRadius: 2.0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26.0),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 36.0),
          Text(
            'onboarding.intro_title'.tr(),
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: 28.0,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16.0),
          Text(
            'onboarding.intro_desc'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48.0),

          // Bilingual Toggle Header
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'onboarding.language_title'.tr().toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.secondaryContainer,
                letterSpacing: 1.5,
                fontSize: 11.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16.0),

          // Language Cards Row
          Row(
            children: [
              Expanded(
                child: _buildLangSelectorCard(
                  label: 'English',
                  localeCode: 'en',
                  isActive: currentLocale.languageCode == 'en',
                  theme: theme,
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: _buildLangSelectorCard(
                  label: 'Bahasa Indonesia',
                  localeCode: 'id',
                  isActive: currentLocale.languageCode == 'id',
                  theme: theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLangSelectorCard({
    required String label,
    required String localeCode,
    required bool isActive,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: () => _onLanguageSelected(context, localeCode),
      borderRadius: BorderRadius.circular(12.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18.0),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.05)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isActive
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
            width: isActive ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Text(
              localeCode.toUpperCase(),
              style: TextStyle(
                fontSize: 22.0,
                fontWeight: FontWeight.bold,
                color: isActive
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              label,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: theme.colorScheme.onSurface,
                fontSize: 14.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SLIDE 2: AI / GEMINI ---
  Widget _buildGeminiPage(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        children: [
          const SizedBox(height: 36.0),
          // Animated Glowing Spark
          AnimatedBuilder(
            animation: _floatingController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, 6.0 * math.sin(_floatingController.value * 2 * math.pi)),
                child: Transform.scale(
                  scale: 1.0 + 0.05 * math.cos(_floatingController.value * 2 * math.pi),
                  child: child,
                ),
              );
            },
            child: Container(
              width: 140.0,
              height: 140.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 64.0,
                    color: theme.colorScheme.primaryContainer,
                  ),
                  Positioned(
                    top: 24.0,
                    right: 24.0,
                    child: Icon(
                      Icons.auto_awesome_outlined,
                      size: 20.0,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Positioned(
                    bottom: 30.0,
                    left: 28.0,
                    child: Icon(
                      Icons.blur_on,
                      size: 28.0,
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 48.0),
          Text(
            'onboarding.gemini_title'.tr(),
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: 28.0,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18.0),
          Text(
            'onboarding.gemini_desc'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24.0),
          // Short decorative indicator representing the Gemini button UI in-app
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 16.0, color: theme.colorScheme.primaryContainer),
                const SizedBox(width: 8.0),
                Text(
                  'edit.gemini'.tr().toUpperCase(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 11.0,
                    letterSpacing: 1.0,
                    color: theme.colorScheme.primaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SLIDE 3: CUSTOMIZE / KEY & SAMPLES ---
  Widget _buildCustomizePage(ThemeData theme, ResponsiveLayout layout) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          children: [
            const SizedBox(height: 8.0),
            Text(
              'onboarding.customize_title'.tr(),
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 26.0,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12.0),
            Text(
              'onboarding.customize_desc'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                height: 1.5,
                fontSize: 14.0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24.0),

            // API Key Input
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'account.gemini_key_section'.tr().toUpperCase(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.secondaryContainer,
                  letterSpacing: 1.0,
                  fontSize: 11.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10.0),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14.0),
              decoration: InputDecoration(
                hintText: 'onboarding.gemini_key_hint'.tr(),
                hintStyle: theme.inputDecorationTheme.hintStyle?.copyWith(
                  fontSize: 14.0,
                ),
                prefixIcon: Icon(
                  Icons.vpn_key_outlined,
                  color: theme.colorScheme.primaryContainer,
                  size: 18.0,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
              ),
              onChanged: _handleGeminiKeyChange,
            ),

            const SizedBox(height: 24.0),

            // Writing style sample article
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'account.writing_style_samples'.tr().toUpperCase(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.secondaryContainer,
                  letterSpacing: 1.0,
                  fontSize: 11.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10.0),
            TextField(
              controller: _sampleController,
              maxLines: 5,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14.0, height: 1.4),
              decoration: InputDecoration(
                hintText: 'onboarding.sample_hint'.tr(),
                hintStyle: theme.inputDecorationTheme.hintStyle?.copyWith(
                  fontSize: 14.0,
                ),
                contentPadding: const EdgeInsets.all(16.0),
              ),
              onChanged: _handleSampleChange,
            ),
          ],
        ),
      ),
    );
  }

  // --- SLIDE 4: LORE & BIRD ---
  Widget _buildLorePage(ThemeData theme, ResponsiveLayout layout) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        children: [
          const SizedBox(height: 20.0),
          
          // Bird Chirper Visual Container
          Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Radar pulse circles
              AnimatedBuilder(
                animation: _floatingController,
                builder: (context, child) {
                  final wave = _floatingController.value;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 140.0 + (wave * 40.0),
                        height: 140.0 + (wave * 40.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.primaryContainer.withValues(
                              alpha: (1.0 - wave) * 0.15,
                            ),
                            width: 1.5,
                          ),
                        ),
                      ),
                      Container(
                        width: 120.0 + (wave * 20.0),
                        height: 120.0 + (wave * 20.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.secondaryContainer.withValues(
                              alpha: (1.0 - wave) * 0.10,
                            ),
                            width: 1.0,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              // Interactive Bird widget with recoil anims
              GestureDetector(
                onTap: _triggerBirdChirp,
                child: AnimatedBuilder(
                  animation: _birdChirpController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _birdScaleAnimation.value,
                      child: Transform.rotate(
                        angle: _birdRotateAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: 110.0,
                    height: 110.0,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primaryContainer,
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                          blurRadius: 20.0,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.flutter_dash, // stylized bird
                      size: 56.0,
                      color: theme.colorScheme.primaryContainer,
                    ),
                  ),
                ),
              ),

              // Floating Chirps
              ..._floatingChirps.map((chirp) {
                return _FloatingChirpWidget(
                  key: ValueKey(chirp.id),
                  chirp: chirp,
                  theme: theme,
                );
              }),
            ],
          ),
          
          const SizedBox(height: 36.0),
          Text(
            'onboarding.lore_title'.tr(),
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: 26.0,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16.0),
          Text(
            'onboarding.lore_desc'.tr(),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24.0),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.15),
              ),
            ),
            child: Text(
              'onboarding.lore_question'.tr(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w600,
                fontSize: 15.0,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// Model class for tracking floating chirp animations
class _FloatingChirp {
  final String id;
  final String text;
  final double leftOffset;
  final double startBottom;
  final double targetBottom;

  _FloatingChirp({
    required this.id,
    required this.text,
    required this.leftOffset,
    required this.startBottom,
    required this.targetBottom,
  });
}

// Stateful Widget representing a single floating text bubble fading out
class _FloatingChirpWidget extends StatefulWidget {
  final _FloatingChirp chirp;
  final ThemeData theme;
  const _FloatingChirpWidget({super.key, required this.chirp, required this.theme});

  @override
  State<_FloatingChirpWidget> createState() => _FloatingChirpWidgetState();
}

class _FloatingChirpWidgetState extends State<_FloatingChirpWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _yAnim;
  late final Animation<double> _opacityAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _yAnim = Tween<double>(
      begin: widget.chirp.startBottom,
      end: widget.chirp.targetBottom,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _opacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.4, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 80),
    ]).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutBack));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Positioned(
          bottom: _yAnim.value,
          left: widget.chirp.leftOffset + 80.0, // center offset mapping
          child: Opacity(
            opacity: _opacityAnim.value,
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: child,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: widget.theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4.0,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          widget.chirp.text,
          style: widget.theme.textTheme.bodySmall?.copyWith(
            color: widget.theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 12.0,
          ),
        ),
      ),
    );
  }
}
