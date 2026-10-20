import '../services/windows_credentials.dart';
import '../services/access_control.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/app_language_provider.dart';
import '../services/app_profile.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _passwordFocus = FocusNode();
  bool _showPassword = false;
  bool _submitting = false;
  bool _useInAppFields = false;
  String? _error;
  bool get _testProfile => context.read<AppProfile?>()?.isTest ?? false;
  String t(String en, String ar) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool get _native =>
      Theme.of(context).platform == TargetPlatform.windows && !_useInAppFields;

  Future<void> _submit({bool testShortcut = false}) async {
    final auth = context.read<AuthService>();
    if (_submitting || auth.busy) return;
    final useTestAccount = testShortcut && _testProfile;
    if (!useTestAccount && !_native && !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      String name = _name.text.trim(), password = _password.text;
      if (useTestAccount) {
        name = AppProfile.testerName;
        password = AppProfile.testerPassword;
      } else if (_native) {
        final credentials =
            await WindowsCredentials.prompt(setup: auth.needsSetup);
        if (credentials == null || !mounted) return;
        name = credentials['name']?.trim() ?? '';
        password = credentials['password'] ?? '';
      }
      if (name.isEmpty || password.isEmpty) {
        throw ArgumentError(t(
            'Enter a username and password', 'أدخل اسم المستخدم وكلمة المرور'));
      }
      if (auth.needsSetup && (password.length < 12 || password.length > 128)) {
        throw ArgumentError(t('Password must contain 12–128 characters',
            'يجب أن تتكون كلمة المرور من ١٢ إلى ١٢٨ حرفاً'));
      }
      if (auth.needsSetup) {
        await auth.saveUser(name: name, role: 'owner', password: password);
      }
      await auth.login(name, password);
    } catch (e) {
      if (mounted) setState(() => _error = _authenticationError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _authenticationError(Object error) {
    if (error is StateError &&
        error.message == 'Invalid username or password.') {
      return t(
          'The username or password is incorrect. Use the account created on this computer. For trial access, open START-TEST.cmd in the Windows package.',
          'اسم المستخدم أو كلمة المرور غير صحيحة. استخدم الحساب الذي أنشأته على هذا الجهاز. للتجربة افتح START-TEST.cmd من حزمة ويندوز.');
    }
    if (error is StateError &&
        error.message == 'Account is inactive or temporarily locked.') {
      return t(
          'This account is inactive or locked after repeated attempts. Wait 5 minutes, or contact the local owner.',
          'الحساب معطل أو مقفل بعد محاولات متكررة. انتظر ٥ دقائق أو تواصل مع مالك النظام على هذا الجهاز.');
    }
    return error.toString();
  }

  Future<void> _openTestWorkspace() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await WindowsCredentials.openTestWorkspace();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final busy = auth.busy || _submitting;
    return Scaffold(
      appBar: AppBar(
        title: Text(t('Detergent Factory', 'مصنع المنظفات')),
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: t('Language', 'اللغة'),
            onPressed: busy
                ? null
                : () => context.read<AppLanguageProvider>().changeLanguage(
                    Locale(Localizations.localeOf(context).languageCode == 'ar'
                        ? 'en'
                        : 'ar')),
          )
        ],
      ),
      body: Center(
          child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Form(
            key: _form,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                if (_testProfile) ...[
                  Text(t('Try the ERP', 'تجربة نظام ERP'),
                      style: Theme.of(context).textTheme.headlineSmall),
                  Text(t(
                      'Start immediately with the tester account. Test records are saved separately on this computer.',
                      'ابدأ مباشرة بحساب التجربة. تُحفظ سجلات التجربة بشكل منفصل على هذا الجهاز.')),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const ValueKey('test-sign-in'),
                    onPressed: busy ? null : () => _submit(testShortcut: true),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(t('Enter test app', 'دخول التطبيق التجريبي')),
                  ),
                  const SizedBox(height: 12),
                  const SelectableText(
                      'Username: ${AppProfile.testerName}\nPassword: ${AppProfile.testerPassword}',
                      textDirection: TextDirection.ltr),
                  const Divider(height: 32),
                ],
                Text(
                    auth.needsSetup
                        ? t('Create the first owner account',
                            'إنشاء حساب المالك الأول')
                        : t('Sign in', 'تسجيل الدخول'),
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                if (_native)
                  Text(t(
                      'Click the button below to enter your local ERP username and password in the Windows dialog.',
                      'اضغط الزر أدناه لإدخال اسم المستخدم وكلمة المرور الخاصة بالتطبيق في نافذة ويندوز.')),
                if (!_native) ...[
                  TextFormField(
                    key: const ValueKey('auth-username'),
                    controller: _name,
                    readOnly: busy,
                    autocorrect: false,
                    enableSuggestions: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    spellCheckConfiguration:
                        const SpellCheckConfiguration.disabled(),
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? t('Enter your username', 'أدخل اسم المستخدم')
                        : null,
                    decoration: InputDecoration(
                        labelText: t('Username', 'اسم المستخدم')),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('auth-password'),
                    controller: _password,
                    focusNode: _passwordFocus,
                    readOnly: busy,
                    obscureText: !_showPassword,
                    textDirection: TextDirection.ltr,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    spellCheckConfiguration:
                        const SpellCheckConfiguration.disabled(),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return t('Enter your password', 'أدخل كلمة المرور');
                      }
                      if (auth.needsSetup &&
                          (v.length < 12 || v.length > 128)) {
                        return t('Password must contain 12–128 characters',
                            'يجب أن تتكون كلمة المرور من ١٢ إلى ١٢٨ حرفاً');
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      labelText: t('Password', 'كلمة المرور'),
                      suffixIcon: IconButton(
                        tooltip: _showPassword
                            ? t('Hide password', 'إخفاء كلمة المرور')
                            : t('Show password', 'إظهار كلمة المرور'),
                        onPressed: busy
                            ? null
                            : () =>
                                setState(() => _showPassword = !_showPassword),
                        icon: Icon(_showPassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                      ),
                    ),
                  ),
                ],
                if (auth.needsSetup)
                  Text(t(
                      'Use 12–128 characters. Keep this owner password secure. Accounts belong to this installation and are separate from business backups.',
                      'استخدم ١٢–١٢٨ حرفاً واحفظ كلمة مرور المالك بأمان. الحسابات خاصة بهذا الجهاز ومنفصلة عن النسخ الاحتياطية التجارية.')),
                if (_error != null) Text(_error!),
                const SizedBox(height: 16),
                FilledButton(
                    key: const ValueKey('auth-submit'),
                    onPressed: busy ? null : _submit,
                    child: Text(_native
                        ? t('Enter credentials and sign in',
                            'إدخال بيانات الحساب وتسجيل الدخول')
                        : auth.needsSetup
                            ? t('Create owner and sign in',
                                'إنشاء المالك وتسجيل الدخول')
                            : t('Sign in', 'تسجيل الدخول'))),
                if (_native)
                  TextButton(
                      onPressed: busy
                          ? null
                          : () => setState(() => _useInAppFields = true),
                      child: Text(t(
                          'Use in-app fields', 'استخدام الحقول داخل التطبيق'))),
                if (!_testProfile &&
                    Theme.of(context).platform == TargetPlatform.windows) ...[
                  const Divider(height: 24),
                  OutlinedButton.icon(
                    key: const ValueKey('open-test-workspace'),
                    onPressed: busy ? null : _openTestWorkspace,
                    icon: const Icon(Icons.science_outlined),
                    label: Text(t('Open test workspace — no password needed',
                        'فتح بيئة التجربة — دون الحاجة لكلمة مرور')),
                  ),
                  Text(t(
                      'A separate window opens with the tester account and its own test records.',
                      'تفتح نافذة منفصلة بحساب التجربة وسجلاتها المستقلة.')),
                ],
                if (busy) const LinearProgressIndicator(),
              ],
            )),
      )),
    );
  }
}

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});
  String t(BuildContext c, String en, String ar) =>
      Localizations.localeOf(c).languageCode == 'ar' ? ar : en;
  Future<void> _edit(BuildContext context, Map<String, dynamic>? user) async {
    final auth = context.read<AuthService>();
    String name = user?['name'] ?? '',
        role = user?['role'] ?? 'viewer',
        password = '';
    bool active = user?['active'] ?? true, saving = false;
    String? error;
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, update) => PopScope(
                canPop: !saving,
                child: AlertDialog(
                    title: Text(t(context, 'User account', 'حساب المستخدم')),
                    content: SizedBox(
                        width: 440,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              TextFormField(
                                  initialValue: name,
                                  enabled: !saving,
                                  onChanged: (v) => name = v,
                                  decoration: InputDecoration(
                                      labelText: t(context, 'Username',
                                          'اسم المستخدم'))),
                              DropdownButtonFormField<String>(
                                  initialValue: role,
                                  isExpanded: true,
                                  items: AuthService.roles
                                      .map((r) => DropdownMenuItem(
                                          value: r, child: Text(r)))
                                      .toList(),
                                  onChanged: saving ? null : (v) => role = v!),
                              TextField(
                                  enabled: !saving,
                                  obscureText: true,
                                  maxLength: 128,
                                  onChanged: (v) => password = v,
                                  decoration: InputDecoration(
                                      labelText: t(
                                          context,
                                          'New password (blank keeps current)',
                                          'كلمة مرور جديدة (الفراغ يحتفظ بالحالية)'))),
                              SwitchListTile(
                                  value: active,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(t(context, 'Active', 'نشط')),
                                  onChanged: saving
                                      ? null
                                      : (v) => update(() => active = v)),
                              if (error != null) Text(error!),
                              if (saving) const LinearProgressIndicator()
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: saving ? null : () => Navigator.pop(ctx),
                          child: Text(t(context, 'Cancel', 'إلغاء'))),
                      FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  update(() {
                                    saving = true;
                                    error = null;
                                  });
                                  try {
                                    await auth.saveUser(
                                        id: user?['id'],
                                        name: name,
                                        role: role,
                                        password: password,
                                        active: active);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      update(() {
                                        saving = false;
                                        error = e.toString();
                                      });
                                    }
                                  }
                                },
                          child: Text(t(context, 'Save user', 'حفظ المستخدم')))
                    ]))));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!AccessControl.allows('admin')) {
      return Scaffold(
          appBar: AppBar(),
          body: Center(
              child: Text(t(
                  context, 'Owner access required', 'صلاحية المالك مطلوبة'))));
    }
    return Scaffold(
        appBar: AppBar(
            title: Text(t(context, 'Users & roles', 'المستخدمون والصلاحيات'))),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  FilledButton.icon(
                      onPressed: auth.busy ? null : () => _edit(context, null),
                      icon: const Icon(Icons.person_add),
                      label: Text(t(context, 'New user', 'مستخدم جديد'))),
                  for (final u in auth.users)
                    ListTile(
                        title: Text(u['name']),
                        subtitle: Text(
                            '${u['role']} • ${u['active'] ? t(context, 'Active', 'نشط') : t(context, 'Inactive', 'غير نشط')}'),
                        trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: t(context, 'Edit', 'تعديل'),
                            onPressed:
                                auth.busy ? null : () => _edit(context, u)))
                ]))));
  }
}
