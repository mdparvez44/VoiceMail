import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
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
    }
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
            Text(
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

        // Butler service control
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

        // Butler mode selection cards
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
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const SizedBox(height: 18),
        const Text(
          'The message room',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w300),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your recorded messages will be kept here.',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 30),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: const Column(
            children: [
              Icon(Icons.mark_email_unread_outlined, size: 48, color: gold),
              SizedBox(height: 18),
              Text(
                'No messages yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Any saved voicemail recordings will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
