package crossj.cj;

import crossj.base.Assert;
import crossj.base.List;
import crossj.base.Optional;
import crossj.base.Pair;
import crossj.base.Tuple3;
import crossj.base.Tuple4;

// TODO: Refactor to address the hack used for implementing nested items.
public final class CJParser {
    private static final int ASSIGNMENT_PRECEDENCE = getTokenPrecedence('=');
    private static final int LOGICAL_NOT_PRECEDENCE = getTokenPrecedence(CJToken.EQ) + 5;
    private static final int UNARY_OP_PRECEDENCE = getTokenPrecedence('*') + 5;

    public static CJAstItemDefinition parseString(String path, String string) {
        var tokens = CJLexer.lex(string).get();
        var parser = new CJParser(path, tokens);
        return parser.parseTranslationUnit();
    }

    private final String path;
    private final List<CJToken> tokens;
    private int i = 0;

    private CJParser(String path, List<CJToken> tokens) {
        this.path = path;
        this.tokens = tokens;
    }

    private CJMark getMark() {
        return CJMark.fromToken(path, peek());
    }

    private CJToken peek() {
        return tokens.get(i);
    }

    private CJToken next() {
        return tokens.get(i++);
    }

    private boolean at(int type) {
        return peek().type == type;
    }

    private boolean atOffset(int type, int offset) {
        var j = i + offset;
        return j < tokens.size() && tokens.get(j).type == type;
    }

    private CJToken expect(int type) {
        if (!at(type)) {
            throw etype(type);
        }
        return next();
    }

    private boolean consume(int type) {
        if (at(type)) {
            next();
            return true;
        }
        return false;
    }

    private CJError etype(int type) {
        return ekind(CJToken.typeToString(type));
    }

    private CJError ekind(String kind) {
        return CJError.of("Expected " + kind + " but got " + CJToken.typeToString(peek().type), getMark());
    }

    private void expectDelimiters() {
        if (!at(';') && !at('}') && !at('\n')) {
            throw ekind("delimiter");
        }
        skipDelimiters();
    }

    private void skipDelimiters() {
        while (at(';') || at('\n')) {
            next();
        }
    }

    private String parseId() {
        return expect(CJToken.ID).text;
    }

    private String parseTypeId() {
        return expect(CJToken.TYPE_ID).text;
    }

    private Optional<String> parseComment() {
        if (at(CJToken.COMMENT)) {
            var ret = Optional.of(expect(CJToken.COMMENT).text);
            expectDelimiters();
            return ret;
        } else {
            return Optional.empty();
        }
    }

    private List<CJIRModifier> parseModifiers() {
        var modifiers = List.<CJIRModifier>of();
        var repeat = true;
        while (repeat) {
            switch (peek().type) {
                case CJToken.KW_NATIVE: {
                    next();
                    modifiers.add(CJIRModifier.Native);
                    break;
                }
                case CJToken.KW_STATIC: {
                    next();
                    modifiers.add(CJIRModifier.Static);
                    break;
                }
                case CJToken.KW_PUBLIC: {
                    next();
                    modifiers.add(CJIRModifier.Public);
                    break;
                }
                case CJToken.KW_PRIVATE: {
                    next();
                    modifiers.add(CJIRModifier.Private);
                    break;
                }
                case CJToken.KW_ASYNC: {
                    next();
                    modifiers.add(CJIRModifier.Async);
                    break;
                }
                default: {
                    repeat = false;
                }
            }
        }
        return modifiers;
    }

    private CJIRItemKind parseItemKind() {
        switch (peek().type) {
            case CJToken.KW_CLASS:
                next();
                return CJIRItemKind.Class;
            case CJToken.KW_UNION:
                next();
                return CJIRItemKind.Union;
            case CJToken.KW_TRAIT:
                next();
                return CJIRItemKind.Trait;
        }
        throw ekind("class, union or trait");
    }

    private String parsePackageName() {
        var sb = new StringBuilder();
        sb.append(parseId());
        while (at('.') && atOffset(CJToken.ID, 1)) {
            expect('.');
            sb.append('.');
            sb.append(parseId());
        }
        return sb.toString();
    }

    private Pair<String, Optional<String>> parseFullItemNameAndAlias() {
        var packageName = parsePackageName();
        expect('.');
        var name = packageName + "." + parseTypeId();
        while (consume('.')) {
            name += "." + parseTypeId();
        }
        Optional<String> alias = consume(CJToken.KW_AS) ? Optional.of(parseTypeId()) : Optional.empty();
        return Pair.of(name, alias);
    }

