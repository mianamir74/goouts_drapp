import 'dart:async';

import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'services/intro_preferences_service.dart';
import 'package:auto_size_text/auto_size_text.dart';

class IntroSlidesScreen extends StatefulWidget {
  final String role;
  final Future<void> Function()? onFinished;

  const IntroSlidesScreen({
    super.key,
    required this.role,
    this.onFinished,
  });

  @override
  State<IntroSlidesScreen> createState() => _IntroSlidesScreenState();
}

class _IntroSlidesScreenState extends State<IntroSlidesScreen> {
  static const Color _goOutsBlue = Color(0xFF0392CA);
  static const Duration _splashAutoAdvanceDelay = Duration(milliseconds: 3500);

  static const List<String> _driverSlides = <String>[
    'assets/intro/Splash Logo_1.png',
    'assets/intro/Become Partner_2.png',
    'assets/intro/Invite Friends_3.png',
    'assets/intro/Commission Structure_3a.png',
    'assets/intro/Grow Network_4.png',
    'assets/intro/Limited Promo_5.png',
    'assets/intro/More opportunities_6.png',
    'assets/intro/Stay tuned_7.png',
  ];

  // ⚠ FIXED 8 September 2026 — these used to point at assets/intro/business/,
  // a folder that has never existed in this project (checked the old
  // driver_app tree too — never there either). Every business partner who
  // tapped "view intro" saw a "Missing intro asset" placeholder on every
  // slide. Repointed at the same real driver images per Mian's decision —
  // not business-specific copy, but real content instead of a broken screen.
  static const List<String> _businessPartnerSlides = <String>[
    'assets/intro/Splash Logo_1.png',
    'assets/intro/Become Partner_2.png',
    'assets/intro/Commission Structure_3a.png',
    'assets/intro/Grow Network_4.png',
    'assets/intro/More opportunities_6.png',
    'assets/intro/Stay tuned_7.png',
  ];

  final PageController _pageController = PageController();
  final IntroPreferencesService _prefsService = IntroPreferencesService();

  int _currentIndex = 0;
  bool _isLoading = true;
  bool _hideSlides = false;
  bool _isCompleting = false;

  Timer? _autoFinishTimer;

  bool get _isBusinessRole {
    final String normalizedRole = widget.role.trim().toLowerCase();
    return normalizedRole == 'business' ||
        normalizedRole == 'business_partner' ||
        normalizedRole == 'business partner';
  }

  String get _rolePreferenceKey => _isBusinessRole
      ? 'business_partner_intro_hidden'
      : 'delivery_driver_intro_hidden';

  List<String> get _roleSlides =>
      _isBusinessRole ? _businessPartnerSlides : _driverSlides;

  List<String> get _slides => _hideSlides ? <String>[_roleSlides.first] : _roleSlides;

  bool get _isSplashScreen => _currentIndex == 0;
  bool get _isLastSlide => _currentIndex == _slides.length - 1;
  bool get _showBackButton => !_hideSlides && _currentIndex >= 1;
  bool get _showNextButton => !_hideSlides && !_isLastSlide;
  bool get _showIndicator => !_hideSlides && _currentIndex >= 1;
  bool get _showFinishTopButton => !_hideSlides && _isLastSlide;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final bool hideSlides = await _loadHidePreference();

    if (!mounted) {
      return;
    }

    setState(() {
      _hideSlides = hideSlides;
      _isLoading = false;
      _currentIndex = 0;
    });

