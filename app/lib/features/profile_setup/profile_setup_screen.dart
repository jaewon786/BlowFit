import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/storage/storage_providers.dart';
import '../../core/storage/user_profile_store.dart';
import '../../core/theme/blowfit_colors.dart';

/// 디자인 v2 의 02 화면 (`screens/profile-setup.jsx`).
///
/// Onboarding 마지막 → ProfileSetup → Pairing 흐름. 이름/나이/성별 모두
/// 입력해야 '다음' 버튼 활성. 저장은 `UserProfileStore` (SharedPreferences).
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  UserGender? _gender;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // 이미 저장된 프로필이 있으면 prefill (가이드 다시 보기로 재진입 케이스).
    Future.microtask(() async {
      final store = await ref.read(userProfileStoreProvider.future);
      final profile = store.load();
      if (profile == null || !mounted) return;
      setState(() {
        _nameCtrl.text = profile.name;
        _ageCtrl.text = profile.age.toString();
        _gender = profile.gender;
      });
    });
    // 입력값 변화에 따라 버튼 활성 상태 갱신.
    _nameCtrl.addListener(() => setState(() {}));
    _ageCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  bool get _valid {
    final name = _nameCtrl.text.trim();
    final age = int.tryParse(_ageCtrl.text);
    return name.isNotEmpty &&
        age != null &&
        age > 0 &&
        age < 130 &&
        _gender != null;
  }

  Future<void> _next() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    try {
      final store = await ref.read(userProfileStoreProvider.future);
      // 기존 startedAt 이 있으면 보존, 없으면 store.save 가 now 로 채움.
      final existing = store.load();
      await store.save(
        UserProfile(
          name: _nameCtrl.text.trim(),
          age: int.parse(_ageCtrl.text),
          gender: _gender!,
          startedAt: existing?.startedAt,
        ),
      );
      if (!mounted) return;
      context.go('/connect');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/onboarding');
                }
              },
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                children: [
                  const SizedBox(height: 8),
                  // 헤더
                  const Text(
                    '맞춤 훈련을 위해\n알려주세요',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      letterSpacing: -0.78,
                      color: BlowfitColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '입력하신 정보로 적정 호흡근 강도를 계산해요.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      color: BlowfitColors.ink2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // 이름
                  _Field(
                    label: '이름',
                    child: _BlowfitInput(
                      controller: _nameCtrl,
                      hintText: '홍길동',
                      maxLength: 20,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 나이
                  _Field(
                    label: '나이',
                    suffix: '세',
                    child: _BlowfitInput(
                      controller: _ageCtrl,
                      hintText: '32',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      paddingRight: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 성별
                  _GenderSegment(
                    selected: _gender,
                    onSelect: (g) => setState(() => _gender = g),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '입력하신 정보는 기기에 안전하게 저장되며,\n외부로 공유되지 않습니다.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      color: BlowfitColors.ink3,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _valid && !_saving ? _next : null,
                  child: const Text('다음'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar — back · title · spacer
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.chevron_left,
              size: 26,
              color: BlowfitColors.ink,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const Spacer(),
          const Text(
            '프로필 설정',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: BlowfitColors.ink,
              letterSpacing: -0.34,
            ),
          ),
          const Spacer(),
          // 우측 균형 — 디자인의 26px width 더미.
          const SizedBox(width: 36),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Field row — label + input
// ---------------------------------------------------------------------------

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.child,
    this.suffix,
  });
  final String label;
  final Widget child;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.13,
            color: BlowfitColors.ink2,
          ),
        ),
        const SizedBox(height: 10),
        if (suffix == null)
          child
        else
          Stack(
            alignment: Alignment.centerRight,
            children: [
              child,
              Positioned(
                right: 16,
                child: IgnorePointer(
                  child: Text(
                    suffix!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: BlowfitColors.ink3,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 텍스트 입력 — 디자인 .bf-input 매칭 (56px, 14px radius, focus 시 blue50 bg)
// ---------------------------------------------------------------------------

class _BlowfitInput extends StatefulWidget {
  const _BlowfitInput({
    required this.controller,
    required this.hintText,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.paddingRight,
  });

  final TextEditingController controller;
  final String hintText;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final double? paddingRight;

  @override
  State<_BlowfitInput> createState() => _BlowfitInputState();
}

class _BlowfitInputState extends State<_BlowfitInput> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      maxLength: widget.maxLength,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      cursorColor: BlowfitColors.blue500,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.16,
        color: BlowfitColors.ink,
      ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: BlowfitColors.gray400,
        ),
        counterText: '',
        filled: true,
        fillColor: focused ? BlowfitColors.blue50 : Colors.white,
        contentPadding: EdgeInsets.fromLTRB(
          16,
          0,
          widget.paddingRight ?? 16,
          0,
        ),
        // 56px height — Flutter 의 내장 InputDecoration 은 기본 vertical padding
        // 이 있어서 isDense 로 압축 후 SizedBox 로 감싸야 정확. 여기선 minimum
        // tap target 도 고려해 대략적 높이 일치만 잡음.
        isDense: false,
        border: _border(BlowfitColors.gray200),
        enabledBorder: _border(BlowfitColors.gray200),
        focusedBorder: _border(BlowfitColors.blue500, width: 1.5),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1.5}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

// ---------------------------------------------------------------------------
// 성별 세그먼트 — 남성 / 여성 / 선택 안함 (3 column)
// ---------------------------------------------------------------------------

class _GenderSegment extends StatelessWidget {
  const _GenderSegment({required this.selected, required this.onSelect});
  final UserGender? selected;
  final ValueChanged<UserGender> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '성별',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.13,
            color: BlowfitColors.ink2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < UserGender.values.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _GenderTile(
                  gender: UserGender.values[i],
                  selected: selected == UserGender.values[i],
                  onTap: () => onSelect(UserGender.values[i]),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _GenderTile extends StatelessWidget {
  const _GenderTile({
    required this.gender,
    required this.selected,
    required this.onTap,
  });
  final UserGender gender;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? BlowfitColors.blue50 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  selected ? BlowfitColors.blue500 : BlowfitColors.gray200,
              width: 1.5,
            ),
          ),
          child: Text(
            gender.label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.15,
              color: selected ? BlowfitColors.blue600 : BlowfitColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
