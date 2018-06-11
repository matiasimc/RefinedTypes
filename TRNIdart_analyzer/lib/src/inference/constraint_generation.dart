import 'package:TRNIdart_analyzer/TRNIdart_analyzer.dart';

class CompilationUnitVisitor extends SimpleAstVisitor {
  final Logger log = new Logger("CompilationUnitVisitor");
  Store store;
  ConstraintSet cs;
  IType chainedCallParentType;

  CompilationUnitVisitor() {
    this.store = new Store();
    this.cs = new ConstraintSet();
  }

  @override
  visitCompilationUnit(CompilationUnit node) {
    node.visitChildren(this);
  }

  @override
  visitClassDeclaration(ClassDeclaration node) {
    log.shout("Visiting class ${node.name}");
    node.members.accept(new ClassMemberVisitor(this.store, this.cs));
  }

}


class ClassMemberVisitor extends SimpleAstVisitor {
  final Logger log = new Logger("ClassMemberVisitor");
  Store store;
  ConstraintSet cs;

  ClassMemberVisitor(this.store, this.cs);

  @override
  visitMethodDeclaration(MethodDeclaration node) {
    log.shout("Visiting method ${node.name}");
    /*
    First, we look for declared annotations in parameters. If exists, then we
    generate a DeclaredConstraint for the type variable and the declared type. Else,
    we just add the type variable.
     */
    List<IType> left = node.element.parameters.map((p) {
      Annotation a = AnnotationHelper.getDeclaredForParameter(p.computeNode());
      if (a == null) {
        IType tvar = store.getTypeOrVariable(p, new Top());
        return tvar;
      }
      else {
        // TODO generate object type from declared
        IType t = new DeclaredType(a.arguments.arguments.first.toString());
        IType tvar = this.store.getTypeOrVariable(p, new Top());
        this.cs.addConstraint(new DeclaredConstraint(tvar, t));
        return tvar;
      }
    }).toList();
    /*
    The same goes for the return type. Then, we create the ArrowType.
    TODO if the method element exists in the store, we should create a constraint for the return type
     */
    Annotation a = AnnotationHelper.getDeclared(node);
    IType right = a != null ?
      new DeclaredType(a.arguments.arguments.first.toString()) :
      store.getTypeVariable(new Bot());
    IType t = new ArrowType(left, right);
    /*
    If the store doesn't has the method element, we add it. Else, we create the
    constraint associating the type in the store with the newly created arrow
    type.
     */
    if (!store.hasElement(node.element)) {
      store.addElement(node.element, new ArrowType([new Top()], new Bot()), t);
    }
    else {
      cs.addConstraint(new SubtypingConstraint(store.getTypeOrVariable(node.element, new ArrowType([new Top()], new Bot())), t));
    }
    /*
    Finally, we process the method body.
     */
    node.body.accept(new MethodBodyVisitor(this.store, this.cs, right));
  }

  @override
  visitFieldDeclaration(FieldDeclaration node) {
    log.shout("Visiting field(s) ${node.fields.variables.join(',')}");
    if (store.hasElement(node.element)) return;
    Annotation a = AnnotationHelper.getDeclared(node);
    IType t = a != null ?
      new DeclaredType(a.arguments.arguments.first.toString()) :
      store.getTypeVariable(new Bot());
    store.addElement(node.element, new Bot(), t);
  }

  @override
  visitConstructorDeclaration(ConstructorDeclaration node) {
    log.shout("Visiting constructor");
    if (!store.hasElement(node.element)) {
      List<IType> left = node.parameters.parameters.map((p) {
        Annotation a = AnnotationHelper.getDeclaredForParameter(p);
        if (a == null)
          return store.getTypeVariable(new Top());
        else
          return new DeclaredType(a.arguments.arguments.first.toString());
      }).toList();
      Annotation a = AnnotationHelper.getDeclared(node);
      IType right = a != null ?
      new DeclaredType(a.arguments.arguments.first.toString()) :
      store.getTypeVariable(new Bot());
      store.addElement(node.element, new ArrowType([new Top()], new Bot()), new ArrowType(left, right));
    }
  }
}

class MethodBodyVisitor extends RecursiveAstVisitor {
  final Logger log = new Logger("MethodBodyVisitor");
  Store store;
  ConstraintSet cs;
  IType returnType;
  IType chainedCallParentType;

  MethodBodyVisitor(this.store, this.cs, this.returnType);

  @override
  visitMethodInvocation(MethodInvocation node) {
    log.shout("Found method invocation ${node}");
    /*
    First, we identify the target node. If it's a variable, we get it from the
    store. Else, we generate a type variable.
     */
    AstNode target = node.target;
    IType targetType;
    if (target is SimpleIdentifier) {
      targetType = this.store.getTypeOrVariable(target.bestElement, new Bot());
    }
    if (targetType == null) targetType = this.store.getTypeVariable(new Bot());
    /*
    Now we check the method signature. If the method is from the dart core
    library, we generate type variables and default constraints. Else, we
    get the type from the store.
     */
    ArrowType methodSignature;
    if (node.staticInvokeType.element.library.isDartCore) {
      IType tr = this.store.getTypeVariable(new Bot());
      this.cs.addConstraint(new SubtypingConstraint(new Bot(), tr));
      methodSignature = new ArrowType(node.argumentList.arguments.map((a) {
        IType ta = this.store.getTypeVariable(new Top());
        this.cs.addConstraint(new SubtypingConstraint(ta, new Top()));
        return ta;
      }).toList(), tr);
    }
    else {
      methodSignature = this.store.getTypeOrVariable(
          node.staticInvokeType.element, new ArrowType([new Top()], new Bot()));
    }
    /*
    Now we generate the object type and the constraint for the target, and
    check if the target is part of a chained method call. If it is, we add the
    corresponding constraint.
     */
    IType callType = new ObjectType(
        {node.methodName.toString(): methodSignature});
    // TVar(i) <: {m: x -> y}
    this.cs.addConstraint(new SubtypingConstraint(targetType, callType));
    if (node.parent is MethodInvocation || node.parent is PrefixedIdentifier) {
      // y <: chainedCallParentType
      this.cs.addConstraint(new SubtypingConstraint(methodSignature.rightSide, chainedCallParentType));
    }
    /*
    Finally, we update the variable that store the necessary type for chained
    method calls.
     */
    chainedCallParentType = targetType;
    return super.visitMethodInvocation(node);
  }

  @override
  visitReturnStatement(ReturnStatement node) {
    Expression e = node.expression;
    Element element;
    if (e is Identifier) element = e.bestElement;
    else if (e is InstanceCreationExpression) element = e.staticElement;
    else if (e is MethodInvocation) element = e.staticInvokeType.element;
    else if (e is PrefixedIdentifier) element = e.bestElement;
    this.cs.addConstraint(new SubtypingConstraint(this.store.getTypeOrVariable(element, new Bot()), this.returnType));
    return super.visitReturnStatement(node);
  }
}