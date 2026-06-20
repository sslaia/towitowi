import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../models/note.dart';
import '../widgets/responsive_builder.dart';
import '../widgets/top_bar.dart';
import '../widgets/bottom_bar.dart';
import '../widgets/note_list_item.dart';
import 'detail_screen.dart';
import 'edit_screen.dart';
import 'about_screen.dart';
import '../services/backup_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentTab = 0;
  String? _selectedNoteId = '1';
  bool _isEditingRightPane = false;
  String _searchQuery = '';
  bool _showAllNotes = false;

  late final SettingsProvider _settingsProvider;
  late final TextEditingController _geminiApiKeyController;
  late final TabController _settingsTabController;
  late final TextEditingController _writingStyleInstructionController;
  late final List<TextEditingController> _writingStyleSampleControllers;
  late final FocusNode _searchFocusNode;
  late final TextEditingController _searchController;
  String _lastLangCode = '';

  @override
  void initState() {
    super.initState();
    _settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    _geminiApiKeyController = TextEditingController(
      text: _settingsProvider.geminiApiKey,
    );
    _settingsTabController = TabController(length: 3, vsync: this);
    _writingStyleInstructionController = TextEditingController();
    _writingStyleSampleControllers = List.generate(3, (_) => TextEditingController());
    _searchFocusNode = FocusNode(skipTraversal: true);
    _searchController = TextEditingController();

    _settingsProvider.addListener(_onPreferencesChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final langCode = context.locale.languageCode;
    if (_lastLangCode != langCode) {
      _lastLangCode = langCode;
      _onPreferencesChanged();
    }
  }

  void _onPreferencesChanged() {
    final langCode = context.locale.languageCode;

    if (_geminiApiKeyController.text != _settingsProvider.geminiApiKey) {
      _geminiApiKeyController.value = _geminiApiKeyController.value.copyWith(
        text: _settingsProvider.geminiApiKey,
        selection: TextSelection.collapsed(
          offset: _settingsProvider.geminiApiKey.length,
        ),
      );
    }

    final instruction = _settingsProvider.getWritingStyleInstruction(langCode);
    if (_writingStyleInstructionController.text != instruction) {
      _writingStyleInstructionController.value = _writingStyleInstructionController.value.copyWith(
        text: instruction,
        selection: TextSelection.collapsed(
          offset: instruction.length,
        ),
      );
    }

    final samples = _settingsProvider.getWritingStyleSamples(langCode);
    for (int i = 0; i < 3; i++) {
      final sampleText = i < samples.length ? samples[i] : '';
      final controller = _writingStyleSampleControllers[i];
      if (controller.text != sampleText) {
        controller.value = controller.value.copyWith(
          text: sampleText,
          selection: TextSelection.collapsed(
            offset: sampleText.length,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _settingsProvider.removeListener(_onPreferencesChanged);
    _geminiApiKeyController.dispose();
    _settingsTabController.dispose();
    _writingStyleInstructionController.dispose();
    for (final c in _writingStyleSampleControllers) {
      c.dispose();
    }
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleExport(BuildContext context) async {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    
    if (notesProvider.notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('backup_restore.no_notes_to_export'.tr()),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    try {
      await BackupService.exportNotes(notesProvider.notes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('backup_restore.export_success'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (e.toString().contains('cancelled')) {
        return;
      }
      if (context.mounted) {
        final errorMsg = e.toString().contains('no_notes') 
            ? 'backup_restore.no_notes_to_export'.tr() 
            : e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('backup_restore.export_failed'.tr(args: [errorMsg])),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _handleImport(BuildContext context) async {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    try {
      final count = await BackupService.importNotes(notesProvider);
      if (context.mounted && count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('backup_restore.import_success'.tr(args: [count.toString()])),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('backup_restore.import_failed'.tr(args: [e.toString()])),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<SettingsProvider>(context);
    return ResponsiveBuilder(
      builder: (context, layout) {
        if (layout.isMobile) {
          return _buildMobileLayout(context, layout);
        } else {
          return _buildDesktopLayout(context, layout);
        }
      },
    );
  }

  // --- MOBILE LAYOUT ---
  Widget _buildMobileLayout(BuildContext context, ResponsiveLayout layout) {
    final theme = Theme.of(context);
    final notesProvider = Provider.of<NotesProvider>(context);

    // Filter notes based on tab and search query
    List<Note> filteredNotes = _getFilteredNotes(notesProvider.notes);

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        backgroundColor: theme.colorScheme.surface,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              children: [
                // Drawer Header with App Icon
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Container(
                        width: 44.0,
                        height: 44.0,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(
                            color: theme.colorScheme.primaryContainer,
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9.0),
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14.0),
                      Text(
                        'app_title'.tr(),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontSize: 24.0,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                // Scrollable content of Drawer
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom > 0
                          ? 140.0
                          : 0.0,
                    ),
                    children: [
                      _buildDrawerNavItem(
                        icon: Icons.auto_stories_outlined,
                        activeIcon: Icons.auto_stories,
                        label: 'nav.library'.tr(),
                        index: 0,
                        theme: theme,
                      ),
                      _buildDrawerNavItem(
                        icon: Icons.search_outlined,
                        activeIcon: Icons.search,
                        label: 'nav.search'.tr(),
                        index: 1,
                        theme: theme,
                      ),
                      _buildDrawerNavItem(
                        icon: Icons.bookmark_border_rounded,
                        activeIcon: Icons.bookmark_rounded,
                        label: 'nav.bookmarks'.tr(),
                        index: 2,
                        theme: theme,
                      ),
                      _buildDrawerNavItem(
                        icon: Icons.edit_note_outlined,
                        activeIcon: Icons.edit_note,
                        label: 'nav.drafts'.tr(),
                        index: 3,
                        theme: theme,
                      ),
                      _buildDrawerNavItem(
                        icon: Icons.settings_outlined,
                        activeIcon: Icons.settings,
                        label: 'nav.settings'.tr(),
                        index: 4,
                        theme: theme,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 8.0,
                        ),
                        child: Divider(color: Colors.white10),
                      ),
                      _buildDrawerAboutItem(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: _currentTab != 0 || _searchQuery.isNotEmpty,
        child: _currentTab == 4
            ? SingleChildScrollView(
                child: Column(
                  children: [
                    TopBar(
                      title: 'account.title'.tr(),
                      border: true,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        color: theme.colorScheme.onSurface,
                        iconSize: 20.0,
                        onPressed: () {
                          setState(() {
                            _currentTab = 0;
                          });
                        },
                      ),
                    ),
                    _buildSettingsContent(context, true),
                  ],
                ),
              )
            : SingleChildScrollView(
                child: Column(
                  children: [
                    // Header / Hero Section (Only in Library Tab)
                    if (_currentTab == 0 && _searchQuery.isEmpty)
                      _buildHeroSection(layout),

                    // Search input if search tab is active
                    if (_currentTab == 1) _buildSearchInput(theme),

                    // Scrollable note listing
                    _buildNotesList(
                      filteredNotes,
                      layout,
                      isMobile: true,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                    ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: BottomBar(
        currentIndex: _currentTab,
        onTabSelected: (index) {
          setState(() {
            _currentTab = index;
            _searchQuery = ''; // reset search
            _searchController.clear();
            _showAllNotes = false;
          });
        },
        onCreatePressed: () {
          // Push to edit screen in creation mode
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EditScreen()),
          );
        },
        onMenuPressed: () {
          _scaffoldKey.currentState?.openDrawer();
        },
      ),
    );
  }

  Widget _buildDrawerNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required ThemeData theme,
  }) {
    final isActive = _currentTab == index;
    final color = isActive
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.onSurface.withValues(alpha: 0.8);

    return InkWell(
      onTap: () {
        setState(() {
          _currentTab = index;
          _searchQuery = ''; // Reset search
          _searchController.clear();
          _showAllNotes = false;
        });
        Navigator.pop(context); // Close the drawer
      },
      child: Container(
        color: isActive
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.05)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
        child: Row(
          children: [
            Icon(isActive ? activeIcon : icon, color: color, size: 22.0),
            const SizedBox(width: 16.0),
            Expanded(
              child: Text(
                label.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  letterSpacing: 1.0,
                  fontSize: 13.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildDrawerAboutItem() {
    final theme = Theme.of(context);
    return _buildDrawerActionItem(
      icon: Icons.info_outline_rounded,
      label: 'about.title'.tr(),
      theme: theme,
      onTap: () {
        Navigator.pop(context); // Close the drawer
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AboutScreen()),
        );
      },
    );
  }



  Widget _buildDrawerActionItem({
    required IconData icon,
    required String label,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    final color = theme.colorScheme.onSurface.withValues(alpha: 0.8);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22.0),
            const SizedBox(width: 16.0),
            Expanded(
              child: Text(
                label.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.normal,
                  letterSpacing: 1.0,
                  fontSize: 13.0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- DESKTOP/TABLET SPLIT PANE LAYOUT ---
  Widget _buildDesktopLayout(BuildContext context, ResponsiveLayout layout) {
    final theme = Theme.of(context);
    final notesProvider = Provider.of<NotesProvider>(context);
    List<Note> filteredNotes = _getFilteredNotes(notesProvider.notes);

    // Sync selected note if current one is deleted/empty (and we are not creating a new note)
    if (filteredNotes.isNotEmpty &&
        !(_selectedNoteId == null && _isEditingRightPane) &&
        (notesProvider.getNoteById(_selectedNoteId ?? '') == null)) {
      _selectedNoteId = filteredNotes.first.id;
    }

    final selectedNote = notesProvider.getNoteById(_selectedNoteId ?? '');

    return Scaffold(
      body: Row(
        children: [
          // Navigation Sidebar (Replaces BottomBar on desktop)
          _buildNavigationRail(theme),

          const VerticalDivider(width: 1, thickness: 1, color: Colors.white10),

          // Master Pane: Notes list
          SizedBox(
            width: 360,
            child: Column(
              children: [
                TopBar(
                  title: 'app_title'.tr(),
                  border: true,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.add),
                      color: theme.colorScheme.primaryContainer,
                      onPressed: () {
                        setState(() {
                          _selectedNoteId = null;
                          _isEditingRightPane = true;
                          if (_currentTab == 4) {
                            _currentTab = 0;
                          }
                        });
                      },
                    ),
                  ],
                ),
                _buildSearchInput(theme),
                Expanded(
                  child: _buildNotesList(
                    filteredNotes,
                    layout,
                    isMobile: false,
                  ),
                ),
              ],
            ),
          ),

          const VerticalDivider(width: 1, thickness: 1, color: Colors.white10),

          // Detail/Editor Pane
          Expanded(
            child: _currentTab == 4
                ? Scaffold(
                    appBar: TopBar(title: 'account.title'.tr(), border: true),
                    body: SingleChildScrollView(
                      child: _buildSettingsContent(context, false),
                    ),
                  )
                : (selectedNote == null && !_isEditingRightPane
                      ? Center(
                          child: Text(
                            'home.no_note_selected'.tr(),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                        )
                      : _isEditingRightPane
                      ? EditScreen(
                          note: selectedNote,
                          onSaved: (savedNote) {
                            setState(() {
                              _selectedNoteId = savedNote.id;
                              _isEditingRightPane = false;
                            });
                          },
                          onCancel: () {
                            setState(() {
                              _isEditingRightPane = false;
                            });
                          },
                        )
                      : DetailScreen(
                          note: selectedNote!,
                          onEditPressed: () {
                            setState(() {
                              _isEditingRightPane = true;
                            });
                          },
                        )),
          ),
        ],
      ),
    );
  }

  // --- REUSABLE UI BUILDERS ---

  List<Note> _getFilteredNotes(List<Note> allNotes) {
    List<Note> filtered = allNotes;

    // Filter by Tab
    if (_currentTab == 2) {
      filtered = allNotes
          .where((n) => _settingsProvider.isBookmarked(n.id))
          .toList();
    } else if (_currentTab == 3) {
      filtered = allNotes
          .where((n) => n.label.toLowerCase() == 'poetry')
          .toList(); // Mock drafts folder as Poetry
    }

    // Filter by Search Query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (n) =>
                n.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                n.content.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                n.label.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }

    return filtered;
  }

  Widget _buildHeroSection(ResponsiveLayout layout) {
    final theme = Theme.of(context);
    return SizedBox(
      height: layout.isMobile ? 240 : 320,
      width: double.infinity,
      child: Stack(
        children: [
          // Hero Background Image (Calming Dusk River)
          Positioned.fill(
            child: Image.network(
              'https://lh3.googleusercontent.com/aida-public/AB6AXuB5JG3MY5gSYiunlk5lIsd_dJGz72I4-KoUxBNwZhQAdR8Jn82ECapg9Ev99T0ekMstN-d7JotxvTtHoQ9_RxirNZ2Kj1dkDj2MqX_m5jKkTd5pNGM0TTMrJzhGFXkDY7QvPvXi5qMMKx5zZDNVDMWyo8LKx07DhRFKRdKsPgvlB3MOeQsZaiXiBLXOJfuX92QqHUDL2fJmDfvKR16rnepbIPOLlqRln6JV4QR7yfuj5fkWdAYypbOgBN8ex852-PqBqw8XLg1w3kM',
              fit: BoxFit.cover,
            ),
          ),
          // Deep atmospheric gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.85),
                  ],
                ),
              ),
            ),
          ),
          // Overlay content
          Positioned(
            bottom: 24.0,
            left: layout.margin,
            right: layout.margin,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'app_title'.tr(),
                  style: theme.textTheme.displayLarge?.copyWith(
                    fontSize: layout.isMobile ? 36 : 48,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchInput(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: 'home.search_hint'.tr(),
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          prefixIcon: Icon(
            Icons.search,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.1,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
        ),
      ),
    );
  }

  Widget _buildNotesList(
    List<Note> notes,
    ResponsiveLayout layout, {
    required bool isMobile,
    bool shrinkWrap = false,
    ScrollPhysics? physics,
  }) {
    final theme = Theme.of(context);
    final notesProvider = Provider.of<NotesProvider>(context);

    if (notesProvider.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: theme.colorScheme.primaryContainer,
        ),
      );
    }

    if (notes.isEmpty) {
      return Center(
        child: Text(
          _currentTab == 2 ? 'home.no_bookmarks'.tr() : 'home.no_notes'.tr(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    final bool shouldLimit =
        _currentTab == 0 &&
        _searchQuery.isEmpty &&
        !_showAllNotes &&
        notes.length > 5;
    final List<Note> notesToShow = shouldLimit ? notes.take(5).toList() : notes;
    final bool showViewLibraryButton = shouldLimit;

    return ListView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: EdgeInsets.symmetric(horizontal: layout.margin, vertical: 16.0),
      itemCount: notesToShow.length + 1 + (showViewLibraryButton ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) {
          // List Title/Header
          String headerText = 'home.recent_notes'.tr();
          if (_currentTab == 2) {
            headerText = 'home.bookmarked_notes'.tr();
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              headerText,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        if (showViewLibraryButton && index == notesToShow.length + 1) {
          // View Library Button at the bottom
          return Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 24.0),
            child: Center(
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primaryContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 12.0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    side: BorderSide(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _showAllNotes = true;
                  });
                },
                child: Text(
                  'home.view_library'.tr(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          );
        }

        final note = notesToShow[index - 1];
        final isSelected = note.id == _selectedNoteId && !isMobile;

        return NoteListItem(
          note: note,
          isSelected: isSelected,
          onTap: () {
            if (isMobile) {
              // Mobile Page Push
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DetailScreen(note: note),
                ),
              );
            } else {
              // Desktop update selected note
              setState(() {
                _selectedNoteId = note.id;
                _isEditingRightPane = false;
                if (_currentTab == 4) {
                  _currentTab = 0;
                }
              });
            }
          },
        );
      },
    );
  }

  Widget _buildNavigationRail(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxHeight < 450;
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: NavigationRail(
                selectedIndex: _currentTab,
                backgroundColor: theme.colorScheme.surface,
                indicatorColor: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.2,
                ),
                onDestinationSelected: (index) {
                  setState(() {
                    _currentTab = index;
                    _searchQuery = '';
                    _searchController.clear();
                    _showAllNotes = false;
                  });
                },
                labelType: NavigationRailLabelType.all,
                leading: isCompact
                    ? null
                    : Column(
                        children: [
                          const SizedBox(height: 16.0),
                          Icon(
                            Icons.auto_stories,
                            color: theme.colorScheme.primaryContainer,
                          ),
                          const SizedBox(height: 32.0),
                        ],
                      ),
                destinations: [
                  NavigationRailDestination(
                    icon: const Icon(Icons.auto_stories_outlined),
                    selectedIcon: const Icon(Icons.auto_stories),
                    label: Text(
                      'nav.library'.tr(),
                      style: TextStyle(
                        fontSize: 10.0,
                        color: theme.colorScheme.primaryContainer,
                      ),
                    ),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.search),
                    selectedIcon: const Icon(Icons.search),
                    label: Text(
                      'nav.search'.tr(),
                      style: const TextStyle(fontSize: 10.0),
                    ),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.bookmark_border_rounded),
                    selectedIcon: const Icon(Icons.bookmark_rounded),
                    label: Text(
                      'nav.bookmarks'.tr(),
                      style: const TextStyle(fontSize: 10.0),
                    ),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.edit_note_outlined),
                    selectedIcon: const Icon(Icons.edit_note),
                    label: Text(
                      'nav.drafts'.tr(),
                      style: const TextStyle(fontSize: 10.0),
                    ),
                  ),
                  NavigationRailDestination(
                    icon: const Icon(Icons.settings_outlined),
                    selectedIcon: const Icon(Icons.settings),
                    label: Text(
                      'nav.settings'.tr(),
                      style: const TextStyle(fontSize: 10.0),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsContent(BuildContext context, bool isMobile) {
    final theme = Theme.of(context);
    final currentLocale = context.locale;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600.0),
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Language Selector Section Header
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'account.select_language'.tr().toUpperCase(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.secondaryContainer,
                  letterSpacing: 1.5,
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16.0),

            // Language Selection Buttons
            Row(
              children: [
                // English Card
                Expanded(
                  child: _buildLanguageCard(
                    context,
                    label: 'account.english'.tr(),
                    localeCode: 'en',
                    isActive: currentLocale.languageCode == 'en',
                    theme: theme,
                  ),
                ),
                const SizedBox(width: 16.0),
                // Indonesian Card
                Expanded(
                  child: _buildLanguageCard(
                    context,
                    label: 'account.indonesian'.tr(),
                    localeCode: 'id',
                    isActive: currentLocale.languageCode == 'id',
                    theme: theme,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32.0),
            const Divider(color: Colors.white10),
            const SizedBox(height: 24.0),

            // Backup & Restore Section Header
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'backup_restore.title'.tr().toUpperCase(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.secondaryContainer,
                  letterSpacing: 1.5,
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              'backup_restore.desc'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20.0),

            // Export & Import Buttons Row
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFFE16D),
                      side: const BorderSide(
                        color: Color(0xFFFFE16D),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 16.0,
                      ),
                    ),
                    icon: const Icon(Icons.file_upload_outlined, size: 18.0),
                    label: Text(
                      'backup_restore.export_button'.tr(),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: const Color(0xFFFFE16D),
                        fontWeight: FontWeight.bold,
                        fontSize: 12.0,
                        letterSpacing: 0.5,
                      ),
                    ),
                    onPressed: () => _handleExport(context),
                  ),
                ),
                const SizedBox(width: 16.0),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 16.0,
                      ),
                    ),
                    icon: const Icon(Icons.file_download_outlined, size: 18.0),
                    label: Text(
                      'backup_restore.import_button'.tr(),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.0,
                        letterSpacing: 0.5,
                      ),
                    ),
                    onPressed: () => _handleImport(context),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32.0),
            const Divider(color: Colors.white10),
            const SizedBox(height: 24.0),

            // Gemini API Key Section Header
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'account.gemini_key_section'.tr().toUpperCase(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.secondaryContainer,
                  letterSpacing: 1.5,
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20.0),

            // Gemini API Key input
            TextField(
              controller: _geminiApiKeyController,
              obscureText: true,
              style: theme.textTheme.bodyMedium,
              scrollPadding: const EdgeInsets.only(bottom: 140.0),
              decoration: InputDecoration(
                // labelText: 'account.gemini_api_key'.tr(),
                hintText: 'account.gemini_api_key_hint'.tr(),
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                prefixIcon: Icon(
                  Icons.vpn_key_outlined,
                  color: theme.colorScheme.primaryContainer,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.05,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onChanged: (val) {
                _settingsProvider.setGeminiApiKey(val);
              },
            ),

            const SizedBox(height: 32.0),
            const Divider(color: Colors.white10),
            const SizedBox(height: 24.0),

            // Writing Style Section Header
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'account.writing_style_settings'.tr().toUpperCase(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.secondaryContainer,
                  letterSpacing: 1.5,
                  fontSize: 12.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              'account.writing_style_desc'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20.0),

            // Instruction prompt
            Text(
              'account.writing_style_instruction'.tr().toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.secondaryContainer,
                fontSize: 10.0,
                letterSpacing: 2.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12.0),
            TextField(
              controller: _writingStyleInstructionController,
              maxLines: null,
              minLines: 4,
              style: theme.textTheme.bodyMedium,
              cursorColor: const Color(0xFFFFE16D),
              decoration: InputDecoration(
                hintText: 'account.writing_style_instruction'.tr(),
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.05,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primaryContainer,
                  ),
                ),
              ),
              onChanged: (val) {
                final langCode = context.locale.languageCode;
                _settingsProvider.setWritingStyleInstruction(langCode, val.trim());
              },
            ),
            const SizedBox(height: 24.0),

            // Reference samples
            Text(
              'account.writing_style_samples'.tr().toUpperCase(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.secondaryContainer,
                fontSize: 10.0,
                letterSpacing: 2.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12.0),

            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TabBar(
                    controller: _settingsTabController,
                    indicatorColor: theme.colorScheme.primaryContainer,
                    labelColor: theme.colorScheme.primaryContainer,
                    unselectedLabelColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    labelStyle: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.0,
                    ),
                    tabs: [
                      Tab(text: 'account.writing_style_sample'.tr(args: ['1'])),
                      Tab(text: 'account.writing_style_sample'.tr(args: ['2'])),
                      Tab(text: 'account.writing_style_sample'.tr(args: ['3'])),
                    ],
                  ),
                  Container(
                    height: 250,
                    padding: const EdgeInsets.all(16.0),
                    child: TabBarView(
                      controller: _settingsTabController,
                      children: List.generate(3, (index) {
                        return TextField(
                          controller: _writingStyleSampleControllers[index],
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                          cursorColor: const Color(0xFFFFE16D),
                          decoration: InputDecoration(
                            hintText: 'account.writing_style_sample_hint'.tr(),
                            hintStyle: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) {
                            final langCode = context.locale.languageCode;
                            final currentSamples = List<String>.from(
                              _settingsProvider.getWritingStyleSamples(langCode),
                            );
                            while (currentSamples.length <= index) {
                              currentSamples.add('');
                            }
                            currentSamples[index] = val.trim();
                            _settingsProvider.setWritingStyleSamples(langCode, currentSamples);
                          },
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageCard(
    BuildContext context, {
    required String label,
    required String localeCode,
    required bool isActive,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: () {
        context.setLocale(Locale(localeCode));
      },
      borderRadius: BorderRadius.circular(8.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.05)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.05,
                ),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: isActive
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
            width: isActive ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            // Country flag initials
            Text(
              localeCode.toUpperCase(),
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
                color: isActive
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 12.0),
            Text(
              label,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