    private CJAstItemDefinition parseTranslationUnit() {
        expect(CJToken.KW_PACKAGE);
        var packageName = parsePackageName();
        expectDelimiters();
        var imports = List.<CJAstImport>of();
        while (at(CJToken.KW_IMPORT)) {
            imports.add(parseImport());
        }
        var comment = parseComment();
        var annotations = parseAnnotations();
        var modifiers = parseModifiers();
        var kind = parseItemKind();
        var mark = getMark();
        var shortName = parseTypeId();
        imports.add(new CJAstImport(mark, packageName + "." + shortName, Optional.empty()));
        var typeParameters = parseTypeParameters(true);
        var traitDeclarations = parseTraitDeclarations();
        skipDelimiters();
        expect('{');
        skipDelimiters();
        var members = List.<CJAstItemMemberDefinition>of();
        while (!consume('}')) {
            members.add(parseItemMember(packageName, shortName, imports));
        }
        skipDelimiters();
        if (!at(CJToken.EOF)) {
            throw ekind("EOF");
        }
        return new CJAstItemDefinition(mark, packageName, imports, comment, annotations, modifiers, kind, shortName,
                typeParameters, traitDeclarations, members);
    }

    private List<CJAstAnnotationExpression> parseAnnotations() {
        var list = List.<CJAstAnnotationExpression>of();
        while (consume('@')) {
            list.add(parseAnnotationExpression());
            skipDelimiters();
        }
        return list;
    }

    private CJAstAnnotationExpression parseAnnotationExpression() {
        var mark = getMark();
        String name;
        switch (peek().type) {
            case CJToken.INT:
            case CJToken.DOUBLE:
                name = next().text;
                break;
            default:
                name = parseId();
        }
        var args = List.<CJAstAnnotationExpression>of();
        if (consume('(')) {
            while (!consume(')')) {
                args.add(parseAnnotationExpression());
                if (!consume(',')) {
                    expect(')');
                    break;
                }
            }
        }
        return new CJAstAnnotationExpression(mark, name, args);
    }

    private List<CJAstTypeParameter> parseTypeParameters(boolean itemLevel) {
        var parameters = List.<CJAstTypeParameter>of();
        if (consume('[')) {
            while (!consume(']')) {
                parameters.add(parseTypeParameter(itemLevel));
                if (!consume(',')) {
                    expect(']');
                    break;
                }
            }
        }
        return parameters;
    }

    private CJAstTypeParameter parseTypeParameter(boolean itemLevel) {
        var annotations = parseAnnotations();
        var mark = getMark();
        var name = parseTypeId();
        if (consume('?')) {
            annotations.add(new CJAstAnnotationExpression(mark, "nullable", List.of()));
        }
        var traits = List.<CJAstTraitExpression>of();
        if (consume(':')) {
            traits.add(parseTraitExpression());
            while (consume('&')) {
                traits.add(parseTraitExpression());
            }
        }
        return new CJAstTypeParameter(mark, itemLevel, annotations, name, traits);
    }

    private CJAstTraitExpression parseTraitExpression() {
        var mark = getMark();
        var name = parseTypeId();
        var args = parseTypeArgs();
        return new CJAstTraitExpression(mark, name, args);
    }

    private CJAstTypeExpression parseTypeExpression() {
        var mark = getMark();
        var name = parseTypeId();
        while (at('.') && atOffset(CJToken.TYPE_ID, 1)) {
            expect('.');
            name += "." + parseTypeId();
        }
        var args = parseTypeArgs();
        return new CJAstTypeExpression(mark, name, args);
    }

    private List<CJAstTypeExpression> parseTypeArgs() {
        var args = List.<CJAstTypeExpression>of();
        if (consume('[')) {
            while (!consume(']')) {
                args.add(parseTypeExpression());
                if (!consume(',')) {
                    expect(']');
                    break;
                }
            }
        }
        return args;
    }

    private CJAstImport parseImport() {
        expect(CJToken.KW_IMPORT);
        var mark = getMark();
        var pair = parseFullItemNameAndAlias();
        var fullName = pair.get1();
        var alias = pair.get2();
        expectDelimiters();
        return new CJAstImport(mark, fullName, alias);
    }

    private List<CJAstTraitDeclaration> parseTraitDeclarations() {
        var declarations = List.<CJAstTraitDeclaration>of();
        skipDelimiters();
        if (consume(':')) {
            skipDelimiters();
            declarations.add(parseTraitDeclaration());
            skipDelimiters();
            while (consume(',')) {
                skipDelimiters();
                declarations.add(parseTraitDeclaration());
                skipDelimiters();
            }
        }
        return declarations;
    }

    private CJAstTraitDeclaration parseTraitDeclaration() {
        var mark = getMark();
        var trait = parseTraitExpression();
        var conditions = List.<CJAstTypeCondition>of();
        if (consume(CJToken.KW_IF)) {
            conditions.add(parseTypeCondition());
            while (consume(CJToken.KW_AND)) {
                conditions.add(parseTypeCondition());
            }
        }
        return new CJAstTraitDeclaration(mark, trait, conditions);
    }

    private CJAstTypeCondition parseTypeCondition() {
        var mark = getMark();
        var variableName = parseTypeId();
        var traits = List.<CJAstTraitExpression>of();
        expect(':');
        traits.add(parseTraitExpression());
        while (consume('&')) {
            traits.add(parseTraitExpression());
        }
        return new CJAstTypeCondition(mark, variableName, traits);
    }

