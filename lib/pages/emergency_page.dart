import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../theme/beacon_theme.dart';

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({
    required this.user,
    required this.locationService,
    required this.firestoreService,
    super.key,
  });

  final AuthUser user;
  final LocationService locationService;
  final FirestoreService firestoreService;

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  Timer? _holdTimer;
  Timer? _locationTimer;
  Timer? _expiryTimer;
  double _holdProgress = 0;
  int _holdElapsedMilliseconds = 0;
  bool _loadingContact = true;
  bool _savingContact = false;
  bool _sendingAlert = false;
  bool _alertActive = false;

  @override
  void initState() {
    super.initState();
    _loadEmergencyContact();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _locationTimer?.cancel();
    _expiryTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadEmergencyContact() async {
    try {
      final contact =
          await widget.firestoreService.fetchEmergencyContact(widget.user.uid);
      if (!mounted) return;
      _nameController.text = contact['name'] ?? '';
      _phoneController.text = contact['phone'] ?? '';
    } catch (_) {
      if (mounted) _showMessage('Could not load your emergency contact.');
    } finally {
      if (mounted) setState(() => _loadingContact = false);
    }
  }

  void _startHold() {
    if (_sendingAlert || _alertActive) return;
    _holdElapsedMilliseconds = 0;
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _holdElapsedMilliseconds += 100;
      if (_holdElapsedMilliseconds >= 3000) {
        timer.cancel();
        _holdTimer = null;
        unawaited(_sendEmergencyAlert());
      } else if (mounted) {
        setState(() => _holdProgress = _holdElapsedMilliseconds / 3000);
      }
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdElapsedMilliseconds = 0;
    if (mounted && !_alertActive) setState(() => _holdProgress = 0);
  }

  Future<void> _sendEmergencyAlert() async {
    if (_sendingAlert || _alertActive) return;
    _cancelHold();
    setState(() => _sendingAlert = true);
    try {
      final position = await widget.locationService.getCurrentPosition();
      final recipientCount = await widget.firestoreService.updateEmergencyAlert(
        userId: widget.user.uid,
        latitude: position?.latitude,
        longitude: position?.longitude,
      );
      if (!mounted) return;
      if (recipientCount == 0) {
        _showMessage('No connected family members can receive this alert.');
        return;
      }
      setState(() => _alertActive = true);
      _locationTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(_refreshEmergencyLocation()),
      );
      _expiryTimer = Timer(const Duration(minutes: 15), _cancelEmergencyAlert);
      _showMessage(
        'Alert sent to $recipientCount family member${recipientCount == 1 ? '' : 's'}. Keep Beacon open for location updates.',
      );
    } catch (error) {
      if (mounted) _showMessage('Could not send the alert: $error');
    } finally {
      if (mounted) setState(() => _sendingAlert = false);
    }
  }

  Future<void> _refreshEmergencyLocation() async {
    final position = await widget.locationService.getCurrentPosition();
    if (position == null) return;
    try {
      await widget.firestoreService.updateEmergencyAlert(
        userId: widget.user.uid,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (error) {
      if (mounted) _showMessage('Emergency location update failed: $error');
    }
  }

  Future<void> _cancelEmergencyAlert() async {
    _locationTimer?.cancel();
    _expiryTimer?.cancel();
    _locationTimer = null;
    _expiryTimer = null;
    try {
      await widget.firestoreService.clearEmergencyAlert(widget.user.uid);
      if (mounted) setState(() => _alertActive = false);
    } catch (error) {
      if (mounted) _showMessage('Could not clear the alert: $error');
    }
  }

  Future<void> _saveEmergencyContact() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (name.isEmpty || digits.length < 5) {
      _showMessage('Enter a contact name and a valid phone number.');
      return;
    }
    setState(() => _savingContact = true);
    try {
      await widget.firestoreService.saveEmergencyContact(
        userId: widget.user.uid,
        name: name,
        phone: phone,
      );
      if (mounted) _showMessage('Emergency contact saved.');
    } catch (error) {
      if (mounted) _showMessage('Could not save the contact: $error');
    } finally {
      if (mounted) setState(() => _savingContact = false);
    }
  }

  Future<void> _callEmergencyContact() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showMessage('Add an emergency contact phone number first.');
      return;
    }
    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!launched && mounted) _showMessage('Could not open the phone dialer.');
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final contactName = _nameController.text.trim();
    final contactPhone = _phoneController.text.trim();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Emergency'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
        children: [
          Center(
            child: Semantics(
              button: true,
              label: _alertActive
                  ? 'Emergency alert active'
                  : 'Hold for three seconds to send an emergency alert',
              child: Listener(
                onPointerDown: (_) => _startHold(),
                onPointerUp: (_) => _cancelHold(),
                onPointerCancel: (_) => _cancelHold(),
                child: Container(
                  width: 232,
                  height: 232,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFCE2DE),
                    border: Border.all(
                      color: const Color(0xFFF4B9B0),
                      width: 10,
                    ),
                  ),
                  child: Container(
                    width: 184,
                    height: 184,
                    decoration: const BoxDecoration(
                      color: BeaconColors.coral,
                      shape: BoxShape.circle,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_sendingAlert)
                          const SizedBox.square(
                            dimension: 34,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        else
                          Icon(
                            _alertActive
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        const SizedBox(height: 8),
                        Text(
                          _alertActive ? 'ACTIVE' : 'SOS',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (_holdProgress > 0 && !_alertActive)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(35, 10, 35, 0),
                            child: LinearProgressIndicator(
                              value: _holdProgress,
                              color: Colors.white,
                              backgroundColor: Colors.white38,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _alertActive
                ? 'Your family alert is active for up to 15 minutes.'
                : 'Hold for 3 seconds to share your location with your connected family.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: BeaconColors.muted,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          if (_alertActive) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _cancelEmergencyAlert,
              icon: const Icon(Icons.close),
              label: const Text('I am safe · cancel alert'),
            ),
          ],
          const SizedBox(height: 28),
          const Text(
            'EMERGENCY CONTACT',
            style: TextStyle(
              color: BeaconColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: BeaconColors.line),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _loadingContact
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Contact name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: contactPhone.isEmpty || _savingContact
                                  ? null
                                  : _callEmergencyContact,
                              icon: const Icon(Icons.call_outlined),
                              label: Text(contactName.isEmpty
                                  ? 'Call'
                                  : 'Call $contactName'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filled(
                            tooltip: 'Save emergency contact',
                            onPressed:
                                _savingContact ? null : _saveEmergencyContact,
                            icon: _savingContact
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          const Text(
            'SOS shares your precise location with connected family for up to 15 minutes. Alerts appear in Beacon while family members are online. Keep Beacon open for location updates; push alerts and background sharing are not enabled.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BeaconColors.muted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
