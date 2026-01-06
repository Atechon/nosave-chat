import 'dart:async';
import 'dart:io'; // Added for Platform
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/services.dart'; // For MethodChannel
import 'about_screen.dart'; // Import new pages
import 'privacy_policy_screen.dart';
import 'contact_screen.dart';
import 'settings_screen.dart'; // New

class AppColors {
  static const primary = Color(0xFF036580); // Dark background
  static const backgroundLight = Color(0xFFF5F5F5);
  static const accentTeal = Color(0xFF00A8A8);
  static const accent = Color(0xFF075E54); // WhatsApp Business green
  static const textPrimary = Color(0xFF212121);
  static const textSecondary = Color(0xFF757575);
}

class AdConstants {
  // REPLACE THESE WITH YOUR ACTUAL ADMOB UNIT IDs (test IDs shown)
  static const bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
}

class DirectChatScreen extends StatefulWidget {
  const DirectChatScreen({super.key});

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String _selectedCountryCode = '+1';
  bool _isSending = false;

  bool _isAdLoading = false;
  RewardedAd? _rewardedAd;
  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;
  Timer? _bannerRotationTimer;

  bool _showAds =
      true; // New: Default true, but will be set based on first launch

  static const platform = MethodChannel(
    'com.github.atechon.nosavechat/launch',
  ); // Match native

  @override
  void initState() {
    super.initState();
    _loadPersistedData().then((_) {
      if (_showAds) {
        _loadAds();
        _loadBannerAd();
      }
    });
  }