    private CJAstItemMemberDefinition parseItemMember(String outerPackageName, String outerShortName,
            List<CJAstImport> imports) {
        var comment = parseComment();
        var annotations = parseAnnotations();
        var modifiers = parseModifiers();
        switch (peek().type) {
            case CJToken.KW_VAL:
            case CJToken.KW_VAR:
                return parseFieldDefinition(comment, annotations, modifiers);
            case CJToken.KW_CASE:
                return parseCaseDefinition(comment, annotations, modifiers);
            case CJToken.KW_IF:
            case CJToken.KW_DEF:
                return parseMethod(comment, annotations, modifiers);
            case CJToken.KW_CLASS:
            case CJToken.KW_TRAIT:
            case CJToken.KW_UNION:
                return parseChildItemDefinition(outerPackageName, outerShortName, imports, comment, annotations,
                        modifiers);
        }
        throw ekind("val, var, def or if");
    }

    private CJAstItemDefinition parseChildItemDefinition(String outerPackageName, String outerShortName,
            List<CJAstImport> imports, Optional<String> comment, List<CJAstAnnotationExpression> annotations,
            List<CJIRModifier> modifiers) {
        var packageName = outerPackageName + "." + outerShortName;
        var kind = parseItemKind();
        var mark = getMark();
        var shortName = parseTypeId();
        imports.add(new CJAstImport(mark, packageName + "." + shortName, Optional.empty()));
        var typeParameters = parseTypeParameters(true);
        var traitDeclarations = parseTraitDeclarations();
        skipDelimiters();
        expect('{');
        skipDelimiters();
        var members = List.<CJAstItemMemberDefinition>of();
        while (!consume('}')) {
            members.add(parseItemMember(packageName, shortName, imports));
        }
        expectDelimiters();
        return new CJAstItemDefinition(mark, packageName, imports, comment, annotations, modifiers, kind, shortName,
                typeParameters, traitDeclarations, members);
    }

    private CJAstFieldDefinition parseFieldDefinition(Optional<String> comment,
            List<CJAstAnnotationExpression> annotations, List<CJIRModifier> modifiers) {
        var mutable = next().type == CJToken.KW_VAR;
        var mark = getMark();
        var name = parseId();
        expect(':');
        var type = parseTypeExpression();
        var expression = consume('=') ? Optional.of(parseExpression()) : Optional.<CJAstExpression>empty();
        expectDelimiters();
        return new CJAstFieldDefinition(mark, comment, annotations, modifiers, mutable, name, type, expression);
    }

    private CJAstCaseDefinition parseCaseDefinition(Optional<String> comment,
            List<CJAstAnnotationExpression> annotations, List<CJIRModifier> modifiers) {
        expect(CJToken.KW_CASE);
        var mark = getMark();
        var name = parseId();
        var types = List.<CJAstTypeExpression>of();
        if (consume('(')) {
            while (!consume(')')) {
                types.add(parseTypeExpression());
                if (!consume(',')) {
                    expect(')');
                    break;
                }
            }
        }
        expectDelimiters();
        return new CJAstCaseDefinition(mark, comment, annotations, modifiers, name, types);
    }

    private CJAstMethodDefinition parseMethod(Optional<String> comment, List<CJAstAnnotationExpression> annotations,
            List<CJIRModifier> modifiers) {
        var conditions = List.<CJAstTypeCondition>of();
        if (consume(CJToken.KW_IF)) {
            conditions.add(parseTypeCondition());
            while (consume(CJToken.KW_AND)) {
                conditions.add(parseTypeCondition());
            }
        }
        skipDelimiters();
        modifiers.addAll(parseModifiers());
        expect(CJToken.KW_DEF);
        var mark = getMark();
        var name = parseId();
        var typeParameters = parseTypeParameters(false);
        var parameters = parseParameters();
        var returnType = consume(':') ? Optional.of(parseTypeExpression()) : Optional.<CJAstTypeExpression>empty();
        var body = consume('=') ? Optional.of(parseExpression()) : Optional.<CJAstExpression>empty();
        expectDelimiters();
        return new CJAstMethodDefinition(mark, comment, annotations, conditions, modifiers, name, typeParameters,
                parameters, returnType, body);
    }

    private List<CJAstParameter> parseParameters() {
        expect('(');
        var list = List.<CJAstParameter>of();
        while (!consume(')')) {
            list.add(parseParameter());
            if (!consume(',')) {
                expect(')');
                break;
            }
        }
        return list;
    }

    private CJAstParameter parseParameter() {
        var mutable = consume(CJToken.KW_VAR);
        var mark = getMark();
        var name = parseId();
        expect(':');
        var type = parseTypeExpression();
        return new CJAstParameter(mark, mutable, name, type);
    }

    private CJAstExpression parseBlockElementExpression() {
        return parseExpressionWithPrecedenceUnchecked(0);
    }

    private CJAstExpression parseExpression() {
        // by default, parsing an expression doesn't handle assignments by default.
        return parseExpressionWithPrecedence(ASSIGNMENT_PRECEDENCE + 5);
    }

    private CJAstExpression parseIncrementExpression() {
        return parseExpressionWithPrecedence(0);
    }

