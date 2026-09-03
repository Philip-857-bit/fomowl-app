import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/chain.dart';
import '../../services/blockchain_service.dart';
import '../../utils/app_error_utils.dart';
import 'admin_api_service.dart';
import 'widgets/admin_dashboard_common.dart';
import 'widgets/admin_dashboard_sections.dart';

enum _AdminSection {
  overview('Overview', Icons.dashboard_rounded),
  stats('Stats', Icons.stacked_line_chart_rounded),
  ops('Ops', Icons.monitor_heart_outlined),
  feedback('Feedback', Icons.forum_outlined),
  dapps('DApps', Icons.explore_outlined),
  promos('Promos', Icons.view_carousel_outlined),
  release('Release', Icons.new_releases_outlined),
  actions('Actions', Icons.bolt_outlined),
  push('Push', Icons.notifications_active_outlined),
  maintainers('Maintainers', Icons.groups_2_outlined),
  registry('Registry', Icons.verified_outlined);

  const _AdminSection(this.label, this.icon);

  final String label;
  final IconData icon;
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.adminSecret,
    this.apiService,
  });

  final String adminSecret;
  final AdminApiService? apiService;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final AdminApiService _apiService;
  int? _observedChainId;
  _AdminSection _selectedSection = _AdminSection.overview;
  final Set<_AdminSection> _loadingSections = <_AdminSection>{};
  final Map<_AdminSection, String> _sectionErrors = <_AdminSection, String>{};
  final Set<String> _registryUpdatingContracts = <String>{};

  Map<String, dynamic>? _health;
  Map<String, dynamic>? _stats;
  Map<String, dynamic>? _ops;
  List<Map<String, dynamic>> _errorLogs = const <Map<String, dynamic>>[];
  int _errorLogsPage = 1;
  int _errorLogsTotal = 0;
  bool _errorLogsHasNext = false;

  List<Map<String, dynamic>> _feedbackItems = const <Map<String, dynamic>>[];
  int _feedbackPage = 1;
  int _feedbackTotal = 0;
  bool _feedbackHasNext = false;

  List<Map<String, dynamic>> _maintainers = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _registryTokens = const <Map<String, dynamic>>[];
  int _registryPage = 1;
  int _registryTotal = 0;
  bool _registryHasNext = false;
  List<Map<String, dynamic>> _discoverDapps = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _homeBanners = const <Map<String, dynamic>>[];
  String _appReleaseVersion = '';
  String _appReleaseMinVersion = '';
  String? _discoverEditingId;
  String? _homeBannerEditingId;
  bool _discoverIsActive = true;
  bool _homeBannerIsActive = true;
  bool _showFallbackSocialBanner = true;
  bool _homeBannerImageUploadInFlight = false;

  Map<String, dynamic>? _lastTestPushResult;
  Map<String, dynamic>? _lastBroadcastResult;
  DateTime? _lastSyncedAt;

  final TextEditingController _feedbackWalletController =
      TextEditingController();
  final TextEditingController _maintainerAddressController =
      TextEditingController();
  final TextEditingController _maintainerNameController =
      TextEditingController();
  final TextEditingController _registrySearchController =
      TextEditingController();
  final TextEditingController _discoverSlugController = TextEditingController();
  final TextEditingController _discoverLaunchUrlController =
      TextEditingController();
  final TextEditingController _discoverTitleController =
      TextEditingController();
  final TextEditingController _discoverSubtitleController =
      TextEditingController();
  final TextEditingController _discoverLogoUrlController =
      TextEditingController();
  final TextEditingController _discoverHeroImageUrlController =
      TextEditingController();
  final TextEditingController _discoverBadgeController =
      TextEditingController();
  final TextEditingController _discoverCategoriesController =
      TextEditingController();
  final TextEditingController _discoverChainIdsController =
      TextEditingController();
  final TextEditingController _discoverFeaturedRankController =
      TextEditingController();
  final TextEditingController _discoverTrendingRankController =
      TextEditingController();
  final TextEditingController _appReleaseVersionController =
      TextEditingController();
  final TextEditingController _appReleaseMinVersionController =
      TextEditingController();
  final TextEditingController _appReleaseNotesController =
      TextEditingController();
  final TextEditingController _homeBannerTitleController =
      TextEditingController();
  final TextEditingController _homeBannerDescriptionController =
      TextEditingController();
  final TextEditingController _homeBannerLinkUrlController =
      TextEditingController();
  final TextEditingController _homeBannerImageUrlController =
      TextEditingController();
  final TextEditingController _homeBannerCtaLabelController =
      TextEditingController();
  final TextEditingController _homeBannerSortOrderController =
      TextEditingController(text: '0');
  final TextEditingController _testPushWalletController =
      TextEditingController();
  final TextEditingController _testPushTitleController = TextEditingController(
    text: 'Owllet Admin Test Notification',
  );
  final TextEditingController _testPushMessageController =
      TextEditingController(
        text: 'This is a test push from the Owllet control center.',
      );
  final TextEditingController _broadcastTitleController =
      TextEditingController();
  final TextEditingController _broadcastMessageController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _apiService =
        widget.apiService ?? AdminApiService(adminSecret: widget.adminSecret);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final chainId = Provider.of<BlockchainService>(context).activeChain.chainId;
    if (_observedChainId == chainId) return;
    _observedChainId = chainId;
    _resetForChain();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadSection(_AdminSection.overview, force: true);
      if (_selectedSection != _AdminSection.overview) {
        _loadSection(_selectedSection, force: true);
      }
    });
  }

  @override
  void dispose() {
    if (widget.apiService == null) {
      _apiService.dispose();
    }
    _feedbackWalletController.dispose();
    _maintainerAddressController.dispose();
    _maintainerNameController.dispose();
    _registrySearchController.dispose();
    _discoverSlugController.dispose();
    _discoverLaunchUrlController.dispose();
    _discoverTitleController.dispose();
    _discoverSubtitleController.dispose();
    _discoverLogoUrlController.dispose();
    _discoverHeroImageUrlController.dispose();
    _discoverBadgeController.dispose();
    _discoverCategoriesController.dispose();
    _discoverChainIdsController.dispose();
    _discoverFeaturedRankController.dispose();
    _discoverTrendingRankController.dispose();
    _appReleaseVersionController.dispose();
    _appReleaseMinVersionController.dispose();
    _appReleaseNotesController.dispose();
    _homeBannerTitleController.dispose();
    _homeBannerDescriptionController.dispose();
    _homeBannerLinkUrlController.dispose();
    _homeBannerImageUrlController.dispose();
    _homeBannerCtaLabelController.dispose();
    _homeBannerSortOrderController.dispose();
    _testPushWalletController.dispose();
    _testPushTitleController.dispose();
    _testPushMessageController.dispose();
    _broadcastTitleController.dispose();
    _broadcastMessageController.dispose();
    super.dispose();
  }

  void _resetForChain() {
    setState(() {
      _loadingSections.clear();
      _sectionErrors.clear();
      _registryUpdatingContracts.clear();
      _health = null;
      _stats = null;
      _ops = null;
      _errorLogs = const <Map<String, dynamic>>[];
      _errorLogsPage = 1;
      _errorLogsTotal = 0;
      _errorLogsHasNext = false;
      _feedbackItems = const <Map<String, dynamic>>[];
      _feedbackPage = 1;
      _feedbackTotal = 0;
      _feedbackHasNext = false;
      _maintainers = const <Map<String, dynamic>>[];
      _registryTokens = const <Map<String, dynamic>>[];
      _registryPage = 1;
      _registryTotal = 0;
      _registryHasNext = false;
      _discoverDapps = const <Map<String, dynamic>>[];
      _homeBanners = const <Map<String, dynamic>>[];
      _appReleaseVersion = '';
      _appReleaseMinVersion = '';
      _discoverEditingId = null;
      _homeBannerEditingId = null;
      _discoverIsActive = true;
      _homeBannerIsActive = true;
      _showFallbackSocialBanner = true;
      _homeBannerImageUploadInFlight = false;
      _lastTestPushResult = null;
      _lastBroadcastResult = null;
      _lastSyncedAt = null;
    });
    _resetDiscoverForm();
    _resetHomeBannerForm();
  }

  int get _activeChainId => _observedChainId ?? 1;

  bool _isLoading(_AdminSection section) => _loadingSections.contains(section);

  Future<void> _loadSection(_AdminSection section, {bool force = false}) async {
    if (_isLoading(section) && !force) return;

    setState(() {
      _loadingSections.add(section);
      _sectionErrors.remove(section);
    });

    try {
      switch (section) {
        case _AdminSection.overview:
          await _loadOverview();
          break;
        case _AdminSection.stats:
          await _loadStats();
          break;
        case _AdminSection.ops:
          await _loadOps();
          break;
        case _AdminSection.feedback:
          await _loadFeedback(page: force ? 1 : _feedbackPage);
          break;
        case _AdminSection.dapps:
          await _loadDiscoverDapps();
          break;
        case _AdminSection.promos:
          await _loadHomeBanners();
          break;
        case _AdminSection.release:
          await _loadAppRelease();
          break;
        case _AdminSection.actions:
        case _AdminSection.push:
          break;
        case _AdminSection.maintainers:
          await _loadMaintainers();
          break;
        case _AdminSection.registry:
          await _loadRegistry(page: force ? 1 : _registryPage);
          break;
      }
      _lastSyncedAt = DateTime.now();
    } catch (error) {
      _sectionErrors[section] = AppErrorUtils.userMessage(
        error,
        fallback: 'Unable to load ${section.label.toLowerCase()}.',
      );
    } finally {
      if (mounted) {
        setState(() => _loadingSections.remove(section));
      }
    }
  }

  Future<void> _loadOverview() async {
    final results = await Future.wait([
      _guardAdminLoad(() => _apiService.fetchHealth()),
      _guardAdminLoad(() => _apiService.fetchStats(_activeChainId)),
      _guardAdminLoad(() => _apiService.fetchOps(_activeChainId)),
    ]);
    if (!mounted) return;
    setState(() {
      _health = results[0] ?? _health;
      _stats = results[1] ?? _stats;
      _ops = results[2] ?? _ops;
    });
  }

  Future<void> _loadStats() async {
    final results = await Future.wait([
      _guardAdminLoad(() => _apiService.fetchStats(_activeChainId)),
      _guardAdminLoad(() => _apiService.fetchOps(_activeChainId)),
      if (_health == null)
        _guardAdminLoad(() => _apiService.fetchHealth())
      else
        Future.value(_health!),
    ]);
    if (!mounted) return;
    setState(() {
      _stats = results[0] ?? _stats;
      _ops = results[1] ?? _ops;
      _health = results[2];
    });
  }

  Future<void> _loadOps({int? page}) async {
    final nextPage = page ?? _errorLogsPage;
    final results = await Future.wait([
      _guardAdminLoad(() => _apiService.fetchOps(_activeChainId)),
      _guardAdminLoad(
        () => _apiService.fetchErrorLogs(
          _activeChainId,
          page: nextPage,
          pageSize: 12,
        ),
      ),
    ]);
    final logsResponse = results[1] ?? const <String, dynamic>{};
    final logs = (logsResponse['logs'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    if (!mounted) return;
    setState(() {
      _ops = results[0] ?? _ops;
      _errorLogs = logs;
      _errorLogsPage = logsResponse['page'] as int? ?? nextPage;
      _errorLogsTotal = logsResponse['total'] as int? ?? logs.length;
      _errorLogsHasNext = logsResponse['hasNext'] == true;
    });
  }

  Future<Map<String, dynamic>?> _guardAdminLoad(
    Future<Map<String, dynamic>> Function() load,
  ) async {
    try {
      return await load();
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadFeedback({int page = 1}) async {
    final response = await _apiService.fetchFeedback(
      _activeChainId,
      page: page,
      pageSize: 20,
      walletAddress: _feedbackWalletController.text,
    );
    final items = (response['feedback'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    if (!mounted) return;
    setState(() {
      _feedbackItems = items;
      _feedbackPage = response['page'] as int? ?? page;
      _feedbackTotal = response['total'] as int? ?? items.length;
      _feedbackHasNext = response['hasNext'] == true;
    });
  }

  Future<void> _loadMaintainers() async {
    final maintainers = await _apiService.fetchMaintainers(_activeChainId);
    if (!mounted) return;
    setState(() => _maintainers = maintainers);
  }

  Future<void> _loadRegistry({int page = 1}) async {
    final response = await _apiService.fetchRegistry(
      _activeChainId,
      page: page,
      pageSize: 30,
      query: _registrySearchController.text,
    );
    final tokens = (response['tokens'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    if (!mounted) return;
    setState(() {
      _registryTokens = tokens;
      _registryPage = response['page'] as int? ?? page;
      _registryTotal = response['total'] as int? ?? tokens.length;
      _registryHasNext = response['hasNext'] == true;
    });
  }

  Future<void> _loadDiscoverDapps() async {
    final dapps = await _apiService.fetchDiscoverDapps();
    if (!mounted) return;
    setState(() => _discoverDapps = dapps);
  }

  Future<void> _loadHomeBanners() async {
    final feed = await _apiService.fetchHomeBanners();
    if (!mounted) return;
    setState(() {
      _homeBanners = feed.banners;
      _showFallbackSocialBanner = feed.showFallbackSocialBanner;
    });
  }

  Future<void> _loadAppRelease() async {
    final response = await _apiService.fetchAppRelease();
    if (!mounted) return;
    setState(() {
      _appReleaseVersion = response['version']?.toString() ?? '';
      _appReleaseMinVersion = response['minVersion']?.toString() ?? '';
      _appReleaseVersionController.text = _appReleaseVersion;
      _appReleaseMinVersionController.text = _appReleaseMinVersion;
      _appReleaseNotesController.text =
          (response['releaseNotes'] as List<dynamic>? ?? const <dynamic>[])
              .join('\n');
    });
  }

  Future<void> _submitAppRelease() async {
    final version = _appReleaseVersionController.text.trim();
    final minVersion = _appReleaseMinVersionController.text.trim();
    if (version.isEmpty || minVersion.isEmpty) {
      _showSnackBar('Version and minimum version are required.');
      return;
    }
    setState(() => _loadingSections.add(_AdminSection.release));
    try {
      await _apiService.updateAppRelease(
        version: version,
        minVersion: minVersion,
        releaseNotes: _appReleaseNotesController.text.trim(),
      );
      await _loadAppRelease();
      _showSnackBar('App release published.');
    } catch (error) {
      _showSnackBar(
        AppErrorUtils.userMessage(
          error,
          fallback: 'Unable to publish release.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingSections.remove(_AdminSection.release));
      }
    }
  }

  Future<void> _refreshCurrentSection() async {
    await _loadSection(_selectedSection, force: true);
  }

  Future<void> _copyFeedbackExport(String format) async {
    try {
      final payload = await _apiService.exportFeedback(
        _activeChainId,
        format: format,
        walletAddress: _feedbackWalletController.text,
      );
      await Clipboard.setData(ClipboardData(text: payload));
      _showSnackBar('${format.toUpperCase()} export copied to clipboard.');
    } catch (error) {
      _showSnackBar(
        AppErrorUtils.userMessage(
          error,
          fallback: 'Unable to export feedback.',
        ),
      );
    }
  }

  Future<void> _submitTestPush() async {
    final wallet = _testPushWalletController.text.trim().toLowerCase();
    final title = _testPushTitleController.text.trim();
    final message = _testPushMessageController.text.trim();
    if (wallet.isEmpty || title.isEmpty || message.isEmpty) {
      _showSnackBar('Wallet address, title, and message are required.');
      return;
    }

    setState(() => _loadingSections.add(_AdminSection.actions));
    try {
      final response = await _apiService.sendTestPush(
        _activeChainId,
        walletAddress: wallet,
        title: title,
        message: message,
      );
      if (!mounted) return;
      setState(() => _lastTestPushResult = response);
      _showSnackBar(
        'Test push sent. ${response['pushSent'] ?? 0} delivered, ${response['pushFailed'] ?? 0} failed.',
      );
    } catch (error) {
      _showSnackBar(
        AppErrorUtils.userMessage(error, fallback: 'Unable to send test push.'),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingSections.remove(_AdminSection.actions));
      }
    }
  }

  Future<void> _submitBroadcast() async {
    final title = _broadcastTitleController.text.trim();
    final message = _broadcastMessageController.text.trim();
    if (title.isEmpty || message.isEmpty) {
      _showSnackBar('Broadcast title and message are required.');
      return;
    }

    setState(() => _loadingSections.add(_AdminSection.push));
    try {
      final response = await _apiService.sendBroadcast(
        _activeChainId,
        title: title,
        message: message,
      );
      if (!mounted) return;
      setState(() => _lastBroadcastResult = response);
      _broadcastTitleController.clear();
      _broadcastMessageController.clear();
      _showSnackBar(
        'Broadcast stored for ${response['walletRecipients'] ?? 0} wallets and sent to ${response['pushSent'] ?? 0} devices.',
      );
    } catch (error) {
      _showSnackBar(
        AppErrorUtils.userMessage(
          error,
          fallback: 'Unable to send broadcast push.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingSections.remove(_AdminSection.push));
      }
    }
  }

  Future<void> _submitMaintainer() async {
    final wallet = _maintainerAddressController.text.trim().toLowerCase();
    if (wallet.isEmpty) {
      _showSnackBar('Maintainer wallet address is required.');
      return;
    }

    setState(() => _loadingSections.add(_AdminSection.maintainers));
    try {
      await _apiService.addMaintainer(
        _activeChainId,
        walletAddress: wallet,
        name: _maintainerNameController.text,
      );
      _maintainerAddressController.clear();
      _maintainerNameController.clear();
      await _loadMaintainers();
      _showSnackBar('Maintainer added successfully.');
    } catch (error) {
      _showSnackBar(
        AppErrorUtils.userMessage(error, fallback: 'Unable to add maintainer.'),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingSections.remove(_AdminSection.maintainers));
      }
    }
  }

  Future<void> _deactivateMaintainer(String walletAddress) async {
    setState(() => _loadingSections.add(_AdminSection.maintainers));
    try {
      await _apiService.deactivateMaintainer(
        _activeChainId,
        walletAddress: walletAddress,
      );
      await _loadMaintainers();
      _showSnackBar('Maintainer access revoked.');
    } catch (error) {
      _showSnackBar(
        AppErrorUtils.userMessage(
          error,
          fallback: 'Unable to deactivate maintainer.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingSections.remove(_AdminSection.maintainers));
      }
    }
  }

  Future<void> _toggleRegistryCertification(
    Map<String, dynamic> token,
    bool nextValue,
  ) async {
    final contract = (token['contractAddress'] ?? '').toString().toLowerCase();
    if (contract.isEmpty) return;

    setState(() => _registryUpdatingContracts.add(contract));
    try {
      await _apiService.updateRegistryEntry(
        _activeChainId,
        contractAddress: contract,
        isCertified: nextValue,
        imageUrl: token['imageUrl']?.toString(),
      );
      if (!mounted) return;
      setState(() {
        _registryTokens = _registryTokens.map((item) {
          if ((item['contractAddress'] ?? '').toString().toLowerCase() !=
              contract) {
            return item;
          }
          return <String, dynamic>{...item, 'isCertified': nextValue};
        }).toList();
      });
      _showSnackBar(
        nextValue
            ? 'Token marked as certified.'
            : 'Token marked as uncertified.',
      );
    } catch (error) {
      _showSnackBar(
        AppErrorUtils.userMessage(
          error,
          fallback: 'Unable to update token registry entry.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _registryUpdatingContracts.remove(contract));
      }
    }
  }

  void _resetDiscoverForm() {
    _discoverEditingId = null;
    _discoverIsActive = true;
    _discoverSlugController.clear();
    _discoverLaunchUrlController.clear();
    _discoverTitleController.clear();
    _discoverSubtitleController.clear();
    _discoverLogoUrlController.clear();
    _discoverHeroImageUrlController.clear();
    _discoverBadgeController.clear();
    _discoverCategoriesController.clear();
    _discoverChainIdsController.clear();
    _discoverFeaturedRankController.clear();
    _discoverTrendingRankController.clear();
  }

  void _resetHomeBannerForm() {
    _homeBannerEditingId = null;
    _homeBannerIsActive = true;
    _homeBannerTitleController.clear();
    _homeBannerDescriptionController.clear();
    _homeBannerLinkUrlController.clear();
    _homeBannerImageUrlController.clear();
    _homeBannerCtaLabelController.clear();
    _homeBannerSortOrderController.text = '0';
  }

  Future<void> _submitDiscoverDapp() async {
    final slug = _discoverSlugController.text.trim();
    final launchUrl = _discoverLaunchUrlController.text.trim();
    final title = _discoverTitleController.text.trim();
    if (launchUrl.isEmpty) {
      _showSnackBar('Launch URL is required.');
      return;
    }

    final payload = <String, dynamic>{
      if (slug.isNotEmpty) 'slug': slug,
      'launchUrl': launchUrl,
      if (title.isNotEmpty) 'title': title,
      'subtitle': _trimmedOrNull(_discoverSubtitleController.text),
      'logoUrl': _trimmedOrNull(_discoverLogoUrlController.text),
      'heroImageUrl': _trimmedOrNull(_discoverHeroImageUrlController.text),
      'badgeText': _trimmedOrNull(_discoverBadgeController.text),
      'categories': _csvValues(_discoverCategoriesController.text),
      'supportedChainIds': _csvInts(_discoverChainIdsController.text),
      'featuredRank': _parseOptionalInt(_discoverFeaturedRankController.text),
      'trendingRank': _parseOptionalInt(_discoverTrendingRankController.text),
      'isActive': _discoverIsActive,
    };

    setState(() => _loadingSections.add(_AdminSection.dapps));
    try {
      if (_discoverEditingId == null) {
        await _apiService.createDiscoverDapp(payload: payload);
        _showSnackBar('Discover DApp created.');
      } else {
        await _apiService.updateDiscoverDapp(
          id: _discoverEditingId!,
          payload: payload,
        );
        _showSnackBar('Discover DApp updated.');
      }
      _resetDiscoverForm();
      await _loadDiscoverDapps();
    } catch (error) {
      _showSnackBar(
        AppErrorUtils.userMessage(
          error,
          fallback: 'Unable to save Discover DApp.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingSections.remove(_AdminSection.dapps));
      }
    }
  }

  Future<void> _refreshDiscoverMetadata() async {
    final id = _discoverEditingId;
    if (id == null || id.isEmpty) {
      _showSnackBar('Pick an existing DApp before refreshing metadata.');
      return;
    }

    setState(() => _loadingSections.add(_AdminSection.dapps));
    try {
      final response = await _apiService.refreshDiscoverDappMetadata(id: id);
      final dapp = response['dapp'];
      if (dapp is Map<String, dynamic>) {
        _startEditingDiscoverDapp(dapp);
      } else if (dapp is Map) {
        _startEditingDiscoverDapp(dapp.cast<String, dynamic>());
      }
      await _loadDiscoverDapps();
      _showSnackBar('Site metadata refreshed.');
    } catch (error) {
      _showSnackBar(
        AppErrorUtils.userMessage(
          error,
          fallback: 'Unable to refresh Discover metadata.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingSections.remove(_AdminSection.dapps));
      }
    }
  }

  Future<void> _submitHomeBanner() async {
    final description = _homeBannerDescriptionController.text.trim();
    final linkUrl = _homeBannerLinkUrlController.text.trim();
    if (description.isEmpty || linkUrl.isEmpty) {
      _showSnackBar('Description and link URL are required.');
      return;
    }

    final payload = <String, dynamic>{
      'title': _trimmedOrNull(_homeBannerTitleController.text),
      'description': description,
      'linkUrl': linkUrl,
      'imageUrl': _trimmedOrNull(_homeBannerImageUrlController.text),
      'ctaLabel': _trimmedOrNull(_homeBannerCtaLabelController.text),
      'sortOrder': _parseOptionalInt(_homeBannerSortOrderController.text) ?? 0,
      'isActive': _homeBannerIsActive,
    };

    setState(() => _loadingSections.add(_AdminSection.promos));
    try {
      if (_homeBannerEditingId == null) {
        await _apiService.createHomeBanner(payload: payload);
        _showSnackBar('Home promo created.');
      } else {
        await _apiService.updateHomeBanner(
          id: _homeBannerEditingId!,
          payload: payload,
        );
        _showSnackBar('Home promo updated.');
      }
      _resetHomeBannerForm();
      await _loadHomeBanners();
    } catch (error) {
      _showSnackBar(
        AppErrorUtils.userMessage(
          error,
          fallback: 'Unable to save the home promo.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingSections.remove(_AdminSection.promos));
      }
    }
  }

  Future<void> _pickAndUploadHomeBannerImage() async {
    try {
      final selection = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['png', 'jpg', 'jpeg', 'webp'],
      );
      if (selection.isEmpty) {
        return;
      }

      final file = selection.single;
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        _showSnackBar('Unable to read the selected image.');
        return;
      }

      setState(() => _homeBannerImageUploadInFlight = true);
      final response = await _apiService.uploadHomeBannerImage(
        bytes: bytes,
        filename: file.name,
      );
      final asset = response['asset'];
      final publicUrl = asset is Map<String, dynamic>
          ? asset['publicUrl']?.toString()
          : asset is Map
          ? asset['publicUrl']?.toString()
          : null;

      if (publicUrl == null || publicUrl.trim().isEmpty) {
        throw Exception('Upload completed without a public image URL.');
      }

      if (!mounted) return;
      setState(() => _homeBannerImageUrlController.text = publicUrl.trim());
      _showSnackBar('Banner image uploaded.');
    } catch (error) {
      _showSnackBar(
        AppErrorUtils.userMessage(
          error,
          fallback: 'Unable to upload the home promo image.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _homeBannerImageUploadInFlight = false);
      }
    }
  }

  void _startEditingHomeBanner(Map<String, dynamic> banner) {
    setState(() {
      _homeBannerEditingId = banner['id']?.toString();
      _homeBannerIsActive = banner['isActive'] != false;
      _homeBannerTitleController.text = banner['title']?.toString() ?? '';
      _homeBannerDescriptionController.text =
          banner['description']?.toString() ?? '';
      _homeBannerLinkUrlController.text = banner['linkUrl']?.toString() ?? '';
      _homeBannerImageUrlController.text = banner['imageUrl']?.toString() ?? '';
      _homeBannerCtaLabelController.text = banner['ctaLabel']?.toString() ?? '';
      _homeBannerSortOrderController.text =
          banner['sortOrder']?.toString() ?? '0';
    });
  }

  Future<void> _toggleHomeBannerActive(
    Map<String, dynamic> banner,
    bool nextValue,
  ) async {
    final id = banner['id']?.toString();
    if (id == null || id.isEmpty) {
      return;
    }

    setState(() => _loadingSections.add(_AdminSection.promos));
    try {
      await _apiService.updateHomeBanner(
        id: id,
        payload: {'isActive': nextValue},
      );
      await _loadHomeBanners();
      _showSnackBar(nextValue ? 'Promo activated.' : 'Promo deactivated.');
    } catch (error) {
      _showSnackBar(
        AppErrorUtils.userMessage(
          error,
          fallback: 'Unable to update the home promo.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingSections.remove(_AdminSection.promos));
      }
    }
  }

  Future<void> _updateFallbackSocialBanner(bool nextValue) async {
    setState(() {
      _showFallbackSocialBanner = nextValue;
      _loadingSections.add(_AdminSection.promos);
    });
    try {
      await _apiService.updateHomeBannerSettings(
        showFallbackSocialBanner: nextValue,
      );
      await _loadHomeBanners();
      _showSnackBar(
        nextValue
            ? 'Default social spotlight enabled.'
            : 'Default social spotlight hidden.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _showFallbackSocialBanner = !nextValue);
      _showSnackBar(
        AppErrorUtils.userMessage(
          error,
          fallback: 'Unable to update spotlight settings.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingSections.remove(_AdminSection.promos));
      }
    }
  }

  void _startEditingDiscoverDapp(Map<String, dynamic> dapp) {
    setState(() {
      _discoverEditingId = dapp['id']?.toString();
      _discoverIsActive = dapp['isActive'] != false;
      _discoverSlugController.text = dapp['slug']?.toString() ?? '';
      _discoverLaunchUrlController.text = dapp['launchUrl']?.toString() ?? '';
      _discoverTitleController.text = dapp['title']?.toString() ?? '';
      _discoverSubtitleController.text = dapp['subtitle']?.toString() ?? '';
      _discoverLogoUrlController.text = dapp['logoUrl']?.toString() ?? '';
      _discoverHeroImageUrlController.text =
          dapp['heroImageUrl']?.toString() ?? '';
      _discoverBadgeController.text = dapp['badgeText']?.toString() ?? '';
      _discoverCategoriesController.text =
          (dapp['categories'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => value.toString())
              .join(', ');
      _discoverChainIdsController.text =
          (dapp['supportedChainIds'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => value.toString())
              .join(', ');
      _discoverFeaturedRankController.text =
          dapp['featuredRank']?.toString() ?? '';
      _discoverTrendingRankController.text =
          dapp['trendingRank']?.toString() ?? '';
    });
  }

  Future<void> _toggleDiscoverDappActive(
    Map<String, dynamic> dapp,
    bool nextValue,
  ) async {
    final id = dapp['id']?.toString();
    if (id == null || id.isEmpty) {
      return;
    }
    setState(() => _loadingSections.add(_AdminSection.dapps));
    try {
      await _apiService.updateDiscoverDapp(
        id: id,
        payload: {'isActive': nextValue},
      );
      await _loadDiscoverDapps();
      _showSnackBar(nextValue ? 'DApp activated.' : 'DApp deactivated.');
    } catch (error) {
      _showSnackBar(
        AppErrorUtils.userMessage(
          error,
          fallback: 'Unable to update Discover DApp.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingSections.remove(_AdminSection.dapps));
      }
    }
  }

  String? _trimmedOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  List<String> _csvValues(String value) {
    return value
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  List<int> _csvInts(String value) {
    return value
        .split(',')
        .map((entry) => int.tryParse(entry.trim()))
        .whereType<int>()
        .toList(growable: false);
  }

  int? _parseOptionalInt(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return int.tryParse(trimmed);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _selectSection(_AdminSection section) {
    setState(() => _selectedSection = section);
    _loadSection(section);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final blockchain = Provider.of<BlockchainService>(context);
    final activeChain = blockchain.activeChain;
    final sectionError = _sectionErrors[_selectedSection];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.adminControlCenter,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${activeChain.name} - ${_selectedSection.label}',
              style: GoogleFonts.outfit(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshCurrentSection,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: AdminHeroCard(
                chainName: activeChain.name,
                lastSyncedAt: _lastSyncedAt,
                status: _health?['status']?.toString(),
                isRefreshing: _isLoading(_selectedSection),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: SizedBox(
                height: 50,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final section = _AdminSection.values[index];
                    return AdminSectionChip(
                      label: section.label,
                      icon: section.icon,
                      selected: section == _selectedSection,
                      onTap: () => _selectSection(section),
                    );
                  },
                  separatorBuilder: (_, index) => const SizedBox(width: 10),
                  itemCount: _AdminSection.values.length,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.accentRed,
                onRefresh: _refreshCurrentSection,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    if (sectionError != null && sectionError.isNotEmpty) ...[
                      AdminBanner(
                        title:
                            'Unable to load ${_selectedSection.label.toLowerCase()}',
                        message: sectionError,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _buildSectionBody(l10n, activeChain),
                    if (_isLoading(_selectedSection) &&
                        !_sectionHasContent(_selectedSection)) ...[
                      const SizedBox(height: 48),
                      const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accentRed,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _sectionHasContent(_AdminSection section) {
    switch (section) {
      case _AdminSection.overview:
        return _health != null || _stats != null || _ops != null;
      case _AdminSection.stats:
        return _stats != null;
      case _AdminSection.ops:
        return _ops != null || _errorLogs.isNotEmpty;
      case _AdminSection.feedback:
        return _feedbackItems.isNotEmpty;
      case _AdminSection.dapps:
        return _discoverDapps.isNotEmpty || _discoverEditingId != null;
      case _AdminSection.promos:
        return _homeBanners.isNotEmpty || _homeBannerEditingId != null;
      case _AdminSection.release:
        return _appReleaseVersion.isNotEmpty;
      case _AdminSection.actions:
      case _AdminSection.push:
        return true;
      case _AdminSection.maintainers:
        return _maintainers.isNotEmpty;
      case _AdminSection.registry:
        return _registryTokens.isNotEmpty;
    }
  }

  Widget _buildSectionBody(AppLocalizations l10n, EvmChain activeChain) {
    switch (_selectedSection) {
      case _AdminSection.overview:
        return AdminOverviewSection(
          l10n: l10n,
          activeChain: activeChain,
          health: _health,
          stats: _stats,
          ops: _ops,
        );
      case _AdminSection.stats:
        return AdminStatsSection(l10n: l10n, stats: _stats, ops: _ops);
      case _AdminSection.ops:
        return AdminOpsSection(
          ops: _ops,
          errorLogs: _errorLogs,
          errorLogsPage: _errorLogsPage,
          errorLogsTotal: _errorLogsTotal,
          onPreviousPage: _errorLogsPage > 1
              ? () => _loadOps(page: _errorLogsPage - 1)
              : null,
          onNextPage: _errorLogsHasNext
              ? () => _loadOps(page: _errorLogsPage + 1)
              : null,
        );
      case _AdminSection.feedback:
        return AdminFeedbackSection(
          walletController: _feedbackWalletController,
          feedbackItems: _feedbackItems,
          feedbackPage: _feedbackPage,
          feedbackTotal: _feedbackTotal,
          onSearch: () => _loadFeedback(page: 1),
          onCopyCsv: () => _copyFeedbackExport('csv'),
          onCopyJson: () => _copyFeedbackExport('json'),
          onPreviousPage: _feedbackPage > 1
              ? () => _loadFeedback(page: _feedbackPage - 1)
              : null,
          onNextPage: _feedbackHasNext
              ? () => _loadFeedback(page: _feedbackPage + 1)
              : null,
        );
      case _AdminSection.dapps:
        return AdminDiscoverDappsSection(
          isLoading: _isLoading(_AdminSection.dapps),
          isSubmitting: _isLoading(_AdminSection.dapps),
          isEditing: _discoverEditingId != null,
          slugController: _discoverSlugController,
          launchUrlController: _discoverLaunchUrlController,
          titleController: _discoverTitleController,
          subtitleController: _discoverSubtitleController,
          logoUrlController: _discoverLogoUrlController,
          heroImageUrlController: _discoverHeroImageUrlController,
          badgeController: _discoverBadgeController,
          categoriesController: _discoverCategoriesController,
          chainIdsController: _discoverChainIdsController,
          featuredRankController: _discoverFeaturedRankController,
          trendingRankController: _discoverTrendingRankController,
          isActive: _discoverIsActive,
          onActiveChanged: (value) => setState(() => _discoverIsActive = value),
          onRefreshMetadata: _refreshDiscoverMetadata,
          onSubmit: _submitDiscoverDapp,
          onReset: () => setState(_resetDiscoverForm),
          dapps: _discoverDapps,
          onEdit: _startEditingDiscoverDapp,
          onToggleActive: _toggleDiscoverDappActive,
        );
      case _AdminSection.promos:
        return AdminHomeBannersSection(
          isLoading: _isLoading(_AdminSection.promos),
          isSubmitting: _isLoading(_AdminSection.promos),
          isUploadingImage: _homeBannerImageUploadInFlight,
          isEditing: _homeBannerEditingId != null,
          showFallbackSocialBanner: _showFallbackSocialBanner,
          titleController: _homeBannerTitleController,
          descriptionController: _homeBannerDescriptionController,
          linkUrlController: _homeBannerLinkUrlController,
          imageUrlController: _homeBannerImageUrlController,
          ctaLabelController: _homeBannerCtaLabelController,
          sortOrderController: _homeBannerSortOrderController,
          isActive: _homeBannerIsActive,
          onActiveChanged: (value) =>
              setState(() => _homeBannerIsActive = value),
          onFallbackSocialBannerChanged: _updateFallbackSocialBanner,
          onUploadImage: _pickAndUploadHomeBannerImage,
          onSubmit: _submitHomeBanner,
          onReset: () => setState(_resetHomeBannerForm),
          banners: _homeBanners,
          onEdit: _startEditingHomeBanner,
          onToggleActive: _toggleHomeBannerActive,
        );
      case _AdminSection.release:
        return AdminAppReleaseSection(
          isLoading: _isLoading(_AdminSection.release),
          isSubmitting: _isLoading(_AdminSection.release),
          versionController: _appReleaseVersionController,
          minVersionController: _appReleaseMinVersionController,
          releaseNotesController: _appReleaseNotesController,
          onSubmit: _submitAppRelease,
          currentVersion: _appReleaseVersion.isEmpty ? '—' : _appReleaseVersion,
          currentMinVersion: _appReleaseMinVersion.isEmpty
              ? '—'
              : _appReleaseMinVersion,
        );
      case _AdminSection.actions:
        return AdminActionsSection(
          isSending: _isLoading(_AdminSection.actions),
          walletController: _testPushWalletController,
          titleController: _testPushTitleController,
          messageController: _testPushMessageController,
          onSend: _submitTestPush,
          lastResult: _lastTestPushResult,
        );
      case _AdminSection.push:
        return AdminPushSection(
          isSending: _isLoading(_AdminSection.push),
          titleController: _broadcastTitleController,
          messageController: _broadcastMessageController,
          onSend: _submitBroadcast,
          lastResult: _lastBroadcastResult,
        );
      case _AdminSection.maintainers:
        return AdminMaintainersSection(
          l10n: l10n,
          isSubmitting: _isLoading(_AdminSection.maintainers),
          addressController: _maintainerAddressController,
          nameController: _maintainerNameController,
          maintainers: _maintainers,
          onSubmit: _submitMaintainer,
          onDeactivate: _deactivateMaintainer,
        );
      case _AdminSection.registry:
        return AdminRegistrySection(
          activeChain: activeChain,
          isLoading: _isLoading(_AdminSection.registry),
          registryUpdatingContracts: _registryUpdatingContracts,
          searchController: _registrySearchController,
          registryTokens: _registryTokens,
          registryPage: _registryPage,
          registryTotal: _registryTotal,
          registryHasNext: _registryHasNext,
          onSearch: () => _loadRegistry(page: 1),
          onRefresh: () => _loadRegistry(page: 1),
          onPreviousPage: _registryPage > 1
              ? () => _loadRegistry(page: _registryPage - 1)
              : null,
          onNextPage: _registryHasNext
              ? () => _loadRegistry(page: _registryPage + 1)
              : null,
          onToggleCertification: (token, value) {
            _toggleRegistryCertification(token, value);
          },
        );
    }
  }
}
