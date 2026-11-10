import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/router.dart';
import '../../app/shell.dart';
import '../../models/building.dart';
import '../../models/user.dart';
import '../../providers/app_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/ui.dart';

/// 내 계정 관리 — 아이디·비밀번호 바꾸기, 로그아웃.
/// 관리자는 같이 쓰는 사람의 계정까지(추가·권한·볼 수 있는 건물·비밀번호 새로 정하기·지우기).
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  UserAccount? _me;
  List<UserAccount>? _users; // 관리자만
  Object? _error;

  ApiService get _api => context.read<AppProvider>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final me = await _api.getAccount();
      final users = me.isAdmin ? await _api.getUsers() : null;
      if (!mounted) return;
      setState(() {
        _me = me;
        _users = users;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _changeUsername() async {
    final me = _me!;
    final ok = await showDialog<bool>(context: context, useRootNavigator: true, builder: (_) => _UsernameDialog(current: me.username));
    if (ok != true || !mounted) return;
    showSnack(context, '아이디를 바꿨습니다. 다음 로그인부터 새 아이디로 들어오세요');
    _load();
  }

  Future<void> _changePassword() async {
    final ok = await showDialog<bool>(context: context, useRootNavigator: true, builder: (_) => const _PasswordDialog());
    if (ok != true || !mounted) return;
    showSnack(context, '비밀번호를 바꿨습니다. 다른 기기에서는 다시 로그인해야 합니다');
  }

  /// 내 계정 지우기 — 앱스토어 규정(계정을 만들 수 있는 앱은 앱 안에서 지우기도 돼야 한다).
  Future<void> _deleteMe() async {
    final ok = await showDialog<bool>(context: context, useRootNavigator: true, builder: (_) => const _DeleteMeDialog());
    if (ok != true || !mounted) return;
    showSnack(context, '계정을 지웠습니다');
    await signOut(context);
  }

  Future<void> _editUser(UserAccount? user) async {
    final p = context.read<AppProvider>();
    var buildings = p.buildings;
    if (buildings.isEmpty) {
      try {
        buildings = await p.api.getBuildings();
      } catch (_) {}
    }
    if (!mounted) return;
    final done = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (_) => _UserEditor(user: user, buildings: buildings, taken: [for (final u in _users ?? const <UserAccount>[]) u.username]),
    );
    if (done == null || !mounted) return;
    showSnack(context, done);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final bid = context.read<AppProvider>().buildingId;
    final me = _me;
    return Scaffold(
      appBar: buildingAppBar(context, '내 계정 관리', back: '/b/$bid/settings'),
      body: _error != null && me == null
          ? ListView(padding: const EdgeInsets.all(BillySpace.gutter), children: [
              ContentWidth(max: 720, child: ErrorBanner(message: errorText(_error!), onRetry: _load)),
            ])
          : me == null
              ? const LoadingView()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(BillySpace.gutter, BillySpace.lg, BillySpace.gutter, BillySpace.xxxl),
                    children: [
                      ContentWidth(
                        max: 720,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _MeCard(me: me),
                            const SizedBox(height: BillySpace.md),
                            BillyCard(
                              padding: const EdgeInsets.symmetric(vertical: BillySpace.xs),
                              child: Column(children: [
                                _ActionTile(icon: Icons.badge_outlined, title: '아이디 바꾸기', subtitle: '지금 아이디 ${me.username}', onTap: _changeUsername),
                                const Divider(height: 1),
                                _ActionTile(
                                  icon: Icons.lock_outline_rounded,
                                  title: '비밀번호 바꾸기',
                                  subtitle: '10자 이상, 띄어쓰기 없이',
                                  onTap: _changePassword,
                                ),
                                const Divider(height: 1),
                                ListTile(
                                  leading: const Icon(Icons.logout_rounded, color: BillyColors.error),
                                  title: Text('로그아웃', style: BillyText.body.copyWith(color: BillyColors.error)),
                                  onTap: () => signOut(context),
                                ),
                              ]),
                            ),
                            const SizedBox(height: BillySpace.md),
                            BillyCard(
                              padding: const EdgeInsets.symmetric(vertical: BillySpace.xs),
                              child: ListTile(
                                leading: const Icon(Icons.person_remove_outlined, color: BillyColors.textSecondary),
                                title: Text('계정 삭제', style: BillyText.body.copyWith(color: BillyColors.textSecondary)),
                                subtitle: Text(keepAll('이 계정으로 더 이상 로그인하지 않습니다. 건물·관리비 기록은 남습니다'),
                                    style: BillyText.caption.copyWith(color: BillyColors.textHint)),
                                onTap: _deleteMe,
                              ),
                            ),
                            if (me.isAdmin) ..._adminSection(me),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  List<Widget> _adminSection(UserAccount me) {
    final users = _users;
    final names = {for (final b in context.read<AppProvider>().buildings) b.buildingId: b.buildingName};
    String access(UserAccount u) {
      if (u.isAdmin) return '모든 건물';
      if (u.buildingIds.isEmpty) return '볼 수 있는 건물 없음';
      if (u.buildingIds.length == 1) return names[u.buildingIds.first] ?? '건물 1곳';
      return '건물 ${u.buildingIds.length}곳';
    }

    return [
      SectionTitle(
        '계정 관리',
        subtitle: '관리자는 모든 건물, 매니저는 고른 건물만 봅니다',
        action: TextButton.icon(onPressed: () => _editUser(null), icon: const Icon(Icons.person_add_alt_1_rounded, size: 18), label: const Text('계정 추가')),
      ),
      if (users == null)
        const LoadingView()
      else
        BillyCard(
          padding: const EdgeInsets.symmetric(vertical: BillySpace.xs),
          child: Column(children: [
            for (var i = 0; i < users.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              ListTile(
                leading: _Initial(users[i].username),
                title: Row(children: [
                  Flexible(child: Text(users[i].username, style: BillyText.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (users[i].userId == me.userId) ...[const SizedBox(width: BillySpace.xs), const StatusChip('나', tone: Tone.info)],
                ]),
                subtitle: Text(
                  '${roleLabel(users[i].role)} · ${access(users[i])}',
                  style: BillyText.caption.copyWith(color: !users[i].isAdmin && users[i].buildingIds.isEmpty ? BillyColors.warning : BillyColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: users[i].userId == me.userId ? null : const Icon(Icons.chevron_right_rounded, color: BillyColors.textHint),
                // 내 계정은 위에서 바꾼다(여기서 내 권한을 낮추거나 지우면 아무도 계정을 못 고친다)
                onTap: users[i].userId == me.userId ? null : () => _editUser(users[i]),
              ),
            ],
          ]),
        ),
    ];
  }
}

String _date(DateTime d) => '${d.year}년 ${d.month}월 ${d.day}일';

class _MeCard extends StatelessWidget {
  final UserAccount me;
  const _MeCard({required this.me});

  @override
  Widget build(BuildContext context) {
    return BillyCard(
      child: Row(children: [
        _Initial(me.username, size: 48),
        const SizedBox(width: BillySpace.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(me.username, style: BillyText.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              me.createdAt == null ? '내 계정' : '${_date(me.createdAt!)}부터 사용',
              style: BillyText.caption.copyWith(color: BillyColors.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        StatusChip(roleLabel(me.role), tone: me.isAdmin ? Tone.info : Tone.neutral),
      ]),
    );
  }
}

class _Initial extends StatelessWidget {
  final String name;
  final double size;
  const _Initial(this.name, {this.size = 36});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: BillyColors.primarySoft,
      child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(), style: BillyText.subtitle.copyWith(color: BillyColors.primary)),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: BillyColors.primarySoft, child: Icon(icon, color: BillyColors.primary, size: 20)),
      title: Text(title, style: BillyText.bodyStrong),
      subtitle: Text(subtitle, style: BillyText.caption.copyWith(color: BillyColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right_rounded, color: BillyColors.textHint),
      onTap: onTap,
    );
  }
}

// ── 입력 규칙(서버와 같다) ─────────────────────────────────────────────────
final _space = RegExp(r'\s');

String? _usernameProblem(String v) {
  if (v.isEmpty) return null;
  if (_space.hasMatch(v)) return '띄어쓰기 없이 넣어 주세요';
  if (v.length < 5) return '5자 이상이어야 합니다';
  if (v.length > 32) return '32자까지 됩니다';
  return null;
}

String? _passwordProblem(String v) {
  if (v.isEmpty) return null;
  if (_space.hasMatch(v)) return '띄어쓰기 없이 넣어 주세요';
  if (v.length < 10) return '10자 이상이어야 합니다 (지금 ${v.length}자)';
  if (v.length > 64) return '64자까지 됩니다';
  return null;
}

/// 비밀번호 칸 — 보이기/가리기 단추.
class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? helper;
  final String? error;
  final bool isNew;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  const _PasswordField({
    required this.controller,
    required this.label,
    this.helper,
    this.error,
    this.isNew = false,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      obscureText: _hidden,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: [widget.isNew ? AutofillHints.newPassword : AutofillHints.password],
      textInputAction: widget.onSubmitted == null ? TextInputAction.next : TextInputAction.done,
      onChanged: widget.onChanged,
      onSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper == null ? null : keepAll(widget.helper!),
        helperMaxLines: 2,
        errorText: widget.error,
        errorMaxLines: 2,
        // 보이기 단추는 Tab 순서에서 뺀다 — Tab 이 다음 칸으로 가게
        suffixIcon: ExcludeFocus(
          child: IconButton(
            tooltip: _hidden ? '보이기' : '가리기',
            icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _hidden = !_hidden),
          ),
        ),
      ),
    );
  }
}

/// 창 아래 오류 줄(서버가 거절한 이유).
Widget _errorLine(String? e) => e == null
    ? const SizedBox.shrink()
    : Padding(
        padding: const EdgeInsets.only(top: BillySpace.md),
        child: Text(keepAll(e), style: BillyText.caption.copyWith(color: BillyColors.error)),
      );

Widget _busyLabel(bool busy, String label) =>
    busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: BillyColors.onDark)) : Text(label);

class _DeleteMeDialog extends StatefulWidget {
  const _DeleteMeDialog();

  @override
  State<_DeleteMeDialog> createState() => _DeleteMeDialogState();
}

class _DeleteMeDialogState extends State<_DeleteMeDialog> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppProvider>().api.deleteAccount(_password.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('계정을 지울까요?'),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
            keepAll('지운 계정으로는 다시 로그인할 수 없고 되돌릴 수 없습니다. 건물·검침·명세서 기록은 지워지지 않고 남습니다. '
                '마지막 관리자 계정은 지울 수 없습니다.'),
            style: BillyText.body,
          ),
          const SizedBox(height: BillySpace.md),
          _PasswordField(controller: _password, label: '지금 비밀번호', autofocus: true, onChanged: (_) => setState(() {}), onSubmitted: _submit),
          _errorLine(_error),
        ]),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('취소')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: BillyColors.error),
          onPressed: _busy || _password.text.isEmpty ? null : _submit,
          child: _busyLabel(_busy, '계정 삭제'),
        ),
      ],
    );
  }
}