    if (_hideSlides) {
      _startAutoFinishTimer();
    }
  }

  Future<bool> _loadHidePreference() async {
    try {
      final dynamic result = await _prefsService.shouldHidePromoSlides(
        _rolePreferenceKey,
      );
      if (result is bool) {
        return result;
      }
    } catch (_) {}

    return _prefsService.shouldHidePromoSlides();
  }

  Future<void> _saveHidePreference(bool value) async {
    try {
      await _prefsService.setHidePromoSlides(
        _rolePreferenceKey,
        value,
      );
      return;
    } catch (_) {}

    await _prefsService.setHidePromoSlides(value);
  }

  void _startAutoFinishTimer() {
    _autoFinishTimer?.cancel();
    _autoFinishTimer = Timer(_splashAutoAdvanceDelay, () async {
      if (!mounted || !_hideSlides || _isCompleting) {
        return;
      }

      await _completeIntroFlow();
    });
  }

  Future<void> _finishIntro() async {
    if (_isCompleting) {
      return;
    }

    _isCompleting = true;
    await _saveHidePreference(true);

    if (!mounted) {
      return;
    }

    await _openNextStep();
  }

  Future<void> _completeIntroFlow() async {
    if (_isCompleting) {
      return;
    }

    _isCompleting = true;
    await _openNextStep();
  }

  Future<void> _openNextStep() async {
    _autoFinishTimer?.cancel();

    if (widget.onFinished != null) {
      await widget.onFinished!.call();
      return;
    }

    _goToLogin();
  }

  void _goToLogin() {
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _nextSlide() {
    if (_hideSlides || _isLastSlide) {
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousSlide() {
    if (_currentIndex <= 0) {
      return;
    }

    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildTopBar() {
    if (_hideSlides) {
      return SizedBox(height: 24);
    }

    if (_isLastSlide) {
      return SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: <Widget>[
              if (_showBackButton)
                TextButton.icon(
                  onPressed: _previousSlide,
                  icon: Icon(Icons.arrow_back_ios_new, size: 16),
                  label: AutoSizeText(
                    'BACK',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: _goOutsBlue,
                  ),
                )
              else
                SizedBox(width: 12),
              Spacer(),
              if (_showFinishTopButton)
                TextButton.icon(
                  onPressed: _finishIntro,
                  icon: AutoSizeText(
                    'FINISH',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  label: Icon(Icons.arrow_forward_ios, size: 16),
                  style: TextButton.styleFrom(
                    foregroundColor: _goOutsBlue,
                  ),
                )
              else
                SizedBox(width: 12),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            if (_showBackButton)
              TextButton.icon(
                onPressed: _previousSlide,
                icon: Icon(Icons.arrow_back_ios_new, size: 16),
                label: AutoSizeText(
                  'BACK',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _goOutsBlue,
                ),
              )
            else
              SizedBox(width: 12),
            if (_showNextButton)
              TextButton.icon(
                onPressed: _nextSlide,
                icon: AutoSizeText(
                  'NEXT',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                label: const Icon(Icons.arrow_forward_ios, size: 16),
                style: TextButton.styleFrom(
                  foregroundColor: _goOutsBlue,
                ),
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator() {
    if (!_showIndicator) {
      return const SizedBox(height: 24);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SmoothPageIndicator(
        controller: _pageController,
        count: _slides.length,
        effect: ExpandingDotsEffect(
          activeDotColor: _goOutsBlue,
          dotColor: _goOutsBlue.withOpacity(0.18),
          dotHeight: 8,
          dotWidth: 8,
          expansionFactor: 3.2,
          spacing: 8,
          radius: 12,
        ),
        onDotClicked: (int index) {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
      ),
    );
  }

  Widget _buildBottomButtons() {
    return SizedBox(height: 20);
  }

  Widget _buildSlide(String path) {
    final bool isLogoOnlySplash = _hideSlides && _isSplashScreen;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        24,
        isLogoOnlySplash ? 16 : 8,
        24,
        isLogoOnlySplash ? 20 : 8,
      ),
      child: Center(
        child: Image.asset(
          path,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.image_not_supported_outlined,
                  size: 56,
                  color: Colors.black38,
                ),
                SizedBox(height: 12),
                Text(
                  'Missing intro asset',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6),
                AutoSizeText(
                  path,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _autoFinishTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(
            color: _goOutsBlue,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _buildTopBar(),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (int index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (_, int i) => _buildSlide(_slides[i]),
              ),
            ),
            _buildIndicator(),
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }
}
