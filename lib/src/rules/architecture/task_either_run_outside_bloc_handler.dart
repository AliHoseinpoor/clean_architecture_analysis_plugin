import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import '../../diagnostics/diagnostic_codes.dart';

/// Prevents TaskEither effects from being executed outside Bloc event
/// handlers.
///
/// Pulse treats the Bloc event handler as the execution boundary for
/// TaskEither. Lower layers must create and pass TaskEither values upward
/// without calling `.run()`.
///
/// Allowed:
///
/// ```dart
/// class AuthBloc extends Bloc<AuthEvent, AuthState> {
///   AuthBloc(this._login) {
///     on<LoginRequested>(_onLogin);
///   }
///
///   Future<void> _onLogin(
///     LoginRequested event,
///     Emitter<AuthState> emit,
///   ) async {
///     final result = await _login().run();
///   }
/// }
/// ```
///
/// Not allowed:
///
/// ```dart
/// class LoginUseCase {
///   Future<void> execute() async {
///     await _repository.login().run();
///   }
/// }
/// ```
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
    if (node.methodName.name != 'run') {
      return;
    }

    if (!_isTaskEitherRun(node)) {
      return;
    }

    if (_isInsideBlocEventHandler(node)) {
      return;
    }

    _rule.reportAtNode(node.methodName);
  }

  bool _isTaskEitherRun(MethodInvocation node) {
    final targetType = node.target?.staticType;

    if (targetType is! InterfaceType) {
      return false;
    }

    return _isTaskEither(targetType.element);
  }

  bool _isTaskEither(InterfaceElement element) {
    final libraryUri = element.library.uri;

    if (libraryUri.toString() != 'package:fpdart/fpdart.dart') {
      return false;
    }

    return element.name == 'TaskEither';
  }

  bool _isInsideBlocEventHandler(AstNode node) {
    final method = node.thisOrAncestorOfType<MethodDeclaration>();

    if (method != null && _isRegisteredBlocHandler(method)) {
      return true;
    }

    final function = node.thisOrAncestorOfType<FunctionExpression>();

    if (function != null && _isInlineBlocHandler(function)) {
      return true;
    }

    return false;
  }

  bool _isRegisteredBlocHandler(MethodDeclaration method) {
    final classDeclaration = method.thisOrAncestorOfType<ClassDeclaration>();

    if (classDeclaration == null) {
      return false;
    }

    final classElement = classDeclaration.declaredFragment?.element;

    if (classElement == null || !_isBloc(classElement)) {
      return false;
    }

    final methodName = method.name.lexeme;

    return _isPassedToBlocOn(method, methodName);
  }

  bool _isBloc(InterfaceElement element) {
    return element.allSupertypes.any((supertype) {
      final superElement = supertype.element;

      return superElement.library.uri.toString() == 'package:bloc/bloc.dart' && superElement.name == 'Bloc';
    });
  }

  bool _isPassedToBlocOn(MethodDeclaration method, String methodName) {
    final compilationUnit = method.root;

    var found = false;

    compilationUnit.accept(_BlocHandlerReferenceVisitor(methodName: methodName, onFound: () => found = true));

    return found;
  }

  bool _isInlineBlocHandler(FunctionExpression function) {
    final invocation = function.thisOrAncestorOfType<MethodInvocation>();

    if (invocation == null || invocation.methodName.name != 'on') {
      return false;
    }

    final target = invocation.target;

    if (target != null && target is! ThisExpression) {
      return false;
    }

    final classDeclaration = function.thisOrAncestorOfType<ClassDeclaration>();

    if (classDeclaration == null) {
      return false;
    }

    final classElement = classDeclaration.declaredFragment?.element;

    if (classElement == null) {
      return false;
    }

    return _isBloc(classElement);
  }
}

final class _BlocHandlerReferenceVisitor extends RecursiveAstVisitor<void> {
  _BlocHandlerReferenceVisitor({required this.methodName, required this.onFound});

  final String methodName;
  final void Function() onFound;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name != 'on') {
      super.visitMethodInvocation(node);
      return;
    }

    for (final argument in node.argumentList.arguments) {
      if (argument is SimpleIdentifier && argument.name == methodName) {
        onFound();
        return;
      }
    }

    super.visitMethodInvocation(node);
  }
}