    private CJAstExpression parseExpressionWithPrecedence(int precedence) {
        // We do this check so that variable declarations only appear directly as a block item.
        var expression = parseExpressionWithPrecedenceUnchecked(precedence);
        if (expression instanceof CJAstVariableDeclaration) {
            throw CJError.of("Variable declaration is not allowed here", expression.getMark());
        }
        return expression;
    }

    private CJAstExpression parseExpressionWithPrecedenceUnchecked(int precedence) {
        var expr = parseAtomExpression();
        var tokenPrecedence = getTokenPrecedence(peek().type);
        while (tokenPrecedence >= precedence) {
            var opMark = getMark();
            switch (peek().type) {
                case '.': {
                    next();
                    var methodMark = getMark();
                    if (consume(CJToken.KW_AWAIT)) {
                        expr = new CJAstAwait(methodMark, expr);
                    } else {
                        var name = parseId();
                        var args = List.of(expr);
                        if (atMethodArgsStart(i)) {
                            var typeArgs = parseTypeArgs();
                            args.addAll(parseArgs());
                            expr = new CJAstMethodCall(methodMark, Optional.empty(), name, typeArgs, args);
                        } else {
                            switch (peek().type) {
                                case '=':
                                case CJToken.PLUS_EQ: {
                                    String prefix;
                                    switch (peek().type) {
                                        case '=':
                                            prefix = "__set_";
                                            break;
                                        case CJToken.PLUS_EQ:
                                            prefix = "__augadd_";
                                            break;
                                        default:
                                            throw CJError.of(
                                                    "UNRECOGNIZED AUG ASSIGN TOK " + CJToken.typeToString(peek().type),
                                                    getMark());
                                    }
                                    next();
                                    var methodName = prefix + name;
                                    args.add(parseExpression());
                                    expr = new CJAstMethodCall(methodMark, Optional.empty(), methodName, List.of(),
                                            args);
                                    break;
                                }
                                default: {
                                    var methodName = "__get_" + name;
                                    expr = new CJAstMethodCall(methodMark, Optional.empty(), methodName, List.of(),
                                            args);
                                }
                            }
                        }
                    }
                    break;
                }
                case '[': {
                    var mark = getMark();
                    next();
                    var indexExpr = parseExpression();
                    expect(']');
                    if (consume('=')) {
                        var valexpr = parseExpression();
                        expr = new CJAstMethodCall(mark, Optional.empty(), "__setitem", List.of(),
                                List.of(expr, indexExpr, valexpr));
                    } else {
                        expr = new CJAstMethodCall(mark, Optional.empty(), "__getitem", List.of(),
                                List.of(expr, indexExpr));
                    }
                    break;
                }
                case ':': {
                    // a : b is syntactic sugar for (a, b)
                    var mark = getMark();
                    next();
                    var second = parseExpression();
                    expr = new CJAstTupleDisplay(mark, List.of(expr, second));
                    break;
                }
                case '=': {
                    next();
                    var valexpr = parseExpressionWithPrecedence(tokenPrecedence + 1);
                    var target = expressionToTarget(expr);
                    expr = new CJAstAssignment(opMark, target, valexpr);
                    break;
                }
                case CJToken.PLUS_EQ:
                case CJToken.MINUS_EQ:
                case CJToken.STAR_EQ:
                case CJToken.REM_EQ: {
                    var mark = getMark();
                    CJIRAugAssignKind kind;
                    switch (peek().type) {
                        case CJToken.PLUS_EQ:
                            kind = CJIRAugAssignKind.Add;
                            break;
                        case CJToken.MINUS_EQ:
                            kind = CJIRAugAssignKind.Subtract;
                            break;
                        case CJToken.STAR_EQ:
                            kind = CJIRAugAssignKind.Multiply;
                            break;
                        case CJToken.REM_EQ:
                            kind = CJIRAugAssignKind.Remainder;
                            break;
                        default:
                            throw CJError.of("Unrecognized augmented assignment kind", mark);
                    }
                    next();
                    var valexpr = parseExpressionWithPrecedence(tokenPrecedence + 1);
                    if (!(expr instanceof CJAstVariableAccess)) {
                        throw CJError.of("Augmented assignments are currently only supported for variables",
                                expr.getMark());
                    }
                    var name = ((CJAstVariableAccess) expr).getName();
                    expr = new CJAstAugmentedAssignment(mark, name, kind, valexpr);
                    break;
                }
                case CJToken.KW_AND:
                case CJToken.KW_OR: {
                    var isAnd = next().type == CJToken.KW_AND;
                    var right = parseExpressionWithPrecedence(tokenPrecedence + 1);
                    expr = new CJAstLogicalBinop(opMark, isAnd, expr, right);
                    break;
                }
                case CJToken.KW_IS: {
                    var mark = getMark();
                    next();
                    var isNot = consume(CJToken.KW_NOT);
                    var right = parseExpressionWithPrecedence(tokenPrecedence + 1);
                    expr = new CJAstIs(mark, expr, right);
                    if (isNot) {
                        expr = new CJAstLogicalNot(mark, expr);
                    }
                    break;
                }
                case '+':
                case '-':
                case '*':
                case '/':
                case '%':
                case '<':
                case '>':
                case '|':
                case '^':
                case '&':
                case CJToken.LSHIFT:
                case CJToken.RSHIFT:
                case CJToken.RSHIFTU:
                case CJToken.POWER:
                case CJToken.TRUNCDIV:
                case CJToken.EQ:
                case CJToken.NE:
                case CJToken.LE:
                case CJToken.GE:
                case CJToken.KW_IN:
                case CJToken.KW_NOT: {
                    String methodName = null;
                    boolean logicalNot = false;
                    boolean rightAssociative = false;
                    boolean swap = false;
                    var mark = getMark();
                    switch (next().type) {
                        case '+':
                            methodName = "__add";
                            break;
                        case '-':
                            methodName = "__sub";
                            break;
                        case '*':
                            methodName = "__mul";
                            break;
                        case '/':
                            methodName = "__div";
                            break;
                        case '%':
                            methodName = "__rem";
                            break;
                        case '<':
                            methodName = "__lt";
                            break;
                        case '>':
                            methodName = "__gt";
                            break;
                        case '|':
                            methodName = "__or";
                            break;
                        case '^':
                            methodName = "__xor";
                            break;
                        case '&':
                            methodName = "__and";
                            break;
                        case CJToken.LSHIFT:
                            methodName = "__lshift";
                            break;
                        case CJToken.RSHIFT:
                            methodName = "__rshift";
                            break;
                        case CJToken.RSHIFTU:
                            methodName = "__rshiftu";
                            break;
                        case CJToken.POWER:
                            methodName = "__pow";
                            rightAssociative = true;
                            break;
                        case CJToken.TRUNCDIV:
                            methodName = "__truncdiv";
                            break;
                        case CJToken.EQ:
                            methodName = "__eq";
                            break;
                        case CJToken.NE:
                            methodName = "__eq";
                            logicalNot = true;
                            break;
                        case CJToken.LE:
                            methodName = "__le";
                            break;
                        case CJToken.GE:
                            methodName = "__ge";
                            break;
                        case CJToken.KW_IN:
                            methodName = "__contains";
                            swap = true;
                            break;
                        case CJToken.KW_NOT:
                            expect(CJToken.KW_IN);
                            methodName = "__contains";
                            logicalNot = true;
                            swap = true;
                            break;
                    }
                    Assert.that(methodName != null);
                    var rhs = parseExpressionWithPrecedence(rightAssociative ? tokenPrecedence : tokenPrecedence + 1);
                    if (swap) {
                        var tmp = rhs;
                        rhs = expr;
                        expr = tmp;
                    }
                    expr = new CJAstMethodCall(mark, Optional.empty(), methodName, List.of(), List.of(expr, rhs));
                    if (logicalNot) {
                        expr = new CJAstLogicalNot(mark, expr);
                    }
                    break;
                }
                default:
                    throw ekind("expression operator (TODO)");
            }
            tokenPrecedence = getTokenPrecedence(peek().type);
        }
        return expr;
    }