  // === Ads ===
  Future<void> _loadAds() async {
    if (_isAdLoading) return;
    setState(() => _isAdLoading = true);

    RewardedAd.load(
      adUnitId: AdConstants.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          setState(() => _isAdLoading = false);
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          setState(() => _isAdLoading = false);
        },
      ),
    );
  }

  Future<void> _loadBannerAd() async {
    _bannerAd = BannerAd(
      adUnitId: AdConstants.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() => _isBannerAdLoaded = true);
          _startBannerRotation();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          setState(() => _isBannerAdLoaded = false);
          Future.delayed(const Duration(seconds: 10), () => _loadBannerAd());
        },
      ),
    )..load();
  }

  void _startBannerRotation() {
    _bannerRotationTimer?.cancel();
    _bannerRotationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _bannerAd?.dispose();
      _loadBannerAd();
    });
  }

  Future<void> _showSupportRewardedAd() async {
    if (_rewardedAd == null) {
      _showSnackBar('Ad not ready, try again later');
      return;
    }
    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        _showSnackBar('Thank you for supporting the app!');
      },
    );
    _rewardedAd = null;
    _loadAds();
  }

  // === Persistence ===
  Future<void> _loadPersistedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _phoneController.text = prefs.getString('direct_chat_phone') ?? '';
      _messageController.text = prefs.getString('direct_chat_message') ?? '';
      _selectedCountryCode =
          prefs.getString('direct_chat_country_code') ?? '+1';
    });
    _phoneController.addListener(
      () => _debounceSave('direct_chat_phone', _phoneController.text),
    );
    _messageController.addListener(
      () => _debounceSave('direct_chat_message', _messageController.text),
    );

    // New: Check for first launch and ad delay
    final firstLaunchTime = prefs.getInt('first_launch_time');
    final now = DateTime.now().millisecondsSinceEpoch;
    if (firstLaunchTime == null) {
      await prefs.setInt('first_launch_time', now);
      setState(() => _showAds = false);
    } else {
      final elapsedMillis = now - firstLaunchTime;
      setState(
        () => _showAds = elapsedMillis >= (30 * 60 * 1000),
      ); // 30 minutes in millis
    }
  }

  Future<void> _debounceSave(String key, String value) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<bool> _isAppInstalled(String packageName) async {
    if (!Platform.isAndroid) return true; // iOS uses url
    try {
      final bool installed = await platform.invokeMethod('isAppInstalled', {
        'package': packageName,
      });
      return installed;
    } catch (e) {
      return false;
    }
  }

  // === Sending Logic ===
  Future<void> _sendMessage(String platformName) async {
    if (_isSending) return;
    FocusScope.of(context).unfocus();

    if (_phoneController.text.isEmpty || _messageController.text.isEmpty) {
      _showSnackBar('Please fill phone and message');
      return;
    }

    setState(() => _isSending = true);

    final cleanPhone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final fullPhone = '$_selectedCountryCode$cleanPhone'; // e.g., +1234567890
    final message = _messageController.text;

    // For WhatsApp: Remove '+' (official format requires digits only)
    final phoneForWhatsApp = fullPhone.startsWith('+')
        ? fullPhone.substring(1)
        : fullPhone;

    String packageName;
    String successMessage;

    switch (platformName.replaceAll('\n', ' ')) {
      case 'WhatsApp':
        packageName = 'com.whatsapp';
        successMessage = 'Opening WhatsApp...';
        break;
      case 'WhatsApp Business':
        packageName = 'com.whatsapp.w4b';
        successMessage = 'Opening WhatsApp Business...';
        break;
      case 'Telegram':
        packageName = 'org.telegram.messenger';
        successMessage = 'Opening Telegram...';
        break;
      default:
        setState(() => _isSending = false);
        return;
    }

    final installed = await _isAppInstalled(packageName);

    if (installed) {
      try {
        await platform.invokeMethod('launchApp', {
          'package': packageName,
          'phone': packageName.contains("whatsapp")
              ? phoneForWhatsApp
              : fullPhone,
          'text': message,
        });
        _showSnackBar(successMessage);
      } catch (e) {
        _showSnackBar('$platformName not installed or unable to open');
      }
    } else {
      _showSnackBar('$platformName not installed');
    }

    setState(() => _isSending = false);
  }

  void _clearInputs() {
    _phoneController.clear();
    _messageController.clear();
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('direct_chat_phone', '');
      prefs.setString('direct_chat_message', '');
    });
    setState(() {});
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    _rewardedAd?.dispose();
    _bannerAd?.dispose();
    _bannerRotationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/icons/bg.png'),
            fit: BoxFit.cover,
            opacity: 0.9,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Row(
                  children: [
                    Image.asset(
                      'assets/icon/icon.png',
                      height: screenHeight * 0.08,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'NoSave Chat',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: screenWidth * 0.045,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                actions: [
                  if (_showAds) // New: Hide star button during ad delay
                    IconButton(
                      icon: const Icon(Icons.star, color: AppColors.accentTeal),
                      onPressed: _showSupportRewardedAd,
                      tooltip: 'Support the app',
                    ),
                  IconButton(
                    icon: const Icon(Icons.clear_all),
                    onPressed: _clearInputs,
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'about':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AboutScreen(),
                            ),
                          );
                          break;
                        case 'privacy':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyScreen(),
                            ),
                          );
                          break;
                        case 'contact':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ContactScreen(),
                            ),
                          );
                          break;
                        case 'rate':
                          const playStoreUrl =
                              'https://play.google.com/store/apps/details?id=com.github.atechon.nosavechat'; // Replace with your package name
                          if (await canLaunchUrl(Uri.parse(playStoreUrl))) {
                            await launchUrl(
                              Uri.parse(playStoreUrl),
                              mode: LaunchMode.externalApplication,
                            );
                          }
                          break;
                        case 'settings':
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'about', child: Text('About')),
                      const PopupMenuItem(
                        value: 'privacy',
                        child: Text('Privacy Policy'),
                      ),
                      const PopupMenuItem(
                        value: 'contact',
                        child: Text('Contact'),
                      ),
                      const PopupMenuItem(
                        value: 'rate',
                        child: Text('Rate the App'),
                      ),
                      const PopupMenuItem(
                        value: 'settings',
                        child: Text('Settings'),
                      ),
                    ],
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.04,
                    vertical: screenWidth * 0.03,
                  ),
                  child: Column(
                    children: [
                      Card(
                        color: isDark
                            ? const Color.fromRGBO(3, 101, 128, 0.85)
                            : const Color.fromRGBO(255, 255, 255, 0.85),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: EdgeInsets.all(screenWidth * 0.03),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Send a Message',
                                style: GoogleFonts.poppins(
                                  fontSize: screenWidth * 0.05,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: screenWidth * 0.03),
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color.fromRGBO(
                                              3,
                                              101,
                                              128,
                                              0.9,
                                            )
                                          : const Color.fromRGBO(
                                              255,
                                              255,
                                              255,
                                              0.9,
                                            ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppColors.accentTeal,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.accentTeal.withAlpha(
                                            38,
                                          ),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: CountryCodePicker(
                                      onChanged: (code) async {
                                        setState(() {
                                          _selectedCountryCode =
                                              code.dialCode ?? '+1';
                                        });
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        await prefs.setString(
                                          'direct_chat_country_code',
                                          _selectedCountryCode,
                                        );
                                      },
                                      initialSelection: _selectedCountryCode,
                                      favorite: ['+234', '+1', '+44', '+91'],
                                      showFlag: true,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      flagWidth: 28,
                                    ),
                                  ),
                                  SizedBox(width: screenWidth * 0.02),
                                  Expanded(
                                    child: TextField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      decoration: InputDecoration(
                                        hintText: 'Phone Number',
                                        filled: true,
                                        fillColor: isDark
                                            ? const Color.fromRGBO(
                                                3,
                                                101,
                                                128,
                                                0.8,
                                              )
                                            : const Color.fromRGBO(
                                                255,
                                                255,
                                                255,
                                                0.8,
                                              ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.accentTeal,
                                            width: 1.5,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.accentTeal,
                                            width: 1.5,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: const BorderSide(
                                            color: AppColors.accentTeal,
                                            width: 1.5,
                                          ),
                                        ),
                                        suffixIcon:
                                            _phoneController.text.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(
                                                  Icons.clear,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () {
                                                  setState(
                                                    () => _phoneController
                                                        .clear(),
                                                  );
                                                },
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: screenWidth * 0.03),
                              TextField(
                                controller: _messageController,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: 'Type your message here...',
                                  filled: true,
                                  fillColor: isDark
                                      ? const Color.fromRGBO(3, 101, 128, 0.8)
                                      : const Color.fromRGBO(
                                          255,
                                          255,
                                          255,
                                          0.8,
                                        ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: AppColors.accentTeal,
                                      width: 1.5,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: AppColors.accentTeal,
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: AppColors.accentTeal,
                                      width: 1.5,
                                    ),
                                  ),
                                  suffixIcon: _messageController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.clear,
                                            color: Colors.red,
                                          ),
                                          onPressed: () {
                                            setState(
                                              () => _messageController.clear(),
                                            );
                                          },
                                        )
                                      : null,
                                ),
                              ),
                              SizedBox(height: screenWidth * 0.04),
                              Text(
                                'Send via:',
                                style: GoogleFonts.poppins(
                                  fontSize: screenWidth * 0.04,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: screenWidth * 0.02),
                              // Responsive wrap to prevent overflow on small screens
                              Wrap(
                                spacing: screenWidth * 0.04,
                                runSpacing: 16,
                                alignment: WrapAlignment.spaceEvenly,
                                children: [
                                  _buildPlatformButton(
                                    platform: 'WhatsApp',
                                    iconPath: 'assets/icons/whatsapp_icon.png',
                                    color: const Color(0xFF25D366),
                                    screenWidth: screenWidth,
                                  ),
                                  _buildPlatformButton(
                                    platform: 'WhatsApp\nBusiness',
                                    iconPath:
                                        'assets/icons/whatsapp_business_icon.png',
                                    color: AppColors.accent,
                                    screenWidth: screenWidth,
                                    centerText: true,
                                  ),
                                  _buildPlatformButton(
                                    platform: 'Telegram',
                                    iconPath: 'assets/icons/telegram_icon.png',
                                    color: const Color(0xFF0088CC),
                                    screenWidth: screenWidth,
                                  ),
                                ],
                              ),
                              SizedBox(height: screenWidth * 0.04),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Opacity(
                                    opacity: 0.8,
                                    child: Image.asset(
                                      'assets/icon/icon.png',
                                      height: screenHeight * 0.06,
                                      width: screenHeight * 0.06,
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: GoogleFonts.poppins(
                                          fontSize: screenWidth * 0.035,
                                          color: isDark
                                              ? Colors.grey[300]
                                              : Colors.grey[800],
                                          height: 1.3,
                                        ),
                                        children: const [
                                          TextSpan(
                                            text:
                                                "Send WhatsApp, WA Business & Telegram ",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          TextSpan(
                                            text:
                                                "messages instantly without saving contacts, perfect for business owners and personal use.",
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: screenWidth * 0.04),
                      // Banner ad (always visible, non-intrusive)
                      if (_showAds &&
                          _isBannerAdLoaded &&
                          _bannerAd != null) // New: Hide during ad delay
                        Container(
                          alignment: Alignment.center,
                          width: _bannerAd!.size.width.toDouble(),
                          height: _bannerAd!.size.height.toDouble(),
                          child: AdWidget(ad: _bannerAd!),
                        )
                      else if (_showAds) // New: Show loader only if ads are enabled
                        Container(
                          width: AdSize.banner.width.toDouble(),
                          height: AdSize.banner.height.toDouble(),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformButton({
    required String platform,
    required String iconPath,
    required Color color,
    required double screenWidth,
    bool centerText = false,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: screenWidth * 0.28),
      child: GestureDetector(
        onTap: _isSending
            ? null
            : () => _sendMessage(platform.replaceAll('\n', ' ')),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.02,
            vertical: screenWidth * 0.02,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color.fromRGBO(3, 101, 128, 0.8)
                : const Color.fromRGBO(255, 255, 255, 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(38),
                blurRadius: 4,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: centerText
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Image.asset(
                iconPath,
                width: screenWidth * 0.08,
                height: screenWidth * 0.08,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.error,
                  color: Colors.red,
                  size: screenWidth * 0.06,
                ),
              ),
              SizedBox(height: screenWidth * 0.01),
              Text(
                platform,
                textAlign: centerText ? TextAlign.center : TextAlign.start,
                style: GoogleFonts.poppins(
                  fontSize: screenWidth * 0.035,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
