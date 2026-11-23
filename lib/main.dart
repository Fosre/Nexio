import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final configured = supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  if (configured) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }
  runApp(NexioApp(backendConfigured: configured));
}

class NexioApp extends StatefulWidget {
  const NexioApp({super.key, required this.backendConfigured});
  final bool backendConfigured;

  @override
  State<NexioApp> createState() => _NexioAppState();
}

class _NexioAppState extends State<NexioApp> {
  ThemeMode mode = ThemeMode.system;

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF3390EC);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Nexio',
      themeMode: mode,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: blue), useMaterial3: true),
      darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: blue, brightness: Brightness.dark),
      ),
      home: widget.backendConfigured
          ? AuthGate(onThemeChanged: (v) => setState(() => mode = v))
          : SetupRequired(onThemeChanged: (v) => setState(() => mode = v)),
    );
  }
}

class SetupRequired extends StatelessWidget {
  const SetupRequired({super.key, required this.onThemeChanged});
  final ValueChanged<ThemeMode> onThemeChanged;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nexio')),
    body: Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.sms_outlined, size: 54, color: Color(0xFF3390EC)),
        const SizedBox(height: 16),
        const Text('Подключите сервер для SMS-входа', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        const Text('Приложение уже содержит экран входа по номеру и код подтверждения. Чтобы SMS действительно приходили на SIM-карту, нужно создать проект Supabase и подключить SMS-провайдера. Без этого отправка кодов не работает.', textAlign: TextAlign.center),
        const SizedBox(height: 18),
        const Text('После настройки соберите APK с параметрами SUPABASE_URL и SUPABASE_ANON_KEY.', textAlign: TextAlign.center),
      ]),
    )),
  );
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.onThemeChanged});
  final ValueChanged<ThemeMode> onThemeChanged;
  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: Supabase.instance.client.auth.onAuthStateChange,
    builder: (context, snapshot) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) return HomeScreen(onThemeChanged: onThemeChanged);
      return PhoneAuthScreen();
    },
  );
}

class PhoneAuthScreen extends StatefulWidget {
  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final phone = TextEditingController();
  final code = TextEditingController();
  bool sent = false, busy = false;
  String? error;

  Future<void> sendCode() async {
    final number = phone.text.trim();
    if (!number.startsWith('+') || number.length < 8) {
      setState(() => error = 'Введите номер в международном формате, например +33… или +7…');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      await Supabase.instance.client.auth.signInWithOtp(phone: number);
      setState(() => sent = true);
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } catch (_) {
      setState(() => error = 'Не удалось отправить SMS. Проверьте настройки SMS-провайдера.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> verifyCode() async {
    setState(() { busy = true; error = null; });
    try {
      await Supabase.instance.client.auth.verifyOTP(
        phone: phone.text.trim(),
        token: code.text.trim(),
        type: OtpType.sms,
      );
    } on AuthException catch (e) {
      setState(() => error = e.message);
    } catch (_) {
      setState(() => error = 'Не удалось проверить код. Попробуйте ещё раз.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() { phone.dispose(); code.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.forum_rounded, size: 64, color: Color(0xFF3390EC)),
          const SizedBox(height: 12),
          const Text('Nexio', textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(sent ? 'Введите код из SMS' : 'Вход или регистрация', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          if (!sent) ...[
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Номер телефона', hintText: '+33 6 12 34 56 78', prefixIcon: Icon(Icons.phone), border: OutlineInputBorder())),
            const SizedBox(height: 14),
            FilledButton(onPressed: busy ? null : sendCode, child: Text(busy ? 'Отправка…' : 'Получить код')),
          ] else ...[
            Text('Код отправлен на ${phone.text}', textAlign: TextAlign.center),
            const SizedBox(height: 14),
            TextField(controller: code, keyboardType: TextInputType.number, maxLength: 6, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: 'Код из SMS', border: OutlineInputBorder())),
            FilledButton(onPressed: busy ? null : verifyCode, child: Text(busy ? 'Проверка…' : 'Подтвердить')),
            TextButton(onPressed: () => setState(() { sent = false; code.clear(); }), child: const Text('Изменить номер')),
          ],
          if (error != null) ...[const SizedBox(height: 12), Text(error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)],
          const SizedBox(height: 18),
          const Text('Продолжая, вы подтверждаете, что имеете право использовать этот номер телефона.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
        ],
      )),
    ))),
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onThemeChanged});
  final ValueChanged<ThemeMode> onThemeChanged;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;
  final chats = <Map<String, String>>[
    {'name': 'Команда Nexio', 'message': 'Добро пожаловать!', 'emoji': '🚀'},
    {'name': 'Друзья', 'message': 'Отправили стикер', 'emoji': '😎'},
    {'name': 'Объявления', 'message': 'Новости проекта', 'emoji': '📢'},
  ];
  @override
  Widget build(BuildContext context) {
    final titles = ['Чаты', 'Контакты', 'Каналы', 'Звонки', 'Настройки'];
    return Scaffold(
      appBar: AppBar(title: Text(titles[tab]), actions: [
        if (tab == 0) IconButton(icon: const Icon(Icons.search), onPressed: () => showSearch(context: context, delegate: ChatSearch(chats))),
      ]),
      body: switch (tab) {
        0 => ListView(children: [
          for (final c in chats) ListTile(
            leading: CircleAvatar(child: Text(c['emoji']!)),
            title: Text(c['name']!), subtitle: Text(c['message']!),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(name: c['name']!))),
          ),
        ]),
        1 => const Center(child: Text('Контакты появятся после подключения синхронизации')),
        2 => const Center(child: Text('Каналы Nexio')),
        3 => const Center(child: Text('Здесь будут звонки')),
        _ => ListView(children: [
          ListTile(leading: const Icon(Icons.palette_outlined), title: const Text('Светлая тема'), onTap: () => widget.onThemeChanged(ThemeMode.light)),
          ListTile(leading: const Icon(Icons.dark_mode_outlined), title: const Text('Тёмная тема'), onTap: () => widget.onThemeChanged(ThemeMode.dark)),
          ListTile(leading: const Icon(Icons.phone_android), title: const Text('Выйти из аккаунта'), onTap: () async => Supabase.instance.client.auth.signOut()),
        ]),
      },
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (v) => setState(() => tab = v), destinations: const [
        NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Чаты'),
        NavigationDestination(icon: Icon(Icons.people_outline), label: 'Контакты'),
        NavigationDestination(icon: Icon(Icons.campaign_outlined), label: 'Каналы'),
        NavigationDestination(icon: Icon(Icons.call_outlined), label: 'Звонки'),
        NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Настройки'),
      ]),
    );
  }
}