class _UsernameDialog extends StatefulWidget {
  final String current;
  const _UsernameDialog({required this.current});

  @override
  State<_UsernameDialog> createState() => _UsernameDialogState();
}

class _UsernameDialogState extends State<_UsernameDialog> {
  final _name = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  String? get _nameProblem {
    final v = _name.text.trim();
    if (v.isNotEmpty && v == widget.current) return '지금 아이디와 같습니다';
    return _usernameProblem(v);
  }

  bool get _ready => !_busy && _name.text.trim().isNotEmpty && _nameProblem == null && _password.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_ready) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await context.read<AppProvider>().api.changeUsername(_name.text.trim(), _password.text);
      await AuthService.saveSession(r['access_token'] as String, Map<String, dynamic>.from(r['user'] as Map));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('아이디 바꾸기'),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('지금 아이디 ${widget.current}', style: BillyText.caption.copyWith(color: BillyColors.textSecondary)),
          const SizedBox(height: BillySpace.md),
          TextField(
            controller: _name,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.newUsername],
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: '새 아이디', helperText: '5자 이상, 띄어쓰기 없이', errorText: _nameProblem),
          ),
          const SizedBox(height: BillySpace.md),
          _PasswordField(controller: _password, label: '지금 비밀번호', helper: '본인 확인용', onChanged: (_) => setState(() {}), onSubmitted: _submit),
          _errorLine(_error),
        ]),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('취소')),
        FilledButton(onPressed: _ready ? _submit : null, child: _busyLabel(_busy, '바꾸기')),
      ],
    );
  }
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  String? get _nextProblem {
    if (_next.text.isNotEmpty && _next.text == _current.text) return '지금과 다른 비밀번호를 넣어 주세요';
    return _passwordProblem(_next.text);
  }

  String? get _againProblem => _again.text.isNotEmpty && _again.text != _next.text ? '새 비밀번호와 다릅니다' : null;

  bool get _ready =>
      !_busy && _current.text.isNotEmpty && _next.text.isNotEmpty && _nextProblem == null && _again.text == _next.text;

  Future<void> _submit() async {
    if (!_ready) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await context.read<AppProvider>().api.changePassword(_current.text, _next.text);
      // 예전 토큰은 서버가 이제 거절한다 — 새 토큰으로 이 기기는 이어 간다
      await AuthService.saveSession(r['access_token'] as String, Map<String, dynamic>.from(r['user'] as Map));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    void changed(String _) => setState(() {});
    return AlertDialog(
      scrollable: true,
      title: const Text('비밀번호 바꾸기'),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _PasswordField(controller: _current, label: '지금 비밀번호', autofocus: true, onChanged: changed),
          const SizedBox(height: BillySpace.md),
          _PasswordField(controller: _next, label: '새 비밀번호', helper: '10자 이상, 띄어쓰기 없이', error: _nextProblem, isNew: true, onChanged: changed),
          const SizedBox(height: BillySpace.md),
          _PasswordField(controller: _again, label: '새 비밀번호 한 번 더', error: _againProblem, isNew: true, onChanged: changed, onSubmitted: _submit),
          const SizedBox(height: BillySpace.md),
          Text(keepAll('바꾸면 다른 기기(휴대폰·PC)에서는 다시 로그인해야 합니다.'), style: BillyText.caption.copyWith(color: BillyColors.textSecondary)),
          _errorLine(_error),
        ]),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context, false), child: const Text('취소')),
        FilledButton(onPressed: _ready ? _submit : null, child: _busyLabel(_busy, '바꾸기')),
      ],
    );
  }
}