    private static int getTokenPrecedence(int tokenType) {
        // mostly follows Python, except uses Rust style '?'
        switch (tokenType) {
            case '=':
            case CJToken.PLUS_EQ:
            case CJToken.MINUS_EQ:
            case CJToken.STAR_EQ:
            case CJToken.REM_EQ:
                return 20;
            case ':':
                return 30;
            case CJToken.KW_OR:
                return 40;
            case CJToken.KW_AND:
                return 50;
            case '<':
            case '>':
            case CJToken.EQ:
            case CJToken.NE:
            case CJToken.GE:
            case CJToken.LE:
            case CJToken.KW_IS:
            case CJToken.KW_IN:
            case CJToken.KW_NOT:
                return 60;
            case '|':
                return 70;
            case '^':
                return 80;
            case '&':
                return 90;
            case CJToken.LSHIFT:
            case CJToken.RSHIFT:
            case CJToken.RSHIFTU:
                return 100;
            case '+':
            case '-':
                return 110;
            case '*':
            case '/':
            case '%':
            case CJToken.TRUNCDIV:
                return 120;
            case CJToken.POWER:
                return 130;
            case '.':
            case '[':
            case '?':
                return 140;
            default:
                return -1;
        }
    }

    /**
     * Check if the given index into the token list can be the start of a method
     * argument list.
     *
     * Method args always include a '(', but it may optionally be preceeded by a
     * type list ('[' types.. ']')
     */
    private boolean atMethodArgsStart(int i) {
        var firstTokType = tokens.get(i).type;
        if (firstTokType == '(') {
            return true;
        }
        if (firstTokType != '[') {
            return false;
        }
        var secondTokType = tokens.get(i + 1).type;
        // check for either the start of a type (TYPE_ID) or an empty type list (']')
        if (secondTokType != CJToken.TYPE_ID && secondTokType != ']') {
            return false;
        }
        var j = i + 1;
        var depth = 1;
        while (depth > 0) {
            var token = tokens.get(j++);
            switch (token.type) {
                case '[':
                    depth++;
                    break;
                case ']':
                    depth--;
                    break;
                case CJToken.TYPE_ID:
                case '.':
                case ',':
                case '?':
                    break;
                default:
                    // If any other token is encountered, we assume we have a non-type expression.
                    return false;
            }
        }
        return j < this.tokens.size() && tokens.get(j).type == '(';
    }

