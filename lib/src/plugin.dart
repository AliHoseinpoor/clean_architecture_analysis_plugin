import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'rules/architecture/disallowed_external_dependency.dart';
import 'rules/architecture/layer_dependency_direction.dart';
import 'rules/architecture/no_cross_feature_import.dart';
import 'rules/architecture/no_feature_import_in_global.dart';

class AnalysisPlugin extends Plugin {
  @override
  String get name => 'analysis_plugin';

  @override
  void register(PluginRegistry registry) {
    // Structural rules. Registered as warnings: they describe invariants that
    // hold for any project using this layout, and a violation is a defect
    // rather than a style preference. Warnings are on by default, so a project
    // cannot forget to enable them.
    registry.registerWarningRule(LayerDependencyDirection());
    registry.registerWarningRule(NoCrossFeatureImport());
    registry.registerWarningRule(NoFeatureImportInGlobal());
    registry.registerWarningRule(DisallowedExternalDependency());
  }
}