/// 계정 추가(user == null)·고치기 — 관리자 전용. 끝나면 알릴 문구를 돌려준다.
class _UserEditor extends StatefulWidget {
  final UserAccount? user;
  final List<Building> buildings;
  final List<String> taken;
  const _UserEditor({required this.user, required this.buildings, required this.taken});

  @override
  State<_UserEditor> createState() => _UserEditorState();
}

class _UserEditorState extends State<_UserEditor> {
  final _name = TextEditingController();
  final _password = TextEditingController();
  late String _role = widget.user?.role ?? 'manager';
  late final Set<int> _picked = {...?widget.user?.buildingIds};
  late final Set<int> _owned = {...?widget.user?.ownedBuildingIds};
  bool _busy = false;
  String? _error;

  bool get _isNew => widget.user == null;

  @override
  void initState() {
    super.initState();
    // 건물이 하나뿐이면 새 매니저는 그 건물을 보게 해 둔다(빈 계정을 만들지 않게)
    if (_isNew && widget.buildings.length == 1) _picked.add(widget.buildings.first.buildingId);
  }

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    super.dispose();
  }

  String? get _nameProblem {
    final v = _name.text.trim();
    if (widget.taken.contains(v)) return '이미 쓰는 아이디입니다';
    return _usernameProblem(v);
  }

  /// 고친 게 있는지(권한·비밀번호·볼 수 있는 건물).
  bool get _changed {
    final u = widget.user!;
    final before = {...u.buildingIds}.difference(_owned);
    final after = _picked.difference(_owned);
    final buildingsChanged = _role != 'admin' && (before.length != after.length || !before.containsAll(after));
    return _role != u.role || _password.text.isNotEmpty || buildingsChanged;
  }

  bool get _ready {
    if (_busy) return false;
    if (_isNew) return _name.text.trim().isNotEmpty && _nameProblem == null && _password.text.isNotEmpty && _passwordProblem(_password.text) == null;
    return _changed && (_password.text.isEmpty || _passwordProblem(_password.text) == null);
  }

  Future<void> _save() async {
    if (!_ready) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final api = context.read<AppProvider>().api;
    final ids = _picked.toList()..sort();
    try {
      final u = widget.user;
      if (u == null) {
        await api.createUser(username: _name.text.trim(), password: _password.text, role: _role, buildingIds: _role == 'admin' ? null : ids);
        if (mounted) Navigator.pop(context, '${_name.text.trim()} 계정을 만들었습니다. 비밀번호를 본인에게 알려 주세요');
        return;
      }
      final before = {...u.buildingIds}.difference(_owned);
      final after = ids.where((i) => !_owned.contains(i)).toSet();
      if (_role != u.role) await api.updateUser(u.userId, role: _role);
      if (_password.text.isNotEmpty) await api.updateUser(u.userId, password: _password.text);
      if (_role != 'admin' && (before.length != after.length || !before.containsAll(after))) await api.setUserBuildings(u.userId, after.toList());
      if (mounted) Navigator.pop(context, '${u.username} 계정을 저장했습니다');
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(e);
        });
      }
    }
  }

  Future<void> _delete() async {
    final u = widget.user!;
    final ok = await confirmTypedDelete(
      context,
      title: '계정 지우기',
      name: u.username,
      detail: '이 계정으로는 더 이상 로그인할 수 없습니다. 건물·관리비 기록은 그대로 남습니다.',
    );
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AppProvider>().api.deleteUser(u.userId);
      if (mounted) Navigator.pop(context, '${u.username} 계정을 지웠습니다');
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return AlertDialog(
      scrollable: true,
      title: Text(u == null ? '계정 추가' : u.username, maxLines: 1, overflow: TextOverflow.ellipsis),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_isNew) ...[
            TextField(
              controller: _name,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: '아이디', helperText: '5자 이상, 띄어쓰기 없이', errorText: _nameProblem),
            ),
            const SizedBox(height: BillySpace.md),
          ],
          _PasswordField(
            controller: _password,
            label: _isNew ? '처음 비밀번호' : '비밀번호 새로 정하기',
            helper: _isNew ? '10자 이상 · 본인에게 알려 주고 바꾸게 하세요' : '비워 두면 그대로 · 정하면 그 계정은 다시 로그인',
            error: _passwordProblem(_password.text),
            isNew: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: BillySpace.lg),
          Text('권한', style: BillyText.captionStrong),
          const SizedBox(height: BillySpace.sm),
          SegmentedButton<String>(
            showSelectedIcon: false,
            segments: [
              const ButtonSegment(value: 'manager', label: Text('매니저')),
              const ButtonSegment(value: 'admin', label: Text('관리자')),
              if (u?.role == 'viewer') const ButtonSegment(value: 'viewer', label: Text('뷰어')),
            ],
            selected: {_role},
            onSelectionChanged: _busy ? null : (s) => setState(() => _role = s.first),
          ),
          const SizedBox(height: BillySpace.xs),
          Text(
            keepAll(_role == 'admin' ? '모든 건물을 보고, 계정도 관리합니다' : '아래에서 고른 건물만 보고 관리합니다'),
            style: BillyText.caption.copyWith(color: BillyColors.textSecondary),
          ),
          if (_role != 'admin') ...[
            const SizedBox(height: BillySpace.md),
            Text('볼 수 있는 건물', style: BillyText.captionStrong),
            if (widget.buildings.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: BillySpace.sm),
                child: Text('건물 목록을 불러오지 못했습니다', style: BillyText.caption.copyWith(color: BillyColors.error)),
              ),
            for (final b in widget.buildings)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                value: _owned.contains(b.buildingId) || _picked.contains(b.buildingId),
                onChanged: _owned.contains(b.buildingId) || _busy
                    ? null
                    : (v) => setState(() => v == true ? _picked.add(b.buildingId) : _picked.remove(b.buildingId)),
                title: Text(b.buildingName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: _owned.contains(b.buildingId) ? const Text('이 계정이 주인인 건물') : null,
              ),
            if (widget.buildings.isNotEmpty && _picked.isEmpty && _owned.isEmpty)
              Text(keepAll('하나도 고르지 않으면 로그인해도 볼 건물이 없습니다'), style: BillyText.caption.copyWith(color: BillyColors.warning)),
          ],
          _errorLine(_error),
        ]),
      ),
      actions: [
        if (u != null)
          TextButton(
            onPressed: _busy ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: BillyColors.error),
            child: const Text('지우기'),
          ),
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(onPressed: _ready ? _save : null, child: _busyLabel(_busy, u == null ? '만들기' : '저장')),
      ],
    );
  }
}
