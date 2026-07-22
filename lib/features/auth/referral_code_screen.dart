import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'registration_screen.dart';
import 'package:auto_size_text/auto_size_text.dart';

class ReferralCodeScreen extends StatefulWidget {
  const ReferralCodeScreen({
    super.key,
    this.prefilledReferralCode,
    this.inviteToken,
    this.accountType = 'driver',
  });

  final String? prefilledReferralCode;
  final String? inviteToken;
  final String accountType;

  static const String defaultDriverReferralCode = 'GD100001';
  static const String defaultBusinessReferralCode = 'GB000001';
  static const String defaultCabDriverReferralCode = 'GC100001';

  @override
  State<ReferralCodeScreen> createState() => _ReferralCodeScreenState();
}

class _ReferralCodeScreenState extends State<ReferralCodeScreen> {
  static const Color _goOutsBlue = Color(0xFF0392CA);
  static const Color _screenBackground = Colors.white;
  static const int _codeLength = 8;

  final List<TextEditingController> _controllers = List.generate(
    _codeLength,
    (_) => TextEditingController(),
  );

  final List<FocusNode> _focusNodes = List.generate(
    _codeLength,
    (_) => FocusNode(),
  );

  bool _isLoading = false;
  String? _errorText;
  late String _resolvedAccountType;

  bool get _isBusiness => _resolvedAccountType == 'business';
  bool get _isCabDriver => _resolvedAccountType == 'cab_driver';

  String get _defaultReferralCode {
    if (_isBusiness) return ReferralCodeScreen.defaultBusinessReferralCode;
    if (_isCabDriver) return ReferralCodeScreen.defaultCabDriverReferralCode;
    return ReferralCodeScreen.defaultDriverReferralCode;
  }

  bool get _hasInviteToken {
    return widget.inviteToken != null && widget.inviteToken!.trim().isNotEmpty;
  }

  String _inferInitialAccountType() {
    final String provided = widget.accountType.trim().toLowerCase();
    if (provided == 'business') return 'business';
    if (provided == 'cab_driver') return 'cab_driver';

    final String prefilled = _normalizeCode(widget.prefilledReferralCode ?? '');
    if (prefilled.startsWith('GB')) return 'business';
    if (prefilled.startsWith('GC')) return 'cab_driver';

    return 'driver';
  }

  Future<void> _restorePendingAccountType() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String pending =
        prefs.getString('pending_account_type')?.trim().toLowerCase() ?? 'driver';

    if (!mounted) {
      return;
    }