    private CJAstExpression parseAtomExpression() {
        switch (peek().type) {
            case '{':
                return parseBlock();
            case '(': {
                var mark = getMark();
                if (atLambda()) {
                    return parseLambda();
                } else if (atOffset(')', 1)) {
                    next();
                    next();
                    return new CJAstLiteral(mark, CJIRLiteralKind.Unit, "()");
                } else {
                    next();
                    var inner = parseExpression();
                    if (consume(',')) {
                        var expressions = List.of(inner);
                        while (!consume(')')) {
                            expressions.add(parseExpression());
                            if (!consume(',')) {
                                expect(')');
                                break;
                            }
                        }
                        return new CJAstTupleDisplay(mark, expressions);
                    } else {
                        expect(')');
                        return inner;
                    }
                }
            }
            case '[': {
                var mark = getMark();
                next();
                var expressions = List.<CJAstExpression>of();
                while (!consume(']')) {
                    expressions.add(parseExpression());
                    if (!consume(',')) {
                        expect(']');
                        break;
                    }
                }
                return new CJAstListDisplay(mark, expressions);
            }
            case CJToken.KW_NULL: {
                var mark = getMark();
                next();
                var innerType = Optional.<CJAstTypeExpression>empty();
                if (consume('[')) {
                    innerType = Optional.of(parseTypeExpression());
                    expect(']');
                }
                var inner = Optional.<CJAstExpression>empty();
                if (consume('(')) {
                    inner = Optional.of(parseExpression());
                    expect(')');
                }
                return new CJAstNullWrap(mark, innerType, inner);
            }
            case CJToken.KW_TRUE:
                next();
                return new CJAstLiteral(getMark(), CJIRLiteralKind.Bool, "true");
            case CJToken.KW_FALSE:
                next();
                return new CJAstLiteral(getMark(), CJIRLiteralKind.Bool, "false");
            case CJToken.CHAR:
                return new CJAstLiteral(getMark(), CJIRLiteralKind.Char, next().text);
            case CJToken.INT:
                return new CJAstLiteral(getMark(), CJIRLiteralKind.Int, next().text);
            case CJToken.DOUBLE:
                return new CJAstLiteral(getMark(), CJIRLiteralKind.Double, next().text);
            case CJToken.STRING:
                return new CJAstLiteral(getMark(), CJIRLiteralKind.String, next().text);
            case CJToken.TYPE_ID: {
                var owner = parseTypeExpression();
                if (at('(')) {
                    var mark = getMark();
                    var args = parseArgs();
                    return new CJAstMethodCall(mark, Optional.of(owner), "new", List.of(), args);
                }
                expect('.');
                var mark = getMark();
                var name = parseId();
                if (atMethodArgsStart(i)) {
                    var typeArgs = parseTypeArgs();
                    var args = parseArgs();
                    return new CJAstMethodCall(mark, Optional.of(owner), name, typeArgs, args);
                } else {
                    switch (peek().type) {
                        case '=':
                        case CJToken.PLUS_EQ: {
                            String prefix;
                            switch (peek().type) {
                                case '=':
                                    prefix = "__set_";
                                    break;
                                case CJToken.PLUS_EQ:
                                    prefix = "__augadd_";
                                    break;
                                default:
                                    throw CJError.of("UNRECOGNIZED AUG ASSIGN TOK " + CJToken.typeToString(peek().type),
                                            getMark());
                            }
                            next();
                            var methodName = prefix + name;
                            var args = List.of(parseExpression());
                            return new CJAstMethodCall(mark, Optional.of(owner), methodName, List.of(), args);
                        }
                        default: {
                            var methodName = "__get_" + name;
                            return new CJAstMethodCall(mark, Optional.of(owner), methodName, List.of(), List.of());
                        }
                    }
                }
            }
            case CJToken.ID:
                if (atLambda()) {
                    return parseLambda();
                } else if (atMethodArgsStart(i + 1)) {
                    // Syntactic sugar for Self method call
                    var mark = getMark();
                    var methodName = parseId();
                    var typeArgs = parseTypeArgs();
                    var args = parseArgs();
                    return new CJAstMethodCall(mark, Optional.of(new CJAstTypeExpression(mark, "Self", List.of())),
                            methodName, typeArgs, args);
                } else {
                    return new CJAstVariableAccess(getMark(), parseId());
                }
            case CJToken.KW_IF: {
                var mark = getMark();
                next();
                var mutable = consume(CJToken.KW_VAR);
                var condition = parseExpressionWithPrecedence(ASSIGNMENT_PRECEDENCE + 5);
                if (condition instanceof CJAstNullWrap && consume('=')) {
                    var wrap = (CJAstNullWrap) condition;
                    if (wrap.getInnerType().isPresent()) {
                        throw CJError.of("Inner null wrap type cannot be specified here", mark);
                    }
                    if (wrap.getInner().isEmpty()) {
                        throw CJError.of("if null must specify a target", mark);
                    }
                    var target = expressionToTarget(wrap.getInner().get());
                    var inner = parseExpression();
                    var left = parseBlock();
                    Optional<CJAstExpression> right = consume(CJToken.KW_ELSE)
                            ? at(CJToken.KW_IF) ? Optional.of(parseExpression()) : Optional.of(parseBlock())
                            : Optional.empty();
                    return new CJAstIfNull(mark, mutable, target, inner, left, right);
                } else {
                    if (mutable) {
                        throw CJError.of("Expected null wrapped assignment target", mark);
                    }
                    var left = parseBlock();
                    Optional<CJAstExpression> right = consume(CJToken.KW_ELSE)
                            ? at(CJToken.KW_IF) ? Optional.of(parseExpression()) : Optional.of(parseBlock())
                            : Optional.empty();
                    return new CJAstIf(mark, condition, left, right);
                }
            }
            case CJToken.KW_RETURN: {
                var mark = getMark();
                next();
                var expression = parseExpression();
                return new CJAstReturn(mark, expression);
            }
            case CJToken.KW_WHILE: {
                var mark = getMark();
                next();
                var condition = parseExpression();
                var body = parseBlock();
                return new CJAstWhile(mark, condition, body);
            }
            case CJToken.KW_FOR: {
                var mark = getMark();
                next();
                if (at(';') || at(CJToken.ID) && atOffset('=', 1)) {
                    // c-style for loop -- pure parse-time syntactic sugar
                    Optional<CJAstAssignmentTarget> target;
                    Optional<CJAstExpression> initExpr;
                    if (at(';')) {
                        target = Optional.empty();
                        initExpr = Optional.empty();
                    } else {
                        target = Optional.of(parseTarget());
                        expect('=');
                        initExpr = Optional.of(parseExpression());
                    }
                    expect(';');
                    CJAstExpression condition;
                    if (at(';')) {
                        condition = new CJAstLiteral(mark, CJIRLiteralKind.Bool, "true");
                    } else {
                        condition = parseExpression();
                    }
                    expect(';');
                    Optional<CJAstExpression> increment = at('{') ? Optional.empty()
                            : Optional.of(parseIncrementExpression());
                    var body = parseBlock();

                    List<CJAstExpression> outer = List.of();
                    if (target.isPresent()) {
                        outer.add(new CJAstVariableDeclaration(mark, true, target.get(), Optional.empty(),
                                initExpr.get()));
                    }
                    var inner = List.<CJAstExpression>of(body);
                    if (increment.isPresent()) {
                        inner.add(increment.get());
                    }
                    outer.add(new CJAstWhile(mark, condition, new CJAstBlock(mark, inner)));
                    return new CJAstBlock(mark, outer);
                } else {
                    var target = parseTarget();
                    expect(CJToken.KW_IN);
                    var container = parseExpression();
                    Optional<CJAstExpression> ifCondition = consume(CJToken.KW_IF) ? Optional.of(parseExpression())
                            : Optional.empty();
                    Optional<CJAstExpression> whileCondition = consume(CJToken.KW_WHILE)
                            ? Optional.of(parseExpression())
                            : Optional.empty();
                    var body = parseBlock();
                    return new CJAstFor(mark, target, container, ifCondition, whileCondition, body);
                }
            }
            case CJToken.KW_NOT: {
                var mark = getMark();
                next();
                return new CJAstLogicalNot(mark, parseExpressionWithPrecedence(LOGICAL_NOT_PRECEDENCE));
            }
            case '+':
            case '-':
            case '~': {
                var mark = getMark();
                String methodName;
                switch (next().type) {
                    case '+':
                        methodName = "__pos";
                        break;
                    case '-':
                        methodName = "__neg";
                        break;
                    case '~':
                        methodName = "__invert";
                        break;
                    default:
                        throw CJError.of("FUBAR: UNRECOGNIZED UNARY OP", mark);
                }
                var inner = parseExpressionWithPrecedence(UNARY_OP_PRECEDENCE);
                return new CJAstMethodCall(mark, Optional.empty(), methodName, List.of(), List.of(inner));
            }
            case CJToken.KW_VAL:
            case CJToken.KW_VAR: {
                var mutable = next().type == CJToken.KW_VAR;
                var mark = getMark();
                var target = parseTarget();
                var declaredType = consume(':') ? Optional.of(parseTypeExpression())
                        : Optional.<CJAstTypeExpression>empty();
                expect('=');
                var expression = parseExpression();
                return new CJAstVariableDeclaration(mark, mutable, target, declaredType, expression);
            }
            case CJToken.KW_UNION: {
                var mark = getMark();
                next();
                var target = parseExpression();
                expect('{');
                skipDelimiters();
                var cases = List.<Tuple4<CJMark, String, List<Tuple3<CJMark, Boolean, String>>, CJAstExpression>>of();
                while (!at('}') && !at(CJToken.KW_DEFAULT)) {
                    var caseMark = getMark();
                    expect(CJToken.KW_CASE);
                    var caseName = parseId();
                    var decls = List.<Tuple3<CJMark, Boolean, String>>of();
                    if (consume('(')) {
                        while (!consume(')')) {
                            var mutable = consume(CJToken.KW_VAR);
                            var varMark = getMark();
                            var varName = parseId();
                            decls.add(Tuple3.of(varMark, mutable, varName));
                            if (!consume(',')) {
                                expect(')');
                                break;
                            }
                        }
                    }
                    expect('=');
                    var body = parseExpression();
                    cases.add(Tuple4.of(caseMark, caseName, decls, body));
                    expectDelimiters();
                }
                Optional<CJAstExpression> fallback;
                if (consume(CJToken.KW_DEFAULT)) {
                    expect('=');
                    fallback = Optional.of(parseExpression());
                } else {
                    fallback = Optional.empty();
                }
                expect('}');
                return new CJAstUnion(mark, target, cases, fallback);
            }
            case CJToken.KW_SWITCH: {
                var mark = getMark();
                next();
                var target = parseExpression();
                expect('{');
                skipDelimiters();
                var cases = List.<Pair<List<CJAstExpression>, CJAstExpression>>of();
                while (!at('}') && !at(CJToken.KW_DEFAULT)) {
                    expect(CJToken.KW_CASE);
                    var valexprs = List.of(parseExpressionWithPrecedence(ASSIGNMENT_PRECEDENCE + 5));
                    skipDelimiters();
                    while (consume(CJToken.KW_CASE)) {
                        valexprs.add(parseExpressionWithPrecedence(ASSIGNMENT_PRECEDENCE + 5));
                        skipDelimiters();
                    }
                    expect('=');
                    var body = parseExpression();
                    expectDelimiters();
                    cases.add(Pair.of(valexprs, body));
                }
                var fallback = Optional.<CJAstExpression>empty();
                if (consume(CJToken.KW_DEFAULT)) {
                    expect('=');
                    fallback = Optional.of(parseExpression());
                    expectDelimiters();
                }
                expect('}');
                return new CJAstSwitch(mark, target, cases, fallback);
            }
        }
        throw ekind("expression");
    }

