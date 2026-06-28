import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ai_content_service.dart';
import '../widgets/responsive_builder.dart';
import '../widgets/top_bar.dart';

class EditScreen extends StatefulWidget {
  final Note? note;
  final Function(Note)? onSaved;
  final VoidCallback? onCancel;
  final VoidCallback? onSettingsRedirect;

  const EditScreen({
    super.key,
    this.note,
    this.onSaved,
    this.onCancel,
    this.onSettingsRedirect,
  });

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _labelController;
  late TextEditingController _contentController;
  late FocusNode _titleFocusNode;
  bool _isAiLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _labelController = TextEditingController(text: widget.note?.label ?? '');
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
    _titleFocusNode = FocusNode();
    _titleFocusNode.addListener(() {
      if (!_titleFocusNode.hasFocus) {
        _titleController.text = _toTitleCase(_titleController.text);
      }
    });
  }

  @override
  void didUpdateWidget(covariant EditScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.note?.id != oldWidget.note?.id) {
      _titleController.text = widget.note?.title ?? '';
      _labelController.text = widget.note?.label ?? '';
      _contentController.text = widget.note?.content ?? '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _labelController.dispose();
    _contentController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _insertFormatting(String prefix, [String suffix = '']) {
    final text = _contentController.text;
    final selection = _contentController.selection;

    if (selection.start == -1 || selection.end == -1) {
      _contentController.text = text + prefix + suffix;
      _contentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _contentController.text.length),
      );
      return;
    }

    final selectedText = text.substring(selection.start, selection.end);
    final newText = text.replaceRange(
      selection.start,
      selection.end,
      '$prefix$selectedText$suffix',
    );

    _contentController.text = newText;

    if (selection.start == selection.end) {
      _contentController.selection = TextSelection.fromPosition(
        TextPosition(offset: selection.start + prefix.length),
      );
    } else {
      _contentController.selection = TextSelection(
        baseOffset: selection.start,
        extentOffset:
            selection.start +
            prefix.length +
            selectedText.length +
            suffix.length,
      );
    }
  }

  void _confirmClearText() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text(
            'edit.clear_confirm_title'.tr(),
            style: TextStyle(
              color: theme.colorScheme.primaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'edit.clear_confirm_message'.tr(),
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'edit.cancel'.tr(),
                style: TextStyle(color: theme.colorScheme.secondaryContainer),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                _contentController.clear();
                Navigator.pop(context);
              },
              child: Text('edit.clear'.tr()),
            ),
          ],
        );
      },
    );
  }

  void _showGeminiRestructureDialog() async {
    final rawThoughts = _contentController.text.trim();
    if (rawThoughts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('edit.restructure_empty_warning'.tr()),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final aiService = Provider.of<AiContentService>(context, listen: false);

    if (!aiService.hasAnyConfiguredKey(settingsProvider.geminiApiKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('edit.restructure_no_key_error'.tr()),
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

    // Show the bottom sheet and await the result
    final resultText = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GeminiRestructureSheet(
        rawThoughts: rawThoughts,
        userApiKey: settingsProvider.geminiApiKey,
        aiService: aiService,
      ),
    );

    // If user clicked "Yes, Apply" and returned the text
    if (resultText != null && mounted) {
      setState(() {
        _contentController.text = resultText;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('edit.restructure_success_applied'.tr()),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _polishAndSummarize() async {
    final rawThoughts = _contentController.text.trim();
    if (rawThoughts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('edit.polish_empty_warning'.tr()),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final aiService = Provider.of<AiContentService>(context, listen: false);

    if (!aiService.hasAnyConfiguredKey(settingsProvider.geminiApiKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('edit.restructure_no_key_error'.tr()),
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
      _isAiLoading = true;
    });

    try {
      final result = await aiService.restructureAndSummarize(
        rawThoughts,
        settingsProvider.geminiApiKey,
      );

      setState(() {
        _contentController.text = result;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('edit.polish_success'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('edit.polish_failed'.tr(args: [e.toString()])),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAiLoading = false;
        });
      }
    }
  }

  void _saveNote() {
    final title = _toTitleCase(_titleController.text.trim());
    final label = _labelController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('edit.enter_title_error'.tr())));
      return;
    }

    final notesProvider = Provider.of<NotesProvider>(context, listen: false);

    if (widget.note != null) {
      // Edit existing note
      final updatedNote = widget.note!.copyWith(
        title: title,
        label: label.isEmpty ? 'General' : label,
        content: content,
        date: DateTime.now(),
      );
      notesProvider.updateNote(updatedNote);
      widget.onSaved?.call(updatedNote);
    } else {
      // Create new note
      final newNote = Note(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        label: label.isEmpty ? 'General' : label,
        content: content,
        date: DateTime.now(),
      );
      notesProvider.addNote(newNote);
      widget.onSaved?.call(newNote);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('edit.save_success'.tr()),
        backgroundColor: Colors.green,
      ),
    );

    // If on mobile (page pushed), pop route
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ResponsiveBuilder(
      builder: (context, layout) {
        final isMobile = layout.isMobile;

        return Scaffold(
          appBar: TopBar(
            title: widget.note != null
                ? 'edit.edit_note'.tr()
                : 'edit.new_note'.tr(),
            leading: isMobile
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      widget.onCancel?.call();
                      Navigator.pop(context);
                    },
                  )
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onCancel,
                  ),
            border: true,
          ),
          body: Stack(
            children: [
              // Atmospheric Glow Accent Blobs
              Positioned(
                top: -100,
                left: -100,
                width: 300,
                height: 300,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.secondaryContainer.withValues(
                      alpha: 0.04,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                right: -100,
                width: 300,
                height: 300,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.colorScheme.primaryContainer.withValues(
                      alpha: 0.04,
                    ),
                  ),
                ),
              ),

              // Centered Writing Surface
              GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SafeArea(
                  child: Column(
                    children: [
                      // Sticky Formatting Toolbar
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(alpha: 0.95),
                          border: Border(
                            bottom: BorderSide(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
                              width: 1.0,
                            ),
                          ),
                        ),
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 800.0),
                            padding: EdgeInsets.symmetric(horizontal: layout.margin),
                            child: _buildFormattingToolbar(theme),
                          ),
                        ),
                      ),

                      // Scrollable writing surface
                      Expanded(
                        child: SingleChildScrollView(
                          child: Center(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 800.0),
                              padding: EdgeInsets.symmetric(
                                horizontal: layout.margin,
                                vertical: 32.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title TextField (Transparent and massive display font)
                                  TextField(
                                    controller: _titleController,
                                    focusNode: _titleFocusNode,
                                    autofocus: true,
                                    textCapitalization: TextCapitalization.words,
                                    onTapOutside: (event) {
                                      FocusManager.instance.primaryFocus?.unfocus();
                                    },
                                    style: theme.textTheme.displayLarge?.copyWith(
                                      fontSize: isMobile ? 36.0 : 48.0,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    cursorColor: theme.colorScheme.primaryContainer,
                                    decoration: InputDecoration(
                                      hintText: 'edit.enter_title'.tr(),
                                      hintStyle: theme.inputDecorationTheme.hintStyle,
                                      border: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const SizedBox(height: 24.0),

                                  // Label/Tag input
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.label_outline,
                                        size: 18.0,
                                        color: theme.colorScheme.secondaryContainer,
                                      ),
                                      const SizedBox(width: 8.0),
                                      Text(
                                        '#',
                                        style: TextStyle(
                                          color: theme.colorScheme.secondaryContainer,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 4.0),
                                      Expanded(
                                        child: TextField(
                                          controller: _labelController,
                                          onTapOutside: (event) {
                                            FocusManager.instance.primaryFocus
                                                ?.unfocus();
                                          },
                                          style: theme.textTheme.labelLarge?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSecondaryContainer,
                                            fontSize: 14.0,
                                            letterSpacing: 1.0,
                                          ),
                                          cursorColor: theme.colorScheme.primaryContainer,
                                          textCapitalization:
                                              TextCapitalization.characters,
                                          decoration: InputDecoration(
                                            hintText: 'edit.add_label'.tr(),
                                            hintStyle: theme.inputDecorationTheme.hintStyle?.copyWith(
                                              letterSpacing: 1.0,
                                            ),
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 32.0),

                                  // Narrative section header
                                  Text(
                                    'edit.narrative'.tr(),
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color: theme.colorScheme.secondaryContainer,
                                      fontSize: 10.0,
                                      letterSpacing: 2.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 16.0),

                                  // Body Content Textarea
                                  TextField(
                                    controller: _contentController,
                                    textCapitalization: TextCapitalization.sentences,
                                    spellCheckConfiguration:
                                        const SpellCheckConfiguration(),
                                    onTapOutside: (event) {
                                      FocusManager.instance.primaryFocus?.unfocus();
                                    },
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      height: 1.6,
                                    ),
                                    cursorColor: theme.colorScheme.primaryContainer,
                                    maxLines: null,
                                    minLines: 15,
                                    keyboardType: TextInputType.multiline,
                                    decoration: InputDecoration(
                                      hintText: 'edit.begin_narrative'.tr(),
                                      hintStyle: theme.inputDecorationTheme.hintStyle,
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const SizedBox(height: 32.0),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Wrap(
                                      spacing: 16.0,
                                      runSpacing: 12.0,
                                      alignment: WrapAlignment.end,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: theme.brightness == Brightness.dark
                                                ? const Color(0xFFFFE16D)
                                                : theme.colorScheme.secondary,
                                            side: BorderSide(
                                              color: theme.brightness == Brightness.dark
                                                  ? const Color(0xFFFFE16D)
                                                  : theme.colorScheme.secondary,
                                              width: 1.5,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(
                                                4.0,
                                              ),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20.0,
                                              vertical: 16.0,
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.auto_awesome,
                                            size: 18.0,
                                          ),
                                          label: Text(
                                            'edit.gemini'.tr(),
                                            style: theme.textTheme.labelLarge
                                                ?.copyWith(
                                                  color: theme.brightness == Brightness.dark
                                                      ? const Color(0xFFFFE16D)
                                                      : theme.colorScheme.secondary,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.0,
                                                ),
                                          ),
                                          onPressed: _showGeminiRestructureDialog,
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                theme.colorScheme.primaryContainer,
                                            foregroundColor:
                                                theme.colorScheme.onPrimaryContainer,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(
                                                4.0,
                                              ),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 32.0,
                                              vertical: 16.0,
                                            ),
                                          ),
                                          onPressed: _saveNote,
                                          child: Text(
                                            'edit.save'.tr(),
                                            style: theme.textTheme.labelLarge
                                                ?.copyWith(
                                                  color: theme.colorScheme.onPrimary,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.0,
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
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFormattingToolbar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Subheading
                  IconButton(
                    icon: const Icon(Icons.title),
                    tooltip: 'edit.heading_tooltip'.tr(),
                    color: theme.colorScheme.primaryContainer,
                    onPressed: () => _insertFormatting('### '),
                  ),
                  // Bold
                  IconButton(
                    icon: const Icon(Icons.format_bold),
                    tooltip: 'edit.bold_tooltip'.tr(),
                    color: theme.colorScheme.primaryContainer,
                    onPressed: () => _insertFormatting('**', '**'),
                  ),
                  // Italic
                  IconButton(
                    icon: const Icon(Icons.format_italic),
                    tooltip: 'edit.italic_tooltip'.tr(),
                    color: theme.colorScheme.primaryContainer,
                    onPressed: () => _insertFormatting('*', '*'),
                  ),
                  // Bullet list
                  IconButton(
                    icon: const Icon(Icons.format_list_bulleted),
                    tooltip: 'edit.list_tooltip'.tr(),
                    color: theme.colorScheme.primaryContainer,
                    onPressed: () => _insertFormatting('- '),
                  ),
                  // Code Block
                  IconButton(
                    icon: const Icon(Icons.code),
                    tooltip: 'edit.code_tooltip'.tr(),
                    color: theme.colorScheme.primaryContainer,
                    onPressed: () => _insertFormatting('\n```\n', '\n```\n'),
                  ),
                  // AI Polish Button
                  _isAiLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.0),
                          child: SizedBox(
                            width: 20.0,
                            height: 20.0,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              color: Color(0xFFFFE16D),
                            ),
                          ),
                        )
                        : IconButton(
                            icon: const Icon(Icons.auto_awesome),
                            tooltip: 'edit.polish_summarize_tooltip'.tr(),
                            color: theme.brightness == Brightness.dark
                                ? const Color(0xFFFFE16D)
                                : theme.colorScheme.secondary,
                            onPressed: _polishAndSummarize,
                          ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          // Clear Button
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'edit.clear_tooltip'.tr(),
            color: Colors.redAccent.withValues(alpha: 0.8),
            onPressed: _confirmClearText,
          ),
        ],
      ),
    );
  }
}

class GeminiRestructureSheet extends StatefulWidget {
  final String rawThoughts;
  final String userApiKey;
  final AiContentService aiService;

  const GeminiRestructureSheet({
    super.key,
    required this.rawThoughts,
    required this.userApiKey,
    required this.aiService,
  });

  @override
  State<GeminiRestructureSheet> createState() => _GeminiRestructureSheetState();
}

class _GeminiRestructureSheetState extends State<GeminiRestructureSheet> {
  String? _restructuredText;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _generateRestructured();
      }
    });
  }

  Future<void> _generateRestructured() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      final langCode = context.locale.languageCode;
      final systemInstruction = settingsProvider.getWritingStyleInstruction(
        langCode,
      );
      final styleReferences = settingsProvider.getWritingStyleSamples(langCode);

      final result = await widget.aiService.restructureThoughts(
        widget.rawThoughts,
        widget.userApiKey,
        systemInstruction: systemInstruction,
        styleReferences: styleReferences,
      );
      if (mounted) {
        setState(() {
          _restructuredText = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20.0,
            spreadRadius: 5.0,
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 10.0,
        bottom: 20.0 + MediaQuery.of(context).viewInsets.bottom,
      ),
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40.0,
              height: 4.0,
              margin: const EdgeInsets.only(bottom: 16.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: theme.colorScheme.primaryContainer,
                size: 24.0,
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Text(
                  'edit.restructure_dialog_title'.tr(),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!_isLoading)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'edit.restructure_refresh_tooltip'.tr(),
                  color: theme.colorScheme.primaryContainer,
                  onPressed: _generateRestructured,
                ),
            ],
          ),
          const SizedBox(height: 16.0),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.1,
                  ),
                ),
              ),
              child: _buildBody(theme),
            ),
          ),
          const SizedBox(height: 16.0),
          if (!_isLoading && _error == null && _restructuredText != null) ...[
            Center(
              child: Text(
                'edit.restructure_like_result'.tr(),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                ),
              ),
            ),
            const SizedBox(height: 12.0),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface.withValues(
                        alpha: 0.6,
                      ),
                      side: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('edit.restructure_no_discard'.tr()),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                    ),
                    onPressed: () => Navigator.pop(context, _restructuredText),
                    child: Text(
                      'edit.restructure_yes_apply'.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_error != null) ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.errorContainer,
                foregroundColor: theme.colorScheme.onErrorContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14.0),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text('edit.restructure_close'.tr()),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFFFFE16D)),
            const SizedBox(height: 24.0),
            Text(
              'edit.restructure_loading'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: theme.colorScheme.error,
                size: 48.0,
              ),
              const SizedBox(height: 16.0),
              Text(
                'AI Restructuring Failed',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12.0),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16.0),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                onPressed: _generateRestructured,
              ),
            ],
          ),
        ),
      );
    }

    if (_restructuredText != null) {
      return Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: SelectableText(
              _restructuredText!,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

String _toTitleCase(String text) {
  if (text.isEmpty) return text;

  // List of words that should remain lowercase in title case (unless first or last)
  const lowercaseWords = {
    'a',
    'an',
    'the',
    'and',
    'but',
    'for',
    'or',
    'nor',
    'on',
    'in',
    'at',
    'by',
    'to',
    'of',
    'with',
    'about',
  };

  final words = text.split(' ');
  final capitalizedWords = <String>[];

  for (int i = 0; i < words.length; i++) {
    final word = words[i];
    if (word.isEmpty) {
      capitalizedWords.add('');
      continue;
    }

    // Preserve acronyms like AI, OS, HTML
    if (word == word.toUpperCase() && RegExp(r'^[A-Z]+$').hasMatch(word)) {
      capitalizedWords.add(word);
      continue;
    }

    final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');

    if (i > 0 && i < words.length - 1 && lowercaseWords.contains(cleanWord)) {
      capitalizedWords.add(word.toLowerCase());
    } else {
      if (word.length == 1) {
        capitalizedWords.add(word.toUpperCase());
      } else {
        capitalizedWords.add(
          word[0].toUpperCase() + word.substring(1).toLowerCase(),
        );
      }
    }
  }

  return capitalizedWords.join(' ');
}
