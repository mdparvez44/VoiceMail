import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'services/voicemail_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(const PersonalButlerApp());
}

const background = Color(0xFF101010);
const surface = Color(0xFF1C1C1E);
const gold = Color(0xFFC9A96E);
const muted = Color(0xFF999999);

class PersonalButlerApp extends StatelessWidget {
  const PersonalButlerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Personal Butler',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(primary: gold, surface: surface),
        useMaterial3: true,
      ),
      home: const ButlerHome(),
    );
  }
}

class ButlerHome extends StatefulWidget {
  const ButlerHome({super.key});

  @override
  State<ButlerHome> createState() => _ButlerHomeState();
}

class _ButlerHomeState extends State<ButlerHome> with WidgetsBindingObserver {
  static const platform = MethodChannel('personal_butler/settings');

  String selectedMode = 'General';
  bool butlerEnabled = false;
  int selectedTab = 0;

  String customMessage = "I'm currently unavailable. Please leave a message.";

  final customMessageController = TextEditingController();

  List<Map<String, Object?>> voicemails = [];
  bool isLoadingMessages = false;
  String? inboxError;

  final modes = const [
    ('Sleeping', Icons.nightlight_round, 'Rest without interruptions'),
    ('Reading', Icons.menu_book_rounded, 'Enjoy some quiet time'),
    ('At Work', Icons.work_outline_rounded, 'Focus on your work'),
    ('Custom', Icons.tune_rounded, 'Set your own message'),
    ('General', Icons.notifications_none_rounded, 'Your default setting'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _refreshVoicemails();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    customMessageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadSettings();

      if (selectedTab == 1) {
        _refreshVoicemails();
      }
    }
  }

  Future<void> _refreshVoicemails() async {
    if (mounted) {
      setState(() {
        isLoadingMessages = true;
        inboxError = null;
      });
    }

    try {
      final messages = await VoicemailDatabase.instance.getVoicemails();

      if (!mounted) return;

      setState(() {
        voicemails = messages;
        isLoadingMessages = false;
      });
    } catch (e) {
      debugPrint('Could not load voicemails: $e');

      if (!mounted) return;

      setState(() {
        isLoadingMessages = false;
        inboxError = 'Unable to load messages. Please try again.';
      });
    }
  }

  Future<void> _addTestVoicemail() async {
    final nameController = TextEditingController(text: 'Test Caller');
    final phoneController = TextEditingController(text: 'Unknown number');

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: surface,
          title: const Text('Add test message'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Caller name',
                  hintText: 'e.g. Alex',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: 'e.g. +91 98765 43210',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This creates a test record only. It does not record audio.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    final callerName = nameController.text.trim();
    final phoneNumber = phoneController.text.trim();

    nameController.dispose();
    phoneController.dispose();

    if (shouldSave != true || !mounted) return;

    if (callerName.isEmpty || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter both the caller name and phone number.'),
        ),
      );
      return;
    }

