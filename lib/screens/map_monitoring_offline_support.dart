part of 'map_monitoring_screen.dart';

extension _MapMonitoringOfflineSupport on _MapMonitoringScreenState {
  void _onMapConnectivityChanged() {
    if (!mounted) return;
    final previous = _lastConnectivityState;
    final current = _connectivity.state;
    _lastConnectivityState = current;
    setState(() {});

    if (current.isOffline) {
      unawaited(
        _routeExplorer.useOfflineForCurrentLocation(requestPermission: false),
      );
      if (_routeState.navigationTarget != null) {
        _markRouteUnavailable(
          recalculation: true,
          announceFailure: false,
        );
      }
      return;
    }

    if (!current.isOnline) return;
    if (previous.isOffline || _routeExplorer.lastSource == 'offline') {
      unawaited(_refreshOnlinePoisAfterRecovery());
    }
    if (_routeFallback != null && _routeState.navigationTarget != null) {
      unawaited(_recoverNavigationAfterConnection());
    }
  }

  Future<void> _refreshOnlinePoisAfterRecovery() async {
    if (_routeExplorer.loading) return;
    await _routeExplorer.searchNow(requestPermission: false);
  }

  void _markRouteUnavailable({
    required bool recalculation,
    required bool announceFailure,
  }) {
    final decision = MapOfflineNavigationPolicy.routeFailure(
      hasKnownRoute: _cyclingRoute != null,
      networkOffline: _connectivity.isOffline,
      recalculation: recalculation,
    );
    if (mounted) {
      setState(() => _routeFallback = decision);
    } else {
      _routeFallback = decision;
    }
    _scheduleRouteRecovery();
    if (announceFailure && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(decision.message)),
      );
    }
  }

  void _scheduleRouteRecovery({
    Duration delay = const Duration(seconds: 30),
  }) {
    _routeRecoveryTimer?.cancel();
    if (_routeFallback == null || _routeState.navigationTarget == null) return;
    _routeRecoveryTimer = Timer(delay, () {
      unawaited(_attemptScheduledRouteRecovery());
    });
  }

  Future<void> _attemptScheduledRouteRecovery() async {
    if (!mounted || _routeFallback == null) return;
    final connectivity = await _connectivity.checkNow(force: true);
    if (!mounted || _routeFallback == null) return;
    if (connectivity.isOnline) {
      await _recoverNavigationAfterConnection();
    } else {
      _scheduleRouteRecovery();
    }
  }

  Future<void> _recoverNavigationAfterConnection() async {
    if (_routeRecoveryBusy || _cyclingRouteLoading || !mounted) return;
    final target = _routeState.navigationTarget;
    final current = _routeState.current;
    if (target == null || current == null) return;
    if (!_connectivity.isOnline) {
      _scheduleRouteRecovery();
      return;
    }

    setState(() => _routeRecoveryBusy = true);
    try {
      await _requestCyclingRoute(
        origin: LatLng(current.latitude, current.longitude),
        target: target,
        fitRoute: false,
        announceFailure: false,
        recalculation: _cyclingRoute != null,
      );
    } finally {
      if (mounted) setState(() => _routeRecoveryBusy = false);
    }
  }

  void _cancelRouteRecovery() {
    _routeRecoveryTimer?.cancel();
    _routeRecoveryTimer = null;
  }
}
