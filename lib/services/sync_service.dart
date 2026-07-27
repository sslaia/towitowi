import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/database.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../providers/settings_provider.dart';

class SyncService {
  static const String _lastSyncTimeKey = 'sync_service_last_sync_time';
  static const String _oauthCredentialsKey = 'sync_service_oauth_credentials';

  // OAuth settings for desktop loopback flow
  static const String _googleAuthEndpoint =
      'https://accounts.google.com/o/oauth2/v2/auth';
  static const String _googleTokenEndpoint =
      'https://oauth2.googleapis.com/token';

  static const String _desktopClientId = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_ID',
    defaultValue:
        '832063400113-q68sdic1bjd10i9e463tccfatsvkhkab.apps.googleusercontent.com',
  );
  static const String _desktopClientSecret = String.fromEnvironment(
    'GOOGLE_DESKTOP_CLIENT_SECRET',
    defaultValue: '',
  );

  // Google Sign-In instance for mobile
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );

  static GoogleSignInAccount? _mobileUser;
  static oauth2.Client? _desktopClient;

  /// Returns true if currently signed in.
  static Future<bool> isSignedIn() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      _mobileUser ??= await _googleSignIn.signInSilently();
      return _mobileUser != null;
    } else {
      return await _loadDesktopCredentials() != null;
    }
  }

  /// Initiates sign-in process.
  static Future<bool> signIn() async {
    if (kIsWeb) return false;

    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      try {
        _mobileUser = await _googleSignIn.signIn();
        return _mobileUser != null;
      } catch (e) {
        debugPrint('Mobile Google Sign-In error: $e');
        return false;
      }
    } else {
      // Desktop Loopback Auth Flow
      return await _signInDesktop();
    }
  }

  /// Signs out from Google.
  static Future<void> signOut() async {
    if (kIsWeb) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSyncTimeKey);
    await prefs.remove(_oauthCredentialsKey);

    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      await _googleSignIn.signOut();
      _mobileUser = null;
    } else {
      _desktopClient?.close();
      _desktopClient = null;
    }
  }

  /// Get authenticated HTTP client.
  static Future<http.Client?> _getHttpClient() async {
    if (kIsWeb) return null;

    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      _mobileUser ??= await _googleSignIn.signInSilently();
      if (_mobileUser == null) return null;
      final authHeaders = await _mobileUser!.authHeaders;
      return _AuthenticatedClient(authHeaders, http.Client());
    } else {
      _desktopClient ??= await _loadDesktopCredentials();
      return _desktopClient;
    }
  }

  /// Load saved desktop OAuth2 credentials.
  static Future<oauth2.Client?> _loadDesktopCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final credsJson = prefs.getString(_oauthCredentialsKey);
      if (credsJson == null) return null;

      final credentials = oauth2.Credentials.fromJson(credsJson);
      return oauth2.Client(
        credentials,
        identifier: _desktopClientId,
        secret: _desktopClientSecret.isEmpty ? null : _desktopClientSecret,
      );
    } catch (e) {
      debugPrint('Error loading desktop credentials: $e');
      return null;
    }
  }

  /// Saves desktop credentials.
  static Future<void> _saveDesktopCredentials(
    oauth2.Credentials credentials,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_oauthCredentialsKey, credentials.toJson());
  }

  /// Executes Desktop Google OAuth2 Loopback Flow.
  static Future<bool> _signInDesktop() async {
    HttpServer? server;
    try {
      // 1. Bind local loopback server to random available port
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final redirectUri = Uri.parse('http://localhost:${server.port}');

      final grant = oauth2.AuthorizationCodeGrant(
        _desktopClientId,
        Uri.parse(_googleAuthEndpoint),
        Uri.parse(_googleTokenEndpoint),
        secret: _desktopClientSecret.isEmpty ? null : _desktopClientSecret,
      );

      final authorizationUrl = grant.getAuthorizationUrl(
        redirectUri,
        scopes: [drive.DriveApi.driveAppdataScope],
      );

      // 2. Open authorization URL in system browser
      if (await launchUrl(
        authorizationUrl,
        mode: LaunchMode.externalApplication,
      )) {
        debugPrint('Opened browser for Google Sign-In at: $authorizationUrl');
      } else {
        throw Exception('Could not launch system browser');
      }

      // 3. Listen for redirect request
      final request = await server.first;
      final params = request.uri.queryParameters;

      // Send success HTML response to browser
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write(
          '<h1>Authentication Successful!</h1><p>You can close this tab and return to TowiTowi.</p>',
        );
      await request.response.close();

      // 4. Exchange authorization code for tokens
      if (params.containsKey('code')) {
        final client = await grant.handleAuthorizationResponse(params);
        _desktopClient = client;
        await _saveDesktopCredentials(client.credentials);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Desktop OAuth2 authentication failed: $e');
      return false;
    } finally {
      await server?.close(force: true);
    }
  }

  /// Main sync notes logic.
  /// A ConflictResolver callback can be passed in to resolve conflicts interactively.
  static Future<void> syncNotes(
    NotesProvider notesProvider,
    Future<Note?> Function(Note local, Note remote) conflictResolver, {
    SettingsProvider? settingsProvider,
  }) async {
    final client = await _getHttpClient();
    if (client == null) {
      throw Exception('Not signed in to Google Drive');
    }

    try {
      final driveApi = drive.DriveApi(client);

      // 1. Find sync file in appDataFolder space
      final fileList = await driveApi.files.list(
        q: "name = 'towitowi_sync_data.json'",
        spaces: 'appDataFolder',
        $fields: 'files(id, name, modifiedTime)',
      );

      String? syncFileId;
      List<dynamic> remoteNotesJson = [];

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        syncFileId = fileList.files!.first.id;

        // 2. Download remote sync file
        final drive.Media media =
            await driveApi.files.get(
                  syncFileId!,
                  downloadOptions: drive.DownloadOptions.fullMedia,
                )
                as drive.Media;

        final bytes = await media.stream.fold<List<int>>(
          [],
          (p, e) => p..addAll(e),
        );
        final jsonStr = utf8.decode(bytes);
        if (jsonStr.trim().isNotEmpty) {
          remoteNotesJson = json.decode(jsonStr) as List<dynamic>;
        }
      }

      // Parse remote notes
      final remoteNotesMap = {
        for (var item in remoteNotesJson)
          item['id'] as String: DriftNote.fromJson(
            item as Map<String, dynamic>,
          ),
      };

      // Fetch all local notes (including deleted ones/tombstones)
      final localNotesList = await notesProvider.db
          .getAllNotesIncludingDeleted();
      final localNotesMap = {for (var note in localNotesList) note.id: note};

      final prefs = await SharedPreferences.getInstance();
      final lastSyncMillis = prefs.getInt(_lastSyncTimeKey) ?? 0;

      final List<DriftNote> toUpdateLocally = [];
      final List<DriftNote> toUpload = [];
      final Set<String> allIds = {
        ...localNotesMap.keys,
        ...remoteNotesMap.keys,
      };

      for (final id in allIds) {
        final local = localNotesMap[id];
        final remote = remoteNotesMap[id];

        if (local == null && remote != null) {
          // Exists remotely but not locally
          if (remote.deleted == false) {
            toUpdateLocally.add(remote);
          }
        } else if (local != null && remote == null) {
          // Exists locally but not remotely
          if (local.deleted == false) {
            toUpload.add(local);
          }
        } else if (local != null && remote != null) {
          // Exists in both places
          if (local.deleted && remote.deleted) {
            continue;
          } else if (local.deleted && !remote.deleted) {
            // Deleted locally, active remotely
            final localDeleteTime = local.updatedAt ?? local.date;
            final remoteUpdateTime = remote.updatedAt ?? remote.date;

            if (localDeleteTime.isAfter(remoteUpdateTime)) {
              toUpload.add(local); // Upload deletion tombstone
            } else {
              toUpdateLocally.add(
                remote,
              ); // Remote update is newer, restore locally
            }
          } else if (!local.deleted && remote.deleted) {
            // Active locally, deleted remotely
            final localUpdateTime = local.updatedAt ?? local.date;
            final remoteDeleteTime = remote.updatedAt ?? remote.date;

            if (remoteDeleteTime.isAfter(localUpdateTime)) {
              toUpdateLocally.add(remote); // Local is older, delete locally
            } else {
              toUpload.add(
                local,
              ); // Local is newer, upload (re-creating on remote)
            }
          } else {
            // Both are active
            if (local.title == remote.title &&
                local.content == remote.content &&
                local.label == remote.label) {
              continue;
            }

            final localUpdatedTime = local.updatedAt ?? local.date;
            final remoteUpdatedTime = remote.updatedAt ?? remote.date;

            final localChanged =
                localUpdatedTime.millisecondsSinceEpoch > lastSyncMillis;
            final remoteChanged =
                remoteUpdatedTime.millisecondsSinceEpoch > lastSyncMillis;

            if (localChanged && !remoteChanged) {
              toUpload.add(local); // Fast-forward remote
            } else if (!localChanged && remoteChanged) {
              toUpdateLocally.add(remote); // Fast-forward local
            } else {
              // Conflict: Both changed since last sync
              final resolvedNote = await conflictResolver(
                local.toDomainNote(),
                remote.toDomainNote(),
              );

              if (resolvedNote == null) {
                throw Exception(
                  'Sync cancelled by user due to unresolved conflict.',
                );
              }

              // Update local state with resolved choice
              final resolvedDrift = resolvedNote.toDriftNote(
                createdAt: local.createdAt ?? local.date,
                updatedAt: DateTime.now(),
              );

              await notesProvider.db.saveNote(resolvedDrift);
              toUpload.add(resolvedDrift);
            }
          }
        }
      }

      // Write merged changes to local database
      for (final note in toUpdateLocally) {
        await notesProvider.db.saveNote(note);
      }

      // Reload list of notes from local database
      await notesProvider.reloadNotes();

      // Retrieve finalized list of notes from local database to upload to cloud
      final finalizedNotes = await notesProvider.db
          .getAllNotesIncludingDeleted();
      final uploadJsonStr = json.encode(
        finalizedNotes.map((n) => n.toJson()).toList(),
      );
      final uploadBytes = utf8.encode(uploadJsonStr);

      final mediaStream = Stream.value(uploadBytes);
      final driveFile = drive.File()
        ..name = 'towitowi_sync_data.json'
        ..parents = ['appDataFolder'];

      if (syncFileId == null) {
        // Create new sync file
        await driveApi.files.create(
          driveFile,
          uploadMedia: drive.Media(mediaStream, uploadBytes.length),
        );
      } else {
        // Update existing sync file
        await driveApi.files.update(
          drive.File(),
          syncFileId,
          uploadMedia: drive.Media(mediaStream, uploadBytes.length),
        );
      }

      // Save last sync time checkpoint
      await prefs.setInt(
        _lastSyncTimeKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      if (settingsProvider != null) {
        await _syncSettings(driveApi, settingsProvider);
      }
    } catch (e) {
      debugPrint('Sync failed: $e');
      rethrow;
    }
  }

  /// Synchronize settings with Google Drive.
  static Future<void> syncSettings(SettingsProvider settingsProvider) async {
    final client = await _getHttpClient();
    if (client == null) {
      throw Exception('Not signed in to Google Drive');
    }
    final driveApi = drive.DriveApi(client);
    await _syncSettings(driveApi, settingsProvider);
  }

  static Future<void> _syncSettings(
    drive.DriveApi driveApi,
    SettingsProvider settingsProvider,
  ) async {
    try {
      debugPrint('Syncing settings...');
      // 1. Find settings sync file in appDataFolder space
      final fileList = await driveApi.files.list(
        q: "name = 'towitowi_settings_sync.json'",
        spaces: 'appDataFolder',
        $fields: 'files(id, name, modifiedTime)',
      );

      String? syncFileId;
      Map<String, dynamic>? remoteSettings;

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        syncFileId = fileList.files!.first.id;

        // 2. Download remote sync file
        final drive.Media media = await driveApi.files.get(
          syncFileId!,
          downloadOptions: drive.DownloadOptions.fullMedia,
        ) as drive.Media;

        final bytes = await media.stream.fold<List<int>>(
          [],
          (p, e) => p..addAll(e),
        );
        final jsonStr = utf8.decode(bytes);
        if (jsonStr.trim().isNotEmpty) {
          remoteSettings = json.decode(jsonStr) as Map<String, dynamic>;
        }
      }

      final localUpdatedAt = settingsProvider.settingsUpdatedAt;
      final remoteUpdatedAt = remoteSettings != null
          ? (remoteSettings['updated_at'] as int? ?? 0)
          : 0;

      if (remoteUpdatedAt > localUpdatedAt) {
        // Remote is newer, apply remote settings locally
        await settingsProvider.updateSettingsFromSync(
          geminiApiKey: remoteSettings!['geminiApiKey'] as String? ?? '',
          writingStyleInstructionEn:
              remoteSettings['writingStyleInstructionEn'] as String? ?? '',
          writingStyleInstructionId:
              remoteSettings['writingStyleInstructionId'] as String? ?? '',
          writingStyleSamplesEn: List<String>.from(
            remoteSettings['writingStyleSamplesEn'] as List<dynamic>? ?? [],
          ),
          writingStyleSamplesId: List<String>.from(
            remoteSettings['writingStyleSamplesId'] as List<dynamic>? ?? [],
          ),
          updatedAt: remoteUpdatedAt,
        );
        debugPrint('Settings successfully synchronized (remote applied).');
      } else if (localUpdatedAt > remoteUpdatedAt || syncFileId == null) {
        // Local is newer, upload local settings to Google Drive
        final uploadMap = {
          'geminiApiKey': settingsProvider.geminiApiKey,
          'writingStyleInstructionEn':
              settingsProvider.getWritingStyleInstruction('en'),
          'writingStyleInstructionId':
              settingsProvider.getWritingStyleInstruction('id'),
          'writingStyleSamplesEn':
              settingsProvider.getWritingStyleSamples('en'),
          'writingStyleSamplesId':
              settingsProvider.getWritingStyleSamples('id'),
          'updated_at': localUpdatedAt,
        };
        final uploadJsonStr = json.encode(uploadMap);
        final uploadBytes = utf8.encode(uploadJsonStr);

        final mediaStream = Stream.value(uploadBytes);
        final driveFile = drive.File()
          ..name = 'towitowi_settings_sync.json'
          ..parents = ['appDataFolder'];

        if (syncFileId == null) {
          // Create new settings file
          await driveApi.files.create(
            driveFile,
            uploadMedia: drive.Media(mediaStream, uploadBytes.length),
          );
        } else {
          // Update existing settings file
          await driveApi.files.update(
            drive.File(),
            syncFileId,
            uploadMedia: drive.Media(mediaStream, uploadBytes.length),
          );
        }
        debugPrint('Settings successfully synchronized (local uploaded).');
      } else {
        debugPrint('Settings are already up-to-date.');
      }
    } catch (e) {
      debugPrint('Settings sync failed: $e');
      // We don't rethrow to avoid blocking note sync if settings sync fails
    }
  }
}

/// HTTP Client that automatically adds authorization headers for Android/iOS Google Sign-in.
class _AuthenticatedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client;

  _AuthenticatedClient(this._headers, this._client);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}
