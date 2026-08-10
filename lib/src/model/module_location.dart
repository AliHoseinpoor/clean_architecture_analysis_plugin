import '../config/pulse_architecture.dart';

/// Where a library sits in the architecture, derived from its canonical
/// `package:` URI.
///
/// This is intentionally a *parsed* representation rather than a "does the
/// path contain the segment 'domain' anywhere" heuristic. Scanning for a
/// segment anywhere in the path misfires on paths such as
/// `lib/features/auth/data/models/domain/…`, and it cannot tell a feature
/// named `shared` apart from the global `shared` module.
final class ModuleLocation {
  const ModuleLocation._({
    required this.package,
    required this.segments,
    required this.layerRelativeSegments,
    this.feature,
    this.globalModule,
    this.layer,
  });

  /// The package the library belongs to, e.g. `pulse`.
  final String package;

  /// Path segments below `lib/`, e.g.
  /// `['features', 'auth', 'domain', 'entities', 'user.dart']`.
  final List<String> segments;

  /// Path segments below the layer directory, e.g. `['entities', 'user.dart']`.
  final List<String> layerRelativeSegments;

  /// The feature this library belongs to, or `null` if it is not inside a
  /// feature module.
  final String? feature;

  /// The global module this library belongs to (`core`, `shared`, ...), or
  /// `null`.
  final String? globalModule;

  /// The architectural layer, or `null` if the library sits outside any known
  /// layer (a barrel file, for instance).
  final String? layer;

  String get fileName => segments.isEmpty ? '' : segments.last;

  /// Whether this library is the public barrel of its own feature, i.e.
  /// `lib/features/<feature>/<feature>.dart`.
  bool get isFeatureBarrel {
    final feature = this.feature;
    if (feature == null) return false;

    return segments.length == 3 && fileName == '$feature.dart';
  }

  /// Whether this library sits in a composition root, where wiring concrete
  /// implementations together is legitimate.
  bool isCompositionRoot(PulseArchitecture architecture) {
    return segments.any(architecture.compositionRootSegments.contains);
  }

  /// Parses a canonical `package:` [uri].
  ///
  /// Returns `null` for anything that is not library code of a known package
  /// (`dart:` URIs, `file:` URIs from `test/` or `bin/`, or a URI too short to
  /// carry any structure). Rules treat `null` as "not my business", which is
  /// what keeps this plugin quiet outside `lib/`.
  static ModuleLocation? parse(Uri uri, PulseArchitecture architecture) {
    if (uri.scheme != 'package') return null;

    final all = uri.pathSegments;
    if (all.length < 2) return null;

    final package = all.first;
    final segments = all.sublist(1);

    String? feature;
    String? globalModule;
    String? layer;
    var cursor = 0;

    if (segments[cursor] == architecture.featuresDirectory) {
      if (segments.length < cursor + 2) return null;
      feature = segments[cursor + 1];
      cursor += 2;
    } else if (architecture.globalModules.contains(segments[cursor])) {
      globalModule = segments[cursor];
      cursor += 1;
    }

    if (cursor < segments.length &&
        architecture.layers.contains(segments[cursor])) {
      layer = segments[cursor];
      cursor += 1;
    }

    return ModuleLocation._(
      package: package,
      segments: segments,
      layerRelativeSegments: segments.sublist(cursor),
      feature: feature,
      globalModule: globalModule,
      layer: layer,
    );
  }

  @override
  String toString() =>
      'ModuleLocation(package: $package, feature: $feature, '
      'globalModule: $globalModule, layer: $layer, segments: $segments)';
}
