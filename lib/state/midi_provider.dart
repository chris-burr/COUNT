import 'dart:async';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/timecode/mtc_receiver.dart';
import '../core/timecode/timecode.dart';
import 'providers.dart';

// ─── State ─────────────────────────────────────────────────────────────────────

class MidiState {
  const MidiState({
    this.devices = const [],
    this.selectedDeviceId,
    this.isConnected = false,
    this.isScanning = false,
    this.lastTcString,
  });

  final List<MidiDevice> devices;
  final String? selectedDeviceId;
  final bool isConnected;
  final bool isScanning;

  /// Last decoded TC string received over MIDI — null until first packet arrives.
  final String? lastTcString;

  MidiDevice? get selectedDevice =>
      devices.where((d) => d.id == selectedDeviceId).firstOrNull;

  MidiState copyWith({
    List<MidiDevice>? devices,
    String? selectedDeviceId,
    bool clearDevice = false,
    bool? isConnected,
    bool? isScanning,
    String? lastTcString,
  }) =>
      MidiState(
        devices: devices ?? this.devices,
        selectedDeviceId:
            clearDevice ? null : selectedDeviceId ?? this.selectedDeviceId,
        isConnected: isConnected ?? this.isConnected,
        isScanning: isScanning ?? this.isScanning,
        lastTcString: lastTcString ?? this.lastTcString,
      );
}

// ─── Notifier ──────────────────────────────────────────────────────────────────

class MidiNotifier extends StateNotifier<MidiState> {
  MidiNotifier(this._ref) : super(const MidiState()) {
    _receiver = MtcReceiver(onTimecode: _onTimecode);
  }

  final Ref _ref;
  late final MtcReceiver _receiver;

  Future<void> scan() async {
    state = state.copyWith(isScanning: true);
    final devices = await _receiver.fetchDevices();
    state = state.copyWith(
      devices: devices,
      isScanning: false,
      // Auto-select first device if nothing was selected yet.
      selectedDeviceId:
          state.selectedDeviceId ?? (devices.isNotEmpty ? devices.first.id : null),
    );
  }

  void selectDevice(String deviceId) {
    state = state.copyWith(selectedDeviceId: deviceId);
  }

  Future<void> connect() async {
    final device = state.selectedDevice;
    if (device == null) return;
    await _receiver.connect(device);
    state = state.copyWith(isConnected: true);
  }

  Future<void> disconnect() async {
    await _receiver.disconnect();
    state = state.copyWith(isConnected: false, clearDevice: true);
  }

  void _onTimecode(int frames, int framerate, {required bool isRunning}) {
    state = state.copyWith(lastTcString: Timecode.framesToString(frames, framerate));
    _ref
        .read(timecodeProvider.notifier)
        .update(frames, isRunning: isRunning, framerate: framerate);
  }

  @override
  void dispose() {
    _receiver.dispose();
    super.dispose();
  }
}

final midiProvider =
    StateNotifierProvider<MidiNotifier, MidiState>((ref) => MidiNotifier(ref));
