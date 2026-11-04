import 'dart:math';

class EqFilter {
  const EqFilter(this.type, this.freq, this.gain, this.q);

  final String type;
  final double freq;
  final double gain;
  final double q;
}

class AutoEqProfile {
  const AutoEqProfile({
    required this.preamp,
    required this.filters,
    required this.graphic,
  });

  final double preamp;
  final List<EqFilter> filters;
  final List<(double, double)> graphic;

  bool get isEmpty => filters.isEmpty && graphic.isEmpty;

  double gainAt(double freq) {
    if (graphic.isNotEmpty) return _graphicGain(freq);
    var total = 0.0;
    for (final f in filters) {
      total += _magnitudeDb(f, freq);
    }
    return total;
  }

  double _graphicGain(double freq) {
    final pts = graphic;
    if (freq <= pts.first.$1) return pts.first.$2;
    if (freq >= pts.last.$1) return pts.last.$2;
    for (var i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      if (freq >= a.$1 && freq <= b.$1) {
        final t = (log(freq) - log(a.$1)) / (log(b.$1) - log(a.$1));
        return a.$2 + (b.$2 - a.$2) * t;
      }
    }
    return 0;
  }

  static double _magnitudeDb(EqFilter f, double freq) {
    const fs = 48000.0;
    final a = pow(10, f.gain / 40).toDouble();
    final w0 = 2 * pi * f.freq / fs;
    final cosw = cos(w0);
    final sinw = sin(w0);
    final q = f.q <= 0 ? 0.707 : f.q;
    final alpha = sinw / (2 * q);

    double b0, b1, b2, a0, a1, a2;
    switch (f.type) {
      case 'LSC' || 'LS':
        final sqL = 2 * sqrt(a) * alpha;
        b0 = a * ((a + 1) - (a - 1) * cosw + sqL);
        b1 = 2 * a * ((a - 1) - (a + 1) * cosw);
        b2 = a * ((a + 1) - (a - 1) * cosw - sqL);
        a0 = (a + 1) + (a - 1) * cosw + sqL;
        a1 = -2 * ((a - 1) + (a + 1) * cosw);
        a2 = (a + 1) + (a - 1) * cosw - sqL;
      case 'HSC' || 'HS':
        final sqH = 2 * sqrt(a) * alpha;
        b0 = a * ((a + 1) + (a - 1) * cosw + sqH);
        b1 = -2 * a * ((a - 1) + (a + 1) * cosw);
        b2 = a * ((a + 1) + (a - 1) * cosw - sqH);
        a0 = (a + 1) - (a - 1) * cosw + sqH;
        a1 = 2 * ((a - 1) - (a + 1) * cosw);
        a2 = (a + 1) - (a - 1) * cosw - sqH;
      default:
        b0 = 1 + alpha * a;
        b1 = -2 * cosw;
        b2 = 1 - alpha * a;
        a0 = 1 + alpha / a;
        a1 = -2 * cosw;
        a2 = 1 - alpha / a;
    }

    final w = 2 * pi * freq / fs;
    final cw = cos(w);
    final c2w = cos(2 * w);
    final sw = sin(w);
    final s2w = sin(2 * w);
    final numRe = b0 + b1 * cw + b2 * c2w;
    final numIm = -(b1 * sw + b2 * s2w);
    final denRe = a0 + a1 * cw + a2 * c2w;
    final denIm = -(a1 * sw + a2 * s2w);
    final num = numRe * numRe + numIm * numIm;
    final den = denRe * denRe + denIm * denIm;
    if (den == 0 || num <= 0) return 0;
    return 10 * log(num / den) / ln10;
  }

  static AutoEqProfile? parse(String text) {
    var preamp = 0.0;
    final filters = <EqFilter>[];
    final graphic = <(double, double)>[];

    final preampRe = RegExp(r'Preamp:\s*([-+]?\d+(?:\.\d+)?)\s*dB', caseSensitive: false);
    final pm = preampRe.firstMatch(text);
    if (pm != null) preamp = double.parse(pm.group(1)!);

    final filterRe = RegExp(
      r'Filter\s*\d*:\s*ON\s+(\w+)\s+Fc\s+([\d.]+)\s*Hz\s+Gain\s+([-+]?\d+(?:\.\d+)?)\s*dB(?:\s+Q\s+([\d.]+))?',
      caseSensitive: false,
    );
    for (final m in filterRe.allMatches(text)) {
      filters.add(EqFilter(
        m.group(1)!.toUpperCase(),
        double.parse(m.group(2)!),
        double.parse(m.group(3)!),
        m.group(4) == null ? 0.707 : double.parse(m.group(4)!),
      ));
    }

    final graphicIdx = text.toLowerCase().indexOf('grapheq');
    if (graphicIdx != -1) {
      final body = text.substring(graphicIdx);
      final colon = body.indexOf(':');
      if (colon != -1) {
        for (final part in body.substring(colon + 1).split(';')) {
          final bits = part.trim().split(RegExp(r'\s+'));
          if (bits.length < 2) continue;
          final f = double.tryParse(bits[0]);
          final g = double.tryParse(bits[1]);
          if (f != null && g != null) graphic.add((f, g));
        }
        graphic.sort((a, b) => a.$1.compareTo(b.$1));
      }
    }

    final profile = AutoEqProfile(preamp: preamp, filters: filters, graphic: graphic);
    return profile.isEmpty ? null : profile;
  }
}
