import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';

class ProfileIntroAnimationScreen extends StatefulWidget {
  final FamilyMember member;
  final Widget nextScreen;
  final Duration duration;

  const ProfileIntroAnimationScreen({
    super.key,
    required this.member,
    required this.nextScreen,
    this.duration = const Duration(seconds: 3),
  });

  @override
  State<ProfileIntroAnimationScreen> createState() => _ProfileIntroAnimationScreenState();
}

class _ProfileIntroAnimationScreenState extends State<ProfileIntroAnimationScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.duration, _openProfile);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _openProfile() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => widget.nextScreen),
    );
  }

  String get _gifPath {
    switch (widget.member.profileType) {
      case ProfileType.pregnant:
        return 'assets/gifs/pregnant.gif';
      case ProfileType.child:
        return 'assets/gifs/child.gif';
      case ProfileType.elderly:
        return 'assets/gifs/elder.gif';
      case ProfileType.chronic:
        return 'assets/gifs/choronic.gif';
      case ProfileType.adult:
        return 'assets/gifs/adult.gif';
    }
  }

  Color get _profileColor => widget.member.profileType.color;
  Color get _profileBgColor => widget.member.profileType.bgColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _profileBgColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 360),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 220,
                        child: Image.asset(
                          _gifPath,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/gifs/adult.gif',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.family_restroom_rounded,
                              size: 96,
                              color: _profileColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        widget.member.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.grey900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _profileBgColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          widget.member.profileType.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _profileColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Preparing profile / جاري فتح الملف',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