    if ((pending == 'business' || pending == 'cab_driver') &&
        _resolvedAccountType != pending) {
      setState(() {
        _resolvedAccountType = pending;
        _fillCode(_buildInitialCode());
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _resolvedAccountType = _inferInitialAccountType();

    final String initialCode = _buildInitialCode();
    if (initialCode.isNotEmpty) {
      _fillCode(initialCode);
    }

    _restorePendingAccountType();
  }

  Future<void> _persistResolvedAccountType() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_account_type', _resolvedAccountType);
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers) {
      controller.dispose();
    }
    for (final FocusNode focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  String _normalizeCode(String value) {
    final String cleaned = value
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');

    if (cleaned.length <= _codeLength) {
      return cleaned;
    }

    return cleaned.substring(0, _codeLength);
  }

  String _buildInitialCode() {
    final String prefilled = _normalizeCode(widget.prefilledReferralCode ?? '');
    if (prefilled.isNotEmpty) {
      return prefilled;
    }

    if (_hasInviteToken) {
      return _defaultReferralCode;
    }

    return '';
  }

  void _fillCode(String code) {
    final String normalized = _normalizeCode(code);
    for (int i = 0; i < _controllers.length; i++) {
      _controllers[i].text = i < normalized.length ? normalized[i] : '';
    }
  }

  String get _typedCode {
    return _controllers.map((TextEditingController e) => e.text).join();
  }

  bool get _allBoxesEmpty {
    return _controllers.every(
      (TextEditingController controller) => controller.text.trim().isEmpty,
    );
  }

  bool get _allBoxesFilled {
    return _controllers.every(
      (TextEditingController controller) => controller.text.trim().isNotEmpty,
    );
  }

  String _resolvedReferralCode() {
    if (_hasInviteToken) {
      final String prefilled = _normalizeCode(widget.prefilledReferralCode ?? '');
      if (prefilled.isNotEmpty) {
        return prefilled;
      }
      return _defaultReferralCode;
    }

    final String typed = _normalizeCode(_typedCode);
    if (typed.isEmpty) {
      return _defaultReferralCode;
    }

    return typed;
  }

  bool _validateCodeEntry() {
    if (_hasInviteToken || _allBoxesEmpty) {
      setState(() {
        _errorText = null;
      });
      return true;
    }

    if (!_allBoxesFilled || _normalizeCode(_typedCode).length != _codeLength) {
      setState(() {
        _errorText =
            'Enter the full 8-character referral code or leave all boxes blank.';
      });
      return false;
    }

    setState(() {
      _errorText = null;
    });
    return true;
  }

  void _handleCodeChanged(int index, String value) {
    if (_errorText != null) {
      setState(() {
        _errorText = null;
      });
    }

    if (value.isNotEmpty) {
      if (index < _focusNodes.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }
  }

  // Backspace pressed while a box is already empty (nothing to delete in it) —
  // jump back to the previous box and clear it, so the user can keep pressing
  // backspace without having to manually tap each box.
  void _handleBackspaceOnEmpty(int index) {
    if (index <= 0) {
      return;
    }
    _controllers[index - 1].clear();
    _focusNodes[index - 1].requestFocus();
    if (_errorText != null) {
      setState(() {
        _errorText = null;
      });
    }
  }

  Future<void> _goToRegistration(String referralCode) async {
    if (_isLoading) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
    });

    try {
      await _persistResolvedAccountType();

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          settings: RouteSettings(
            arguments: {
              'inviteToken': widget.inviteToken?.trim(),
              'referralCode': referralCode,
              'isInviteFlow': _hasInviteToken,
              'accountType': _resolvedAccountType,
            },
          ),
          builder: (_) => RegistrationScreen(
            referralCode: referralCode,
          ),
        ),
      );
    } finally {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleContinue() async {
    if (!_validateCodeEntry()) {
      return;
    }

    await _goToRegistration(_resolvedReferralCode());
  }

  Widget _buildInviteInfoCard() {
    return Container(
      clipBehavior: Clip.antiAlias,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _goOutsBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _goOutsBlue.withOpacity(0.16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.link_rounded,
              color: _goOutsBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You opened a GoOuts invite link. The referral code has already been applied and locked for this signup.',
              style: TextStyle(
                color: Colors.grey.shade800,
                height: 1.5,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIllustration() {
    final String assetPath = _isCabDriver
        ? 'assets/logo/cab driver_code.png'
        : 'assets/logo/goouts_code.png';

    return Image.asset(
      assetPath,
      height: 300,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) {
        return Image.asset(
          'assets/logo/goouts_logo_login.png',
          height: 190,
          fit: BoxFit.contain,
        );
      },
    );
  }

  Widget _buildCodeBoxes() {
  return Wrap(
    spacing: 8,
    runSpacing: 8,
    alignment: WrapAlignment.center,
    children: List.generate(
      8,
      (int index) => _CodeInputBox(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        hintText: _defaultReferralCode[index],
        readOnly: _hasInviteToken,
        hasError: _errorText != null,
        textInputAction: index == 7
            ? TextInputAction.done
            : TextInputAction.next,
        onChanged: (String value) => _handleCodeChanged(index, value),
        onBackspaceEmpty: () => _handleBackspaceOnEmpty(index),
        onSubmitted: (_) {
          if (index == 7 && !_isLoading) {
            _handleContinue();
          }
        },
      ),
    ),
  );
}

  Widget _buildBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (_hasInviteToken) ...[
          _buildInviteInfoCard(),
          SizedBox(height: 18),
        ],
        SizedBox(height: 20),
        Text(
          'ENTER',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: _goOutsBlue,
                letterSpacing: 1.2,
              ),
        ),
        SizedBox(height: 2),
        Text(
          _hasInviteToken ? 'REFERRAL APPLIED' : 'REFERRAL CODE',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: _goOutsBlue,
                letterSpacing: 1.2,
              ),
        ),
        SizedBox(height: 22),
        _buildIllustration(),
        SizedBox(height: 28),
        Text(
          _hasInviteToken
              ? 'Your referral code has already been applied for this signup.'
              : 'Please enter your 8-character referral code below:',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF4A5568),
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
        ),
        SizedBox(height: 24),
        _buildCodeBoxes(),
        if (_errorText != null) ...[
          SizedBox(height: 12),
          AutoSizeText(
            _errorText!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        SizedBox(height: 22),
        Text(
          'If you do not have a referral code, just tap Continue. Default code $_defaultReferralCode will be used automatically.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5B6472),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                height: 1.5,
              ),
        ),
        SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 58,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleContinue,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: _goOutsBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: _isLoading
                ? SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : AutoSizeText(
                    'Continue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                  maxWidth: 420,
                ),
                child: Center(
                  child: _buildBody(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CodeInputBox extends StatelessWidget {
  const _CodeInputBox({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.readOnly,
    required this.hasError,
    required this.textInputAction,
    required this.onChanged,
    required this.onSubmitted,
    this.onBackspaceEmpty,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final bool readOnly;
  final bool hasError;
  final TextInputAction textInputAction;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onBackspaceEmpty;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 56,
      child: KeyboardListener(
        focusNode: focusNode,
        onKeyEvent: (KeyEvent event) {
          if (readOnly || onBackspaceEmpty == null) return;
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty) {
            onBackspaceEmpty!();
          }
        },
        child: TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: readOnly,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        keyboardType: TextInputType.text,
        textCapitalization: TextCapitalization.characters,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
        maxLength: 1,
        inputFormatters: readOnly
            ? const []
            : <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                LengthLimitingTextInputFormatter(1),
                UpperCaseTextFormatter(),
              ],
        decoration: InputDecoration(
          counterText: '',
          isDense: true,
          hintText: hintText,
          hintStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9AA4B2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: hasError ? Colors.red : Colors.grey.shade300,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: hasError ? Colors.red : const Color(0xFF0392CA),
              width: 1.4,
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
