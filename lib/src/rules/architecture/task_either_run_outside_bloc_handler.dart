import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../../diagnostics/diagnostic_codes.dart';

/// The `fpdart` type whose effect must be executed exactly once, at the edge of
/// the application.
const _taskEitherTypeName = 'TaskEither';

/// The `bloc` base class that declares `on<Event>(handler)`.
const _blocTypeName = 'Bloc';

/// The registration method declared by [_blocTypeName].
const _registrationMethodName = 'on';

/// The method that executes a [_taskEitherTypeName].
const _runMethodName = 'run';

/// Requires `TaskEither.run()` to appear only inside a registered Bloc event
/// handler.
///
/// A `TaskEither` is a *description* of an effect, not the effect itself. The
/// value is built in the inner layers and passed outward untouched; `run()` is
/// the single point where the description becomes execution. Concentrating that
/// point in the event handler is what makes the layers below it referentially
/// transparent and trivially composable — a repository that has already run its
/// effect cannot be combined into a larger one, and a use case that has already
/// run its effect cannot be retried, timed out, or short-circuited by its
/// caller.
///
/// The rule therefore treats `run()` as a *boundary* operation rather than a
/// style preference, and allows exactly one home for it.
final class TaskEitherRunOutsideBlocHandler extends AnalysisRule {
  static const LintCode code = PulseDiagnosticCodes.taskEitherRunOutsideBlocHandler;

  TaskEitherRunOutsideBlocHandler()
    : super(
        name: 'pulse_task_either_run_outside_bloc_handler',
        description:
            'Requires TaskEither.run() to be called only inside Bloc '
            'event handlers.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    registry.addMethodInvocation(this, _Visitor(this));
  }
}

final class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this._rule);

  final TaskEitherRunOutsideBlocHandler _rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!isTaskEitherRunInvocation(node)) return;
    if (isInsideRegisteredBlocEventHandler(node)) return;

    _rule.reportAtNode(node.methodName);
  }
}

/// Whether [node] invokes `run()` on a value statically known to be a
/// `TaskEither`.
///
/// The check is driven by the resolved static type of the receiver, so an
/// unrelated `run()` — on a user-defined class, on a `Future`, or an unqualified
/// call to a local `run()` — is never matched. `realTarget` rather than `target`
/// so that a cascade (`task..run()`) is covered as well.
///
/// The type is matched by element *name* only, not by declaring library. That
/// is deliberate and load-bearing: it is the detection strategy already
/// verified against analyzer 14.1.0 on this project. The cost is that a
/// same-named type from another package would also match, which is worth
/// revisiting only if that ever actually happens.
///
/// Public so the rule's decision logic can be exercised from tests without
/// booting the plugin host.
bool isTaskEitherRunInvocation(MethodInvocation node) {
  if (node.methodName.name != _runMethodName) return false;

  final targetType = node.realTarget?.staticType;
  if (targetType is! InterfaceType) return false;

  return targetType.element.name == _taskEitherTypeName;
}

/// Whether [node] is lexically enclosed by a function that Bloc actually
/// registered as an event handler.
///
/// "Lexically enclosed", not "reachable from". A closure written *inside* a
/// handler body is still inside the handler and is allowed — that is what makes
/// `await emit.forEach(...)` and `await Future.wait([...])` work. A separate
/// method that a handler happens to *call* is not, because the walk stops at
/// the first [MethodDeclaration] boundary. No call-graph analysis is performed,
/// by design: it would be unsound across files, and "the effect runs where the
/// event is handled" is a claim about the code's shape, not about its runtime
/// reachability.
///
/// Public so the rule's decision logic can be exercised from tests without
/// booting the plugin host.
bool isInsideRegisteredBlocEventHandler(AstNode node) {
  for (AstNode? current = node; current != null; current = current.parent) {
    // A closure passed directly to `on<Event>(...)`.
    if (current is FunctionExpression && _isInlineEventHandler(current)) {
      return true;
    }

    // A method declaration is the outermost enclosing function that can be an
    // event handler; anything above it is a class body. Whether the method is a
    // handler is the final answer either way, so stop here.
    if (current is MethodDeclaration) {
      return _isRegisteredEventHandlerMethod(current);
    }
  }

  return false;
}

