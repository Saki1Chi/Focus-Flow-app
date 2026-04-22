import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../providers/social_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // Login fields
  final _loginUsernameCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();

  // Register fields
  final _regUsernameCtrl    = TextEditingController();
  final _regDisplayNameCtrl = TextEditingController();
  final _regEmailCtrl       = TextEditingController();
  final _regPasswordCtrl    = TextEditingController();
  final _regBioCtrl         = TextEditingController();
  String _selectedEmoji  = '🧑';

  bool _obscureLogin = true;
  bool _obscureReg   = true;

  static const _emojiOptions = ['🧑','👩','👨','🧑‍💻','👩‍💻','🦊','🐼','🚀','⚡','🎯'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _loginUsernameCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _regUsernameCtrl.dispose();
    _regDisplayNameCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPasswordCtrl.dispose();
    _regBioCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent  = ref.watch(settingsProvider).accentColor;
    final social  = ref.watch(socialProvider);
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    // Show error snackbar
    ref.listen<SocialState>(socialProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(socialProvider.notifier).clearError();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accent.withValues(alpha: 0.3)),
                    ),
                    child: Icon(Icons.people_rounded, color: accent, size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'FocusFlow Social',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Conecta, compite y crece con tu red',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  // ── Tab bar ──────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: TabBar(
                      controller: _tabCtrl,
                      indicator: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey,
                      labelStyle: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Iniciar sesión'),
                        Tab(text: 'Registrarse'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Tab content ─────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildLoginTab(accent, social),
                  _buildRegisterTab(accent, social),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Login tab ────────────────────────────────────────────────────────────

  Widget _buildLoginTab(Color accent, SocialState social) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _field(
            controller: _loginUsernameCtrl,
            label: 'Username',
            icon: Icons.person_outline_rounded,
            accent: accent,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _loginPasswordCtrl,
            label: 'Contraseña',
            icon: Icons.lock_outline_rounded,
            accent: accent,
            obscure: _obscureLogin,
            toggleObscure: () =>
                setState(() => _obscureLogin = !_obscureLogin),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: social.isLoading ? null : _doLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: social.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Entrar',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Register tab ─────────────────────────────────────────────────────────

  Widget _buildRegisterTab(Color accent, SocialState social) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // Avatar picker
          Text('Avatar',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600])),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _emojiOptions.map((e) {
              final selected = e == _selectedEmoji;
              return GestureDetector(
                onTap: () => setState(() => _selectedEmoji = e),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected
                        ? accent.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? accent
                          : Colors.grey.withValues(alpha: 0.25),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                      child: Text(e, style: const TextStyle(fontSize: 22))),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _field(
                  controller: _regUsernameCtrl,
                  label: 'Username *',
                  icon: Icons.alternate_email_rounded,
                  accent: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(
                  controller: _regDisplayNameCtrl,
                  label: 'Nombre visible *',
                  icon: Icons.badge_outlined,
                  accent: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _field(
            controller: _regEmailCtrl,
            label: 'Email (opcional)',
            icon: Icons.email_outlined,
            accent: accent,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 14),
          _field(
            controller: _regPasswordCtrl,
            label: 'Contraseña *',
            icon: Icons.lock_outline_rounded,
            accent: accent,
            obscure: _obscureReg,
            toggleObscure: () =>
                setState(() => _obscureReg = !_obscureReg),
          ),
          const SizedBox(height: 14),
          _field(
            controller: _regBioCtrl,
            label: 'Bio (opcional)',
            icon: Icons.edit_note_rounded,
            accent: accent,
            maxLines: 2,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: social.isLoading ? null : _doRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: social.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Crear cuenta',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────────

  Future<void> _doLogin() async {
    final username = _loginUsernameCtrl.text.trim();
    final password = _loginPasswordCtrl.text;
    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa todos los campos'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await ref
        .read(socialProvider.notifier)
        .login(username: username, password: password);
  }

  Future<void> _doRegister() async {
    final username = _regUsernameCtrl.text.trim();
    final display  = _regDisplayNameCtrl.text.trim();
    final password = _regPasswordCtrl.text;
    if (username.isEmpty || display.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username, nombre y contraseña son requeridos'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await ref.read(socialProvider.notifier).register(
          username: username,
          displayName: display,
          password: password,
          email: _regEmailCtrl.text.trim().isEmpty
              ? null
              : _regEmailCtrl.text.trim(),
          avatarEmoji: _selectedEmoji,
          bio: _regBioCtrl.text.trim(),
        );
  }

  // ─── Reusable field ───────────────────────────────────────────────────────

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color accent,
    bool obscure = false,
    VoidCallback? toggleObscure,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: toggleObscure != null
            ? IconButton(
                icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18),
                onPressed: toggleObscure,
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
