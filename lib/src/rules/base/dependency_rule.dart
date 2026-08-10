import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../config/pulse_architecture.dart';
import '../../model/module_location.dart';
import '../../utils/directive_target.dart';

/// Base class for every rule that inspects a dependency edge between two
/// libraries.
///
/// It centralises the four things all such rules were duplicating:
///
///  * registering **both** `import` and `export` — an `export` creates exactly
///    the same compile-time dependency, and leaving it unchecked is a hole big
///    enough to drive a barrel file through;
///  * resolving the directive target to a canonical URI;
///  * locating the current library in the architecture;
///  * bailing out quietly on anything outside `lib/` or outside the known
///    project structure.
///
/// Subclasses implement a single method and stay about fifteen lines long.
abstract class DependencyRule extends AnalysisRule {
  DependencyRule({
    required super.name,
    required super.description,
    this.architecture = PulseArchitecture.instance,
  });

  final PulseArchitecture architecture;

  /// Called once per `import`/`export` directive in a library that could be
  /// located inside the architecture.
  ///
  /// [node] is the directive (report against it), [source] is where the
  /// importing library lives, and [target] is the canonical URI being pulled
  /// in — which may be a `dart:` URI or another package.
  void checkDependency({
    required Directive node,
    required ModuleLocation source,
    required Uri target,
  });

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _DirectiveVisitor(this, context);

    registry.addImportDirective(this, visitor);
    registry.addExportDirective(this, visitor);
  }
}

class _DirectiveVisitor extends SimpleAstVisitor<void> {
  _DirectiveVisitor(this._rule, this._context);

  final DependencyRule _rule;
  final RuleContext _context;

  @override
  void visitImportDirective(ImportDirective node) => _check(node);

  @override
  void visitExportDirective(ExportDirective node) => _check(node);

  void _check(Directive node) {
    // The canonical URI of the library being analysed. Non-`package:` URIs
    // (test/, bin/, tool/) fall outside the architecture on purpose.
    final libraryUri = _context.libraryElement?.uri;
    if (libraryUri == null) return;

    final source = ModuleLocation.parse(libraryUri, _rule.architecture);
    if (source == null) return;

    final target = resolveDirectiveTarget(
      node: node,
      libraryUri: libraryUri,
    );
    if (target == null) return;

    _rule.checkDependency(node: node, source: source, target: target);
  }
}
