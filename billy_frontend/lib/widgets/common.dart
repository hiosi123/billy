import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'ui.dart' show keepAll;

void showSnack(BuildContext context, String msg, {bool error = false}) {
  final text = keepAll(msg);
  final duration = Duration(seconds: error ? 8 : 4);
  // 아래 창·가운데 창이 떠 있으면 스낵바가 창 뒤에 깔려 안 보인다 — 화면 맨 위에 같은 모양으로 띄운다
  if (modalOnTop(context)) {
    _showTopNotice(context, text, error: error, duration: duration);
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  // 줄 서지 않게 — 저장을 연달아 하면 4초씩 이어지며 아래 단추를 가렸다
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(text),
      backgroundColor: error ? BillyColors.error : BillyColors.textPrimary,
      // 오류는 어느 호실을 고칠지까지 담겨 길다 — 읽을 시간을 주고 직접 닫을 수 있게
      duration: duration,
      showCloseIcon: error,
      // 화면 아래 고정 단추(모두 저장·다음·확정하기)를 가리지 않게 그 위에 띄운다
      margin: const EdgeInsets.fromLTRB(BillySpace.gutter, 0, BillySpace.gutter, 84),
    ),
  );
}

/// 맨 위 라우트를 지켜본다 — 아래 창·가운데 창(PopupRoute)이 떠 있는지 [showSnack] 이 알도록.
/// router.dart 의 GoRouter(observers:) 에 건다(창은 useRootNavigator 라 루트 내비게이터에 뜬다).
class ModalWatch extends NavigatorObserver {
  ModalWatch._();
  static final instance = ModalWatch._();
  final _routes = <Route<dynamic>>[];

  Route<dynamic>? get top {
    _routes.removeWhere((r) => r.navigator == null);
    return _routes.isEmpty ? null : _routes.last;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _routes.add(route);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _routes.remove(route);
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _routes.remove(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final i = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (newRoute == null) return;
    if (i >= 0) {
      _routes[i] = newRoute;
    } else {
      _routes.add(newRoute);
    }
  }
}

/// 아래 창·가운데 창·메뉴가 맨 위에 떠 있나.
bool modalOnTop(BuildContext context) {
  final own = ModalRoute.of(context);
  if (own is PopupRoute && own.isCurrent) return true;
  return ModalWatch.instance.top is PopupRoute;
}

OverlayEntry? _topNotice;

void _showTopNotice(BuildContext context, String text, {required bool error, required Duration duration}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final old = _topNotice;
  if (old != null && old.mounted) old.remove();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TopNotice(
      text: text,
      error: error,
      duration: duration,
      onDone: () {
        if (entry.mounted) entry.remove();
        if (identical(_topNotice, entry)) _topNotice = null;
      },
    ),
  );
  _topNotice = entry;
  overlay.insert(entry);
}

/// 창 위에 뜨는 알림 — 스낵바와 같은 모양, 자리만 화면 맨 위(자판이 올라와도 안 가린다). 누르면 닫힌다.
class _TopNotice extends StatefulWidget {
  final String text;
  final bool error;
  final Duration duration;
  final VoidCallback onDone;
  const _TopNotice({required this.text, required this.error, required this.duration, required this.onDone});

  @override
  State<_TopNotice> createState() => _TopNoticeState();
}

class _TopNoticeState extends State<_TopNotice> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 200))..forward();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _close);
  }

  Future<void> _close() async {
    _timer?.cancel();
    if (!mounted) return;
    await _anim.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: _anim,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(BillySpace.md),
                child: Material(
                  color: widget.error ? BillyColors.error : BillyColors.textPrimary,
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BillyRadius.md)),
                  child: InkWell(
                    onTap: _close,
                    borderRadius: BorderRadius.circular(BillyRadius.md),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(children: [
                        Expanded(child: Text(widget.text, style: BillyText.body.copyWith(color: BillyColors.onDark))),
                        if (widget.error) const Icon(Icons.close_rounded, size: 18, color: BillyColors.onDark),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 제목 + 콘텐츠를 담는 카드 섹션.
class SectionCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    this.title,
    this.icon,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BillyColors.card(),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: BillyColors.primary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: BillyColors.textPrimary),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

/// 통계 타일 (라벨 + 큰 숫자 + 색).
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color softColor;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.softColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: softColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: BillyColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// 라벨 배지(역할/상태).
class BillyBadge extends StatelessWidget {
  final String text;
  final Color color;
  const BillyBadge(this.text, {super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

/// key : value 한 줄.
class KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  const KeyValueRow(this.label, this.value, {super.key, this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: BillyColors.textSecondary,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? BillyColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 불러오기 실패 안내 + 다시 시도. (실패를 '데이터 없음'처럼 보이게 하지 않는다)
class ErrorBanner extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const ErrorBanner({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(color: BillyColors.errorSoft, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: BillyColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(keepAll(message),
                style: const TextStyle(fontSize: 13, color: BillyColors.error, fontWeight: FontWeight.w600)),
          ),
          TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ],
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(strokeWidth: 2.5)));
}

class EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;
  const EmptyView({super.key, required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: BillyColors.primarySoft, shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: BillyColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              keepAll(message),
              textAlign: TextAlign.center,
              style: const TextStyle(color: BillyColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

/// 비동기 동작 버튼(로딩 스피너 내장).
class AsyncButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Future<void> Function() onPressed;
  final Color? color;
  final bool outlined;
  const AsyncButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color,
    this.outlined = false,
  });

  @override
  State<AsyncButton> createState() => _AsyncButtonState();
}

class _AsyncButtonState extends State<AsyncButton> {
  bool _loading = false;

  Future<void> _run() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 로딩 중 단추는 비활성 회색이 되는데 흰 스피너는 거기서 안 보였다 — 테두리 단추는 파란 스피너, 채운 단추는 색을 지킨다
    final child = _loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4, color: widget.outlined ? BillyColors.primary : BillyColors.onDark))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[Icon(widget.icon, size: 18), const SizedBox(width: 8)],
              Text(widget.label),
            ],
          );

    if (widget.outlined) {
      return OutlinedButton(onPressed: _loading ? null : _run, child: child);
    }
    final bg = widget.color ?? BillyColors.primary;
    return ElevatedButton(
      onPressed: _loading ? null : _run,
      style: ElevatedButton.styleFrom(backgroundColor: bg, disabledBackgroundColor: _loading ? bg : null, disabledForegroundColor: _loading ? BillyColors.onDark : null),
      child: child,
    );
  }
}