    private boolean atLambda() {
        if (at(CJToken.KW_ASYNC)) {
            return true;
        }
        var start = i;
        if (at(CJToken.ID) && atOffset(CJToken.RIGHT_ARROW, 1)) {
            return true;
        }
        if (!consume('(')) {
            return false;
        }
        while (consume(',') || consume(CJToken.KW_VAR) || consume(CJToken.ID)) {
        }
        var ret = consume(')') && consume(CJToken.RIGHT_ARROW);
        i = start;
        return ret;
    }

    private CJAstLambda parseLambda() {
        var mark = getMark();
        var isAsync = consume(CJToken.KW_ASYNC);
        var parameters = List.<Tuple3<CJMark, Boolean, String>>of();
        if (at(CJToken.ID)) {
            var parameterName = parseId();
            parameters.add(Tuple3.of(mark, false, parameterName));
        } else {
            expect('(');
            while (!consume(')')) {
                var mutable = consume(CJToken.KW_VAR);
                var parameterMark = getMark();
                var parameterName = parseId();
                parameters.add(Tuple3.of(parameterMark, mutable, parameterName));
                if (!consume(',')) {
                    expect(')');
                    break;
                }
            }
        }
        expect(CJToken.RIGHT_ARROW);
        var body = parseExpression();
        return new CJAstLambda(mark, isAsync, parameters, body);
    }

