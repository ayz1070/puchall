import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

class BannerAdSlot extends StatefulWidget {
  const BannerAdSlot({super.key, this.horizontalPadding = 0});

  final double horizontalPadding;

  @override
  State<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends State<BannerAdSlot> {
  BannerAd? _bannerAd;
  AdSize? _adSize;
  bool _isLoaded = false;
  bool _isLoading = false;
  int? _loadedWidth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadedWidth = null;
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdConfig.supportsAds || AdConfig.bannerAdUnitId == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final adWidth = (availableWidth - widget.horizontalPadding * 2)
            .floor()
            .clamp(0, 10000);
        unawaited(_loadAdIfNeeded(adWidth));

        final reservedWidth = _adSize?.width.toDouble() ?? adWidth.toDouble();
        final reservedHeight =
            _adSize?.height.toDouble() ?? AdSize.banner.height.toDouble();

        if (!_isLoaded || _bannerAd == null || _adSize == null) {
          return Center(
            child: SizedBox(width: reservedWidth, height: reservedHeight),
          );
        }

        return Center(
          child: SizedBox(
            width: reservedWidth,
            height: reservedHeight,
            child: AdWidget(ad: _bannerAd!),
          ),
        );
      },
    );
  }

  Future<void> _loadAdIfNeeded(int width) async {
    if (!AdConfig.supportsAds || _isLoading || width <= 0) return;
    if (_bannerAd != null && width == _loadedWidth) return;

    final adUnitId = AdConfig.bannerAdUnitId;
    if (adUnitId == null) return;

    _bannerAd?.dispose();
    _bannerAd = null;
    _adSize = null;
    _isLoaded = false;
    _isLoading = true;
    _loadedWidth = width;

    final adSize = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || adSize == null) {
      _isLoading = false;
      return;
    }
    setState(() {
      _adSize = adSize;
    });

    final bannerAd = BannerAd(
      size: adSize,
      adUnitId: adUnitId,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _adSize = adSize;
            _isLoaded = true;
            _isLoading = false;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _bannerAd = null;
            _adSize = null;
            _isLoaded = false;
            _isLoading = false;
          });
        },
      ),
    );

    _bannerAd = bannerAd;
    unawaited(
      bannerAd.load().catchError((Object _) {
        bannerAd.dispose();
        if (!mounted) return;
        setState(() {
          _bannerAd = null;
          _adSize = null;
          _isLoaded = false;
          _isLoading = false;
        });
      }),
    );
  }
}