    try {
      await VoicemailDatabase.instance.addVoicemail(
        callerName: callerName,
        phoneNumber: phoneNumber,
      );

      await _refreshVoicemails();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Test message saved.')));
    } catch (e) {
      debugPrint('Could not save test voicemail: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the message.')),
      );
    }
  }

  Future<void> _markMessageAsRead(int id) async {
    try {
      await VoicemailDatabase.instance.markAsRead(id);
      await _refreshVoicemails();
    } catch (e) {
      debugPrint('Could not mark message as read: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update the message.')),
      );
    }
  }

  Future<void> _deleteVoicemail(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: surface,
          title: const Text('Delete message?'),
          content: const Text(
            'This will permanently remove this message record.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await VoicemailDatabase.instance.deleteVoicemail(id);
      await _refreshVoicemails();

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message deleted.')));
    } catch (e) {
      debugPrint('Could not delete voicemail: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete the message.')),
      );
    }
  }

  String _formatDate(String? value) {
    if (value == null) return 'Unknown date';

    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return 'Unknown date';

    String twoDigits(int number) => number.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  String _formatDuration(Object? value) {
    final seconds = value is int ? value : 0;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _loadSettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final settings = await platform.invokeMapMethod<String, dynamic>(
        'getSettings',
      );

      if (!mounted || settings == null) return;

      setState(() {
        butlerEnabled = settings['enabled'] as bool? ?? false;
        selectedMode = settings['mode'] as String? ?? 'General';
        customMessage =
            settings['customMessage'] as String? ??
            "I'm currently unavailable. Please leave a message.";
      });
    } on PlatformException catch (e) {
      debugPrint('Could not load Butler settings: ${e.message}');
    } on MissingPluginException catch (e) {
      debugPrint('Butler settings channel is unavailable: $e');
    }
  }

  Future<void> _setEnabled(bool value) async {
    setState(() => butlerEnabled = value);

    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      await platform.invokeMethod<void>('setEnabled', {'enabled': value});
    } on PlatformException catch (e) {
      debugPrint('Could not save Butler status: ${e.message}');
    } on MissingPluginException catch (e) {
      debugPrint('Butler settings channel is unavailable: $e');
    }
  }

  Future<void> _setMode(String mode) async {
    setState(() => selectedMode = mode);

    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      await platform.invokeMethod<void>('setMode', {'mode': mode});
    } on PlatformException catch (e) {
      debugPrint('Could not save Butler mode: ${e.message}');
    } on MissingPluginException catch (e) {
      debugPrint('Butler settings channel is unavailable: $e');
    }
  }

  Future<void> _showCustomMessageDialog() async {
    customMessageController.text = customMessage;

    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: surface,
          title: const Text('Your custom message'),
          content: TextField(
            controller: customMessageController,
            autofocus: true,
            maxLines: 4,
            maxLength: 300,
            decoration: const InputDecoration(
              hintText: 'Write the message your Butler should use...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  customMessageController.text.trim(),
                );
              },
              child: const Text('Save message'),
            ),
          ],
        );
      },
    );

    if (message == null || !mounted) return;

    setState(() {
      customMessage = message;
      selectedMode = 'Custom';
    });

    await _saveCustomMessage(message);
    await _setMode('Custom');
  }

  Future<void> _saveCustomMessage(String message) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    try {
      await platform.invokeMethod<void>('setCustomMessage', {
        'message': message,
      });
    } on PlatformException catch (e) {
      debugPrint('Could not save custom message: ${e.message}');
    } on MissingPluginException catch (e) {
      debugPrint('Custom message storage is unavailable: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: selectedTab == 0 ? dashboard() : inbox()),
      bottomNavigationBar: NavigationBar(
        backgroundColor: surface,
        indicatorColor: gold.withValues(alpha: 0.18),
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() => selectedTab = index);

          if (index == 1) {
            _refreshVoicemails();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.door_front_door_outlined),
            selectedIcon: Icon(Icons.door_front_door, color: gold),
            label: 'Butler',
          ),
          NavigationDestination(
            icon: Icon(Icons.voicemail_rounded),
            selectedIcon: Icon(Icons.voicemail_rounded, color: gold),
            label: 'Messages',
          ),
        ],
      ),
    );
  }

  Widget dashboard() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
      children: [
        Row(
          children: [
            const Icon(Icons.circle, color: gold, size: 10),
            const SizedBox(width: 9),
            const Text(
              'PERSONAL BUTLER',
              style: TextStyle(
                color: gold,
                fontSize: 12,
                letterSpacing: 3,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
            ),
          ],
        ),
        const SizedBox(height: 32),
        const Center(
          child: Icon(
            Icons.notifications_active_outlined,
            size: 54,
            color: gold,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'At your service.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w300),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your time. Your terms.',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 14),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: butlerEnabled
                  ? gold.withValues(alpha: 0.65)
                  : Colors.white12,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Butler Service',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Switch(
                    value: butlerEnabled,
                    activeThumbColor: gold,
                    onChanged: _setEnabled,
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  butlerEnabled ? 'Service is enabled' : 'Service is resting',
                  style: const TextStyle(color: muted, fontSize: 13),
                ),
              ),
              const SizedBox(height: 18),
              const Divider(color: Colors.white12),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.style_outlined, color: gold),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Current mode', style: TextStyle(color: muted)),
                  ),
                  Text(
                    selectedMode,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          'YOUR PREFERENCES',
          style: TextStyle(
            color: muted,
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        ...modes.map((mode) {
          final isSelected = selectedMode == mode.$1;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: isSelected ? gold.withValues(alpha: 0.10) : surface,
              borderRadius: BorderRadius.circular(15),
              child: InkWell(
                borderRadius: BorderRadius.circular(15),
                onTap: () {
                  if (mode.$1 == 'Custom') {
                    _showCustomMessageDialog();
                  } else {
                    _setMode(mode.$1);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isSelected ? gold : Colors.white10,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(mode.$2, color: isSelected ? gold : muted, size: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mode.$1,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              mode.$3,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: gold, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 10),
        const Text(
          'QUICK ACCESS',
          style: TextStyle(
            color: muted,
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Row(
            children: [
              Icon(Icons.grid_view_rounded, color: gold),
              SizedBox(width: 12),
              Expanded(child: Text('Android Quick Settings tile')),
              Icon(Icons.build_outlined, color: muted, size: 19),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Control your Butler from Android Quick Settings.',
          style: TextStyle(color: muted, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget inbox() {
    return RefreshIndicator(
      color: gold,
      onRefresh: _refreshVoicemails,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The message room',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your saved message records.',
                      style: TextStyle(color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _addTestVoicemail,
                icon: const Icon(Icons.add, size: 19),
                label: const Text('Add test'),
                style: FilledButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: background,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (isLoadingMessages && voicemails.isEmpty)
            const Padding(
              padding: EdgeInsets.all(36),
              child: Center(child: CircularProgressIndicator(color: gold)),
            )
          else if (inboxError != null && voicemails.isEmpty)
            _inboxMessage(
              icon: Icons.error_outline,
              title: 'Could not load messages',
              subtitle: inboxError!,
              action: TextButton.icon(
                onPressed: _refreshVoicemails,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            )
          else if (voicemails.isEmpty)
            _inboxMessage(
              icon: Icons.mark_email_unread_outlined,
              title: 'No messages yet',
              subtitle:
                  'Add a test message to try out your local voicemail inbox.',
            )
          else ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'SAVED MESSAGES',
                    style: TextStyle(
                      color: muted,
                      fontSize: 11,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${voicemails.length} '
                  '${voicemails.length == 1 ? 'message' : 'messages'}',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...voicemails.map(_voicemailCard),
          ],
          const SizedBox(height: 18),
          const Text(
            'Test entries are saved on this device. Audio recording is not '
            'implemented yet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _inboxMessage({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: gold),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted),
          ),
          if (action != null) ...[const SizedBox(height: 12), action],
        ],
      ),
    );
  }

  Widget _voicemailCard(Map<String, Object?> message) {
    final id = message['id'] as int;
    final callerName = message['callerName'] as String? ?? 'Unknown caller';
    final phoneNumber = message['phoneNumber'] as String? ?? 'Unknown number';
    final createdAt = message['createdAt'] as String?;
    final duration = message['durationSeconds'];
    final isRead = (message['isRead'] as int? ?? 0) == 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isRead ? null : () => _markMessageAsRead(id),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isRead ? Colors.white10 : gold.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.voicemail_rounded,
                    color: gold,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              callerName,
                              style: TextStyle(
                                fontWeight: isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: gold,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        phoneNumber,
                        style: const TextStyle(color: muted, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatDate(createdAt),
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 14, color: muted),
                          const SizedBox(width: 5),
                          Text(
                            'Duration: ${_formatDuration(duration)}',
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                          const Spacer(),
                          if (!isRead)
                            const Text(
                              'Unread',
                              style: TextStyle(
                                color: gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          else
                            const Text(
                              'Read',
                              style: TextStyle(color: muted, fontSize: 11),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Delete message',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _deleteVoicemail(id),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: muted,
                    size: 21,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
