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
    this.restrictedLayerDependencies = _defaultRestrictedLayerDependencies,
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

  /// Allowed layer dependencies that may only reach some folders of the
  /// target layer.
  ///
  /// `from -> to -> folders`: when `from` imports `to`, the first folder below
  /// `to` must be one of `folders`. A pair absent from this map is governed by
  /// [allowedLayerDependencies] alone. A pair present here must also be
  /// allowed there; this map only narrows it.
  final Map<String, Map<String, Set<String>>> restrictedLayerDependencies;

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
  ///
  /// [targetFolder] is the first folder below the target layer
  /// (`errors` for `domain/errors/auth_error.dart`), or `null` when the target
  /// sits directly in the layer folder. It only matters for pairs listed in
  /// [restrictedLayerDependencies].
  bool allowsLayerDependency({
    required String from,
    required String to,
    String? targetFolder,
  }) {
    if (from == to) return true;

    final allowed = allowedLayerDependencies[from];
    if (allowed == null) return true;
    if (!allowed.contains(to)) return false;

    final folders = restrictedLayerDependencies[from]?[to];
    if (folders == null) return true;

    return targetFolder != null && folders.contains(targetFolder);
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

  // NOTE — two deliberate policy choices:
  //
  //  * `presentation -> domain` is allowed only into `domain/errors/` and
  //    `domain/value_objects/` (Pulse ADR-020 §1–2 as amended by ADR-032 §1).
  //    A bloc must pattern-match operation errors, and a form validates
  //    through value objects; entities, repositories (ports) and domain
  //    services stay behind the boundary, because entities carry mutating
  //    behaviour the UI must not call. See [_defaultRestrictedLayerDependencies].
  //
  //  * `infrastructure -> application` is FORBIDDEN here. Infrastructure
  //    implements ports declared by the inner layers; if it needs to call a
  //    use case, the dependency is pointing the wrong way. If your ports live
  //    in `application` rather than `domain`, add 'application' back.
  static const Map<String, Set<String>> _defaultAllowedLayerDependencies = {
    'presentation': {'application', 'domain'},
    'application': {'domain'},
    'domain': <String>{},
    'infrastructure': {'domain'},
  };

  static const Map<String, Map<String, Set<String>>> _defaultRestrictedLayerDependencies = {
    'presentation': {
      'domain': {'errors', 'value_objects'},
    },
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
    // `injectable` and `freezed_annotation` are pure-Dart annotation packages.
    // Use cases and mappers register themselves with `@injectable` (Pulse
    // ADR-024 §3) and UiModels may be Freezed (ADR-020 §3). Domain stays free
    // of both (ADR-020 §1, ADR-021 §7).
    'application': {
      ..._pureDartLibraries,
      'package:meta',
      'package:collection',
      'package:equatable',
      'package:fpdart',
      'package:injectable',
      'package:freezed_annotation',
    },
    // 'presentation' and 'infrastructure' are intentionally absent: they are
    // the layers that are supposed to depend on frameworks and SDKs.
  };

  static const Set<String> _defaultCompositionRootSegments = {'bootstrap', 'di', 'injection'};
}
