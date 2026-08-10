/// How a feature is allowed to reach another feature.
enum CrossFeatureAccess {
  /// A feature may never import another feature.
  forbidden,

  /// A feature may import another feature only through its public barrel
  /// file (`lib/features/<feature>/<feature>.dart`).
  publicApiOnly,
}

/// The single source of truth for the architectural policy enforced by this
/// plugin.
///
/// Every rule reads its policy from here instead of hard-coding it, so that
/// adapting the plugin to a different project means editing one file rather
/// than editing every rule. Keeping the policy as data (maps and sets) instead
/// of `switch` statements also makes it trivially unit-testable without going
/// through the analyzer at all.
///
/// Expected project layout (both shapes are supported):
///
/// ```
/// lib/features/<feature>/<layer>/...   // feature-first
/// lib/<global_module>/<layer>/...      // shared/core modules
/// lib/<layer>/...                      // layer-first (small projects)
/// ```
final class PulseArchitecture {
  const PulseArchitecture({
    this.featuresDirectory = 'features',
    this.layers = _defaultLayers,
    this.globalModules = _defaultGlobalModules,
    this.allowedLayerDependencies = _defaultAllowedLayerDependencies,
    this.allowedExternalDependencies = _defaultAllowedExternalDependencies,
    this.crossFeatureAccess = CrossFeatureAccess.forbidden,
    this.compositionRootSegments = _defaultCompositionRootSegments,
  });

  /// The instance the shipped rules use. Point this at a customised
  /// [PulseArchitecture] to change the policy for a whole project.
  static const PulseArchitecture instance = PulseArchitecture();

  /// The directory under `lib/` that holds feature modules.
  final String featuresDirectory;

  /// The recognised architectural layer directory names.
  final Set<String> layers;

  /// Top-level modules under `lib/` that are shared by every feature.
  final Set<String> globalModules;

  /// For each layer, the layers it is allowed to depend on.
  ///
  /// A layer may always depend on itself. A layer that is absent from this map
  /// is unconstrained (fail open) — unknown directories should never produce
  /// noise.
  final Map<String, Set<String>> allowedLayerDependencies;

  /// For each layer, the external dependencies it may import.
  ///
  /// Keys are layer names; values are dependency identifiers in the form
  /// `dart:<library>` or `package:<name>`. A layer absent from this map may
  /// import anything, which is the right default for `presentation` and
  /// `infrastructure` — those layers exist precisely to touch the outside
  /// world.
  final Map<String, Set<String>> allowedExternalDependencies;

  /// Whether a feature may reach another feature, and how.
  final CrossFeatureAccess crossFeatureAccess;

  /// Path segments that identify the composition root, where wiring up
  /// dependencies (and therefore touching the service locator) is legitimate.
  final Set<String> compositionRootSegments;

  /// Whether [from] may depend on [to].
  bool allowsLayerDependency({required String from, required String to}) {
    if (from == to) return true;

    final allowed = allowedLayerDependencies[from];
    if (allowed == null) return true;

    return allowed.contains(to);
  }

  /// Whether [layer] may depend on the external dependency [identifier]
  /// (`dart:async`, `package:flutter`, ...).
  bool allowsExternalDependency({required String layer, required String identifier}) {
    final allowed = allowedExternalDependencies[layer];
    if (allowed == null) return true;

    return allowed.contains(identifier);
  }

  static const Set<String> _defaultLayers = {'presentation', 'application', 'domain', 'infrastructure'};

  static const Set<String> _defaultGlobalModules = {'bootstrap', 'core', 'design_system', 'shared'};

  // NOTE — two deliberate policy choices, both easy to flip:
  //
  //  * `presentation -> domain` is ALLOWED here. Forbidding it (as the first
  //    draft of this plugin did) means a BLoC cannot even name a domain
  //    entity, which forces a parallel set of presentation models for every
  //    entity in the system. That is a defensible but expensive stance; if you
  //    want it, remove 'domain' from the presentation set.
  //
  //  * `infrastructure -> application` is FORBIDDEN here. Infrastructure
  //    implements ports declared by the inner layers; if it needs to call a
  //    use case, the dependency is pointing the wrong way. If your ports live
  //    in `application` rather than `domain`, add 'application' back.
  static const Map<String, Set<String>> _defaultAllowedLayerDependencies = {
    'presentation': {'application'},
    'application': {'domain'},
    'domain': <String>{},
    'infrastructure': {'domain'},
  };

  static const Set<String> _pureDartLibraries = {
    'dart:core',
    'dart:async',
    'dart:collection',
    'dart:convert',
    'dart:math',
    'dart:typed_data',
  };

  static const Map<String, Set<String>> _defaultAllowedExternalDependencies = {
    'domain': {..._pureDartLibraries, 'package:meta', 'package:collection', 'package:equatable', 'package:fpdart'},
    'application': {..._pureDartLibraries, 'package:meta', 'package:collection', 'package:equatable', 'package:fpdart'},
    // 'presentation' and 'infrastructure' are intentionally absent: they are
    // the layers that are supposed to depend on frameworks and SDKs.
  };

  static const Set<String> _defaultCompositionRootSegments = {'bootstrap', 'di', 'injection'};
}