/// Whether [function] is the handler argument of a `Bloc.on<Event>(...)` call.
///
/// Only a *positional* argument qualifies. A closure passed as `transformer:`
/// is parented by a `NamedExpression` rather than the `ArgumentList`, so it
/// falls out naturally — which is correct, since a transformer runs per event
/// but is not the handler.
bool _isInlineEventHandler(FunctionExpression function) {
  final arguments = function.parent;
  if (arguments is! ArgumentList) return false;

  final invocation = arguments.parent;

  return invocation is MethodInvocation && _isEventRegistration(invocation);
}

/// Whether [method] is passed by reference to `on<Event>(...)` somewhere in the
/// class that declares it.
///
/// Registration is looked up in the enclosing class body rather than in the
/// constructor alone, so the common `_registerHandlers()` indirection keeps
/// working.
bool _isRegisteredEventHandlerMethod(MethodDeclaration method) {
  if (method.isStatic || method.isGetter || method.isSetter) return false;

  final owner = method.thisOrAncestorOfType<ClassDeclaration>();
  if (owner == null) return false;

  final collector = _EventHandlerRegistrationCollector();
  owner.accept(collector);

  return collector.handlerNames.contains(method.name.lexeme);
}

/// Whether [invocation] is `on<Event>(handler)` dispatched on a Bloc.
///
/// Three conditions, none of which is a naming convention on its own:
///
///  * the method is named `on` and is called on `this` (implicitly or
///    explicitly) — `Bloc.on` is protected, so registration can only ever
///    happen from inside the Bloc itself;
///  * it has at least one argument, the handler;
///  * the enclosing class resolves to a subtype of `Bloc`, checked through the
///    supertype chain so that a project-specific `BaseBloc` still counts.
///
/// The type argument (`on<LoginRequested>`) is intentionally *not* required:
/// it is inferable from the handler's signature, so demanding it would reject
/// valid code.
bool _isEventRegistration(MethodInvocation invocation) {
  if (invocation.methodName.name != _registrationMethodName) return false;

  final target = invocation.realTarget;
  if (target != null && target is! ThisExpression) return false;

  if (invocation.argumentList.arguments.isEmpty) return false;

  final owner = invocation.thisOrAncestorOfType<ClassDeclaration>();

  return owner != null && _extendsBloc(owner);
}

/// Whether [declaration] has `Bloc` anywhere in its superclass chain.
bool _extendsBloc(ClassDeclaration declaration) {
  final supertype = declaration.extendsClause?.superclass.type;
  if (supertype is! InterfaceType) return false;

  return _isBloc(supertype) || supertype.allSupertypes.any(_isBloc);
}

bool _isBloc(InterfaceType type) => type.element.name == _blocTypeName;

/// Collects the names of every method handed to `on<Event>(...)` inside a class.
///
/// Recursive, because registration can sit inside the constructor body, inside
/// a helper method, or inside a closure in either.
final class _EventHandlerRegistrationCollector extends RecursiveAstVisitor<void> {
  final Set<String> handlerNames = <String>{};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    if (!_isEventRegistration(node)) return;

    final name = _handlerNameOf(node.argumentList.arguments.first);
    if (name != null) handlerNames.add(name);
  }

  /// The method name behind a tear-off, for the two forms that can appear here:
  /// `on<E>(_onLogin)` and `on<E>(this._onLogin)`.
  ///
  /// Matching by name is sound because the comparison is scope-bounded: both
  /// the reference and the declaration are looked up within one class body,
  /// where a bare identifier naming a member resolves to that member. This is
  /// not a naming heuristic — a method called `_onLogin` that is never passed
  /// to `on(...)` is still rejected, and a method called `frobnicate` that is
  /// passed to `on(...)` is still allowed.
  String? _handlerNameOf(Object? argument) {
    final expression = switch (argument) {
      final Expression value => value,
      final AstNode node => _firstExpressionIn(node),
      _ => null,
    };

    return switch (expression) {
      SimpleIdentifier(:final name) => name,
      PropertyAccess(target: ThisExpression(), :final propertyName) => propertyName.name,
      _ => null,
    };
  }

  Expression? _firstExpressionIn(AstNode node) {
    for (final entity in node.childEntities) {
      if (entity is Expression) return entity;
    }
    return null;
  }
}
