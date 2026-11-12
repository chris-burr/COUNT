import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_midi_command/flutter_midi_command.dart';

typedef TcCallback = void Function(int frames, int framerate,
    {required bool isRunning});

/// Decodes MTC quarter-frame and full-frame SysEx bytes to absolute TC.
class MtcDecoder {
  MtcDecoder({required this.onTimecode});

  final TcCallback onTimecode;

  final List<int?> _qf = List.filled(8, null);
  int _lastFrames = 0;
  int _lastFramerate = 25;
  Timer? _stopTimer;

  void handleQuarterFrame(int dataByte) {
    final piece = (dataByte >> 4) & 0x07;
    final nibble = dataByte & 0x0F;
    _qf[piece] = nibble;

    // Re-arm stop-detection: if no QF arrives within 250 ms, TC has stopped.
    _stopTimer?.cancel();
    _stopTimer = Timer(const Duration(milliseconds: 250), () {
      onTimecode(_lastFrames, _lastFramerate, isRunning: false);
    });

    // Reassemble on piece 7 (end of 2-frame QF group) once all pieces known.
    if (piece == 7 && _qf.every((p) => p != null)) {
      final ff = (_qf[0]! & 0x0F) | ((_qf[1]! & 0x01) << 4);
      final ss = (_qf[2]! & 0x0F) | ((_qf[3]! & 0x03) << 4);
      final mm = (_qf[4]! & 0x0F) | ((_qf[5]! & 0x03) << 4);
      final hh = (_qf[6]! & 0x0F) | ((_qf[7]! & 0x01) << 4);
      final rateCode = (_qf[7]! >> 1) & 0x03;
      final fr = const [24, 25, 30, 30][rateCode];
      final frames = ((hh * 3600 + mm * 60 + ss) * fr) + ff;
      _lastFrames = frames;
      _lastFramerate = fr;
      onTimecode(frames, fr, isRunning: true);
    }
  }

  // F0 7F 7F 01 01 hr mn sc fr F7 — MTC Full Frame (locate without playing)
  void handleSysEx(Uint8List msg) {
    if (msg.length < 10) return;
    if (msg[1] != 0x7F || msg[3] != 0x01 || msg[4] != 0x01) return;
    final rateCode = (msg[5] >> 5) & 0x03;
    final hh = msg[5] & 0x1F;
    final mm = msg[6] & 0x3F;
    final ss = msg[7] & 0x3F;
    final ff = msg[8] & 0x1F;
    final fr = const [24, 25, 30, 30][rateCode];
    final frames = ((hh * 3600 + mm * 60 + ss) * fr) + ff;
    _lastFrames = frames;
    _lastFramerate = fr;
    onTimecode(frames, fr, isRunning: false);
  }

  void dispose() => _stopTimer?.cancel();
}

// ─── MIDI wrapper ──────────────────────────────────────────────────────────────

class MtcReceiver {
  MtcReceiver({required TcCallback onTimecode}) {
    _decoder = MtcDecoder(onTimecode: onTimecode);
  }

  final _mc = MidiCommand();
  late final MtcDecoder _decoder;
  StreamSubscription<MidiPacket>? _sub;
  MidiDevice? _connectedDevice;

  /// Fetches available MIDI devices from CoreMIDI.
  Future<List<MidiDevice>> fetchDevices() async =>
      (await _mc.devices) ?? const [];

  /// Connects to [device] and starts decoding MTC.
  Future<void> connect(MidiDevice device) async {
    if (_sub != null) await disconnect();
    try {
      await _mc.connectToDevice(device);
    } catch (_) {
      // CoreMIDI connects synchronously on the native side; the Dart-side
      // awaitable only waits for a state-change callback that may not arrive
      // for virtual/network ports. Proceed regardless and let packets confirm.
    }
    _connectedDevice = device;
    _sub = _mc.onMidiPacketReceived?.listen(_onPacket);
  }

  Future<void> disconnect() async {
    _sub?.cancel();
    _sub = null;
    if (_connectedDevice != null) {
      _mc.disconnectDevice(_connectedDevice!);
      _connectedDevice = null;
    }
  }

  void _onPacket(MidiPacket packet) {
    final data = packet.data;
    int i = 0;
    while (i < data.length) {
      final b = data[i];
      if (b == 0xF1) {
        if (i + 1 < data.length) {
          _decoder.handleQuarterFrame(data[i + 1]);
          i += 2;
        } else {
          i++;
        }
      } else if (b == 0xF0) {
        int end = i + 1;
        while (end < data.length && data[end] != 0xF7) {
          end++;
        }
        if (end < data.length) {
          _decoder.handleSysEx(data.sublist(i, end + 1));
          i = end + 1;
        } else {
          i = end;
        }
      } else {
        i++;
      }
    }
  }

  void dispose() {
    _sub?.cancel();
    _decoder.dispose();
  }
}