class ChatSearch extends SearchDelegate<String> {
  ChatSearch(this.chats);
  final List<Map<String, String>> chats;
  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear))];
  @override
  Widget? buildLeading(BuildContext context) => BackButton(onPressed: () => close(context, ''));
  @override
  Widget buildResults(BuildContext context) => buildSuggestions(context);
  @override
  Widget buildSuggestions(BuildContext context) => ListView(children: [
    for (final c in chats.where((e) => e['name']!.toLowerCase().contains(query.toLowerCase())))
      ListTile(title: Text(c['name']!), subtitle: Text(c['message']!), onTap: () => close(context, c['name']!)),
  ]);
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.name});
  final String name;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final input = TextEditingController();
  final messages = <String>['Привет! Это Nexio 👋', 'Здесь появятся ваши сообщения после подключения сервера.'];
  final stickers = const ['🚀','💙','😂','🔥','👀','🥳','❤️','👍','🤝','✨','😎','🎉','🐱','🌈','💬','⭐'];
  void send(String value) {
    if (value.trim().isEmpty) return;
    setState(() => messages.add(value.trim()));
    input.clear();
  }
  void openStickers() {
    showModalBottomSheet(context: context, showDragHandle: true, builder: (ctx) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Стикеры Nexio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        GridView.count(shrinkWrap: true, crossAxisCount: 4, children: [
          for (final s in stickers) InkWell(onTap: () { Navigator.pop(ctx); send(s); }, child: Center(child: Text(s, style: const TextStyle(fontSize: 38)))),
        ]),
      ]),
    ));
  }
  @override
  void dispose() { input.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.name)),
    body: Column(children: [
      Expanded(child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: messages.length, itemBuilder: (_, i) => Align(
        alignment: Alignment.centerRight,
        child: Container(margin: const EdgeInsets.symmetric(vertical: 4), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(16)), child: Text(messages[i], style: TextStyle(fontSize: messages[i].length < 5 ? 32 : 15))),
      ))),
      SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 8), child: Row(children: [
        IconButton(onPressed: openStickers, icon: const Icon(Icons.emoji_emotions_outlined)),
        Expanded(child: TextField(controller: input, decoration: const InputDecoration(hintText: 'Сообщение', border: OutlineInputBorder(), isDense: true), onSubmitted: send)),
        IconButton(onPressed: () => send(input.text), icon: const Icon(Icons.send, color: Color(0xFF3390EC))),
      ]))),
    ]),
  );
}