    private List<CJAstExpression> parseArgs() {
        var list = List.<CJAstExpression>of();
        expect('(');
        while (!consume(')')) {
            list.add(parseExpression());
            if (!consume(',')) {
                expect(')');
                break;
            }
        }
        return list;
    }

    private CJAstBlock parseBlock() {
        var mark = getMark();
        expect('{');
        skipDelimiters();
        var exprs = List.<CJAstExpression>of();
        while (!consume('}')) {
            exprs.add(parseBlockElementExpression());
            expectDelimiters();
        }
        return new CJAstBlock(mark, exprs);
    }

    private CJAstAssignmentTarget expressionToTarget(CJAstExpression expression) {
        if (expression instanceof CJAstVariableAccess) {
            var e = (CJAstVariableAccess) expression;
            return new CJAstNameAssignmentTarget(e.getMark(), e.getName());
        } else if (expression instanceof CJAstTupleDisplay) {
            var subtargets = ((CJAstTupleDisplay) expression).getExpressions().map(s -> expressionToTarget(s));
            return new CJAstTupleAssignmentTarget(expression.getMark(), subtargets);
        } else {
            throw CJError.of("Expected assignment target but got " + expression.getClass().getName(),
                    expression.getMark());
        }
    }

    private CJAstAssignmentTarget parseTarget() {
        return expressionToTarget(parseAtomExpression());
    }
}
