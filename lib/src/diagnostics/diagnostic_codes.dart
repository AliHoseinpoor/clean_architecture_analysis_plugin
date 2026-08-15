import 'package:analyzer/error/error.dart';

/// Every diagnostic this plugin can report.
///
/// Each code is a `static const` so exactly one instance exists per code. That
/// is a functional requirement, not a style choice: the analysis server matches
/// codes by identity when resolving `// ignore:` comments, and duplicate
/// instances silently break suppression for users of the plugin.
///
/// The code name always equals the rule name, so that enabling a rule
/// (`diagnostics: pulse_x: true`) and suppressing a diagnostic
/// (`// ignore: pulse_analysis_plugin/pulse_x`) use the same identifier.
abstract final class PulseDiagnosticCodes {
  static const LintCode taskEitherRunOutsideBlocHandler = LintCode(
    'pulse_task_either_run_outside_bloc_handler',
    'TaskEither.run() must only be called inside a Bloc event handler.',
    correctionMessage:
    'Return or pass the TaskEither upward and call .run() in the Bloc event handler.',
  );
  static const LintCode invalidLayerDependency = LintCode(
    'pulse_invalid_layer_dependency',
    "The '{0}' layer must not depend on the '{1}' layer.",
    correctionMessage:
        'Try depending on an inner layer, or invert the dependency with an '
        'abstraction owned by the inner layer.',
  );

  static const LintCode noCrossFeatureImport = LintCode(
    'pulse_no_cross_feature_import',
    "Feature '{0}' must not reach into the internals of feature '{1}'.",
    correctionMessage:
        "Try importing 'package:<app>/features/{1}/{1}.dart', or move the "
        'shared contract into a global module.',
  );

  static const LintCode noFeatureImportInGlobal = LintCode(
    'pulse_no_feature_import_in_global',
    "The global module '{0}' must not depend on feature '{1}'.",
    correctionMessage:
        'Try moving the shared abstraction into the global module and letting '
        'the feature depend on it instead.',
  );

  static const LintCode disallowedExternalDependency = LintCode(
    'pulse_disallowed_external_dependency',
    "The '{0}' layer must not depend on '{1}'.",
    correctionMessage:
        'Try declaring an abstraction in this layer and implementing it in an '
        'outer layer.',
  );

  static const LintCode mutableDomainEntity = LintCode(
    'pulse_mutable_domain_entity',
    "The field '{0}' is mutable; types in the '{1}' layer must be immutable.",
    correctionMessage:
        "Try marking the field 'final' and returning a modified copy instead "
        'of mutating in place.',
  );

  static const LintCode fileSuffixConvention = LintCode(
    'pulse_file_suffix_convention',
    "Files in '{0}' must end with '{1}'.",
    correctionMessage: 'Try renaming the file to match the convention.',
  );

  static const LintCode serviceLocatorOutsideCompositionRoot = LintCode(
    'pulse_service_locator_outside_composition_root',
    "'{0}' is a service locator and must only be used in the composition root.",
    correctionMessage:
        'Try injecting the dependency through the constructor instead.',
  );
}
