package compiler.solver

import compiler.solver.CJExprSolver
import cj.Deque
import compiler.CJModifier
import compiler.solver.CJAnnotationMixin
import compiler.solver.CJMethodSynthesizerMixin
import compiler.solver.CJSolverBaseMixin
import compiler.solver.CJInferTypeMixin
import cjx.parser.Mark
import compiler.solver.CJItemFinderMixin
import compiler.solver.CJTypeSolverMixin
import cjx.parser.MError
import compiler.solver.CJData
import compiler.solver.CJScope
import compiler.CJAst
import compiler.CJIR
import compiler.CJIR.Type
import compiler.CJIR.SelfType

class CJSolver:
        CJSolverBaseMixin,
        CJMethodSynthesizerMixin,
        CJTypeSolverMixin,
        CJItemFinderMixin,
        CJInferTypeMixin,
        CJAnnotationMixin {

    # various todo levels
    private static val tlTypeParamTraits = 0
    private static val tlTraitDecl = 1
    private static val tlField = 2
    private static val tlCase = 2 # same as tlField
    private static val tlMethod = 3
    private static val tlMalloc = 3 # same as tlMethod
    private static val tlMethodBody = 4
    private static val tlFieldInit = 4 # same as tlMethodBody

    class Task: Repr {
        val name: String
        val detail: String
        val f: Fn[Unit]
        def repr(self): String = "Task(" + name + "," + detail + ")"
    }

    val sourceRoots: List[String]
    val todos: List[Deque[Task]] = []
    val itemMap: Map[String, CJIR.ItemDef] = Map([])
    var verbose = false

    var _noreturnType: Type? = null
    var _unitType: Type? = null
    var _boolType: Type? = null
    var _charType: Type? = null
    var _intType: Type? = null
    var _doubleType: Type? = null
    var _stringType: Type? = null
    var _bigintType: Type? = null

    def todo(self, level: Int, name: String, detail: String, f: Fn[Unit]) {
        while level >= todos.size() {
            todos.add(Deque([]))
        }
        todos[level].add(Task(name, detail, f))
    }

    def solve(self) {
        var repeat = true
        while repeat {
            var i = 0
            while i < todos.size() and not todos[i] {
                i++
            }
            if i < todos.size() {
                val task = todos[i].popleft()
                if verbose {
                    IO.println(task)
                }
                task.f.call()
            } else {
                repeat = false
            }
        }
    }

    def __get_noreturnType(self): Type {
        if val type = _noreturnType { type } else {
            val type = Type.reified(getReifiedType(Default(), "cj.NoReturn", []))
            _noreturnType = null(type)
            type
        }
    }

    def __get_unitType(self): Type {
        if val type = _unitType { type } else {
            val type = Type.reified(getReifiedType(Default(), "cj.Unit", []))
            _unitType = null(type)
            type
        }
    }

    def __get_boolType(self): Type {
        if val type = _boolType { type } else {
            val type = Type.reified(getReifiedType(Default(), "cj.Bool", []))
            _boolType = null(type)
            type
        }
    }

    def __get_charType(self): Type {
        if val type = _charType { type } else {
            val type = Type.reified(getReifiedType(Default(), "cj.Char", []))
            _charType = null(type)
            type
        }
    }

    def __get_intType(self): Type {
        if val type = _intType { type } else {
            val type = Type.reified(getReifiedType(Default(), "cj.Int", []))
            _intType = null(type)
            type
        }
    }

    def __get_doubleType(self): Type {
        if val type = _doubleType { type } else {
            val type = Type.reified(getReifiedType(Default(), "cj.Double", []))
            _doubleType = null(type)
            type
        }
    }

    def __get_stringType(self): Type {
        if val type = _stringType { type } else {
            val type = Type.reified(getReifiedType(Default(), "cj.String", []))
            _stringType = null(type)
            type
        }
    }

    def __get_bigintType(self): Type {
        if val type = _bigintType { type } else {
            val type = Type.reified(getReifiedType(Default(), "cj.String", []))
            _bigintType = null(type)
            type
        }
    }

    def getNullableType(self, mark: Mark, inner: Type): Type {
        Type.reified(getReifiedType(mark, "cj.Nullable", [inner]))
    }

    def addFile(self, file: CJAst.File) {
        val fileScope = CJScope.newFileScope()
        val packageName = file.packageName
        for import_ in file.imports {
            fileScope.set(
                import_.mark,
                import_.alias,
                CJData.fullName(import_.fullName))
        }
        val fullName = packageName + "." + file.item.shortName
        addItem(fileScope, fullName, file.item)
    }

    def getItemDefOrNull(self, fullName: String): CJIR.ItemDef? {
        if val item = itemMap.getOrNull(fullName) {
            null(item)
        } else {
            if val astFile = parseFileForItem(fullName) {
                addFile(astFile)
                if val item = itemMap.getOrNull(fullName) {
                    null(item)
                } else { null }
            } else { null }
        }
    }

    private def addItem(self, outerScope: CJScope, fullName: String, item: CJAst.Item) {
        annotateItem(item, item.annotations)
        outerScope.set(item.mark, item.shortName, CJData.fullName(fullName))
        val itemScope = CJScope(outerScope)
        when item.kind {
            case class_ {
                synthesizeNew(item)
                val iritem = CJIR.ClassDef(item.mark, item.comment, item.modifiers, fullName)
                itemMap[fullName] = CJIR.ItemDef.class_(iritem)
                handleItemTypeParams(itemScope, item, iritem)
                addSelfToTypeScope(itemScope, iritem)
                handleItemTraits(itemScope, item, iritem)
                handleClassFields(itemScope, item, iritem)
                handleItemMethods(itemScope, item, iritem)
                if not iritem.native_ {
                    createClassMallocMethod(itemScope, iritem)
                }
                CJIR.ItemDef.class_(iritem)
            }
            case union_ {
                val iritem = CJIR.UnionDef(item.mark, item.comment, item.modifiers, fullName)
                itemMap[fullName] = CJIR.ItemDef.union_(iritem)
                handleItemTypeParams(itemScope, item, iritem)
                addSelfToTypeScope(itemScope, iritem)
                handleItemTraits(itemScope, item, iritem)
                handleUnionCases(itemScope, item, iritem)
                handleItemMethods(itemScope, item, iritem)
            }
            case trait_ = {
                val iritem = CJIR.TraitDef(item.mark, item.comment, item.modifiers, fullName)
                itemMap[fullName] = CJIR.ItemDef.trait_(iritem)
                handleItemTypeParams(itemScope, item, iritem)
                addSelfToTraitScope(itemScope, iritem)
                handleItemTraits(itemScope, item, iritem)
                handleItemMethods(itemScope, item, iritem)
            }
        }
        for member in item.members {
            when member {
                case item(subitem) = addItem(
                    itemScope, fullName + "." + subitem.shortName, subitem)
                else = ()
            }
        }
    }

    private def addSelfToTypeScope[I: CJIR.ClassOrUnionDef](
            self, itemScope: CJScope, item: I) {
        val mark = item.mark
        val args = item.typeParameters.map(tp -> when itemScope.get(mark, tp.name) {
            case type(t) = t
            else = throw MError("Expected " + tp.name + " to be a type", [mark])
        })
        val selfType = Type.reified(getReifiedType(mark, item.name, args))
        itemScope.set(mark, "Self", CJData.type(selfType))
    }

    private def addSelfToTraitScope(self, itemScope: CJScope, item: CJIR.TraitDef) {
        val mark = item.mark
        val args = item.typeParameters.map(tp -> when itemScope.get(mark, tp.name) {
            case type(t) = t
            else = throw MError("Expected " + tp.name + " to be a type", [mark])
        })
        val selfType = Type.self_(SelfType(getReifiedTrait(mark, item.name, args)))
        itemScope.set(mark, "Self", CJData.type(selfType))
    }

    private def handleItemTypeParams[I: CJIR.ItemDef](
            self, scope: CJScope, astItem: CJAst.Item, item: I) {
        for astTypeParam in astItem.typeParameters {
            val typeParam = CJIR.TypeParameter(astTypeParam.mark, true, astTypeParam.name)
            scope.set(typeParam.mark, typeParam.name, CJData.type(Type.variable(CJIR.TypeVar(typeParam))))
            item.addTypeParameter(typeParam)
            todo(tlTypeParamTraits, "typeParamTrait", item.name + " " + typeParam.name, () -> {
                for astTrait in astTypeParam.traits {
                    typeParam.addTrait(solveTrait(scope, astTrait))
                }
            })
        }
    }

    private def handleItemTraits[I: CJIR.ItemDef](
            self, scope: CJScope, astItem: CJAst.Item, item: I) {
        for astTraitDecl in astItem.traitDeclarations {
            todo(tlTraitDecl, "traitdecl", item.name + ":" + astTraitDecl.trait_.name, () -> {
                val trait_ = solveTrait(scope, astTraitDecl.trait_)
                val conds = astTraitDecl.conditions.map(c -> solveTypeCondition(scope, c))
                item.addTraitDeclaration(CJIR.TraitDeclaration(
                    astTraitDecl.mark, trait_, conds))
            })
        }
    }

    private def handleItemMethods[I: CJIR.ItemDef](
            self, scope: CJScope, astItem: CJAst.Item, item: I) {
        for member in astItem.members {
            when member {
                case method(astMethod) = todo(
                    tlMethod,
                    "method",
                    item.name + "." + astMethod.name,
                    () -> handleItemMethod(scope, item, astMethod))
                else = ()
            }
        }
    }

    private def handleItemMethod[I: CJIR.ItemDef](
            self, itemScope: CJScope, item: I, astMethod: CJAst.Method) {
        val methodScope = CJScope(itemScope)

        # update type variables with the conditions of the method
        val conditions = List[CJIR.TypeCondition].empty()
        for astCondition in astMethod.conditions {
            val condition = solveTypeCondition(itemScope, astCondition)
            val itemTypeVar = when itemScope.get(astCondition.mark, condition.variableName) {
                case type(type) = when type {
                    case variable(tv) = tv
                    else = throw MError("Expected type variable", [astCondition.mark])
                }
                else = throw MError("Expected type variable", [astCondition.mark])
            }
            val newTypeVar = CJIR.TypeVar(itemTypeVar.decl)
            newTypeVar.additionalTraits.addAll(itemTypeVar.additionalTraits)
            newTypeVar.additionalTraits.addAll(condition.traits)
            methodScope.set(
                astCondition.mark, newTypeVar.name, CJData.type(Type.variable(newTypeVar)))
        }

        # method level type parameters
        val typeParameters = List[CJIR.TypeParameter].empty()
        for astTypeParam in astMethod.typeParameters {
            val typeParam = CJIR.TypeParameter(
                astTypeParam.mark,
                false,
                astTypeParam.name)
            if typeParam.name in itemScope {
                throw MError(
                    "Method level type parameters may not shadow another type", [typeParam.mark])
            }
            for astTrait in astTypeParam.traits {
                typeParam.addTrait(solveTrait(methodScope, astTrait))
            }
            typeParameters.add(typeParam)
            methodScope.set(
                typeParam.mark,
                typeParam.name,
                CJData.type(Type.variable(CJIR.TypeVar(typeParam))))
        }

        # parameters
        val parameters = List[CJIR.Local].empty()
        for astParam in astMethod.parameters {
            val paramType = solveType(methodScope, astParam.type.get())
            val param = CJIR.Local(astParam.mark, astParam.mutable, astParam.name, paramType)
            parameters.add(param)
            methodScope.set(param.mark, param.name, CJData.local(param))
        }

        # return type
        val returnType = if val rt = astMethod.returnType { solveType(methodScope, rt) } else {
            unitType
        }

        val method = CJIR.Method(
            astMethod.mark,
            astMethod.comment,
            astMethod.modifiers,
            conditions,
            astMethod.name,
            typeParameters,
            parameters,
            returnType,
            item.native_ or astMethod.body.isPresent())
        annotateMethod(method, astMethod.annotations)
        item.addMethod(method)
        if val astBody = astMethod.body {
            todo(tlMethodBody, "methodBody", item.name + "." + method.name, () -> {
                val esolver = CJExprSolver(self, methodScope, null(returnType))
                method.body = null(esolver.solveExprEx(astBody, null(returnType)))
            })
        }
    }

    private def createClassMallocMethod(self, scope: CJScope, cls: CJIR.ClassDef) {
        todo(tlMalloc, "malloc", cls.name, () -> {
            val parameters = List[CJIR.Local].empty()
            for field in cls.fields {
                if not field.static_ and field.init.isEmpty() and not field.lateinit {
                    parameters.add(CJIR.Local(
                        field.mark,
                        false,
                        field.name,
                        field.type))
                }
            }
            val method = CJIR.Method(
                cls.mark,
                null,
                [CJModifier.synthetic],
                [],
                "__malloc",
                [],
                parameters,
                solveTypeEx(scope, cls.mark, "Self", []),
                true)
            cls.addMethod(method)
        })
    }

    private def handleClassFields(self, scope: CJScope, astItem: CJAst.Item, cls: CJIR.ClassDef) {
        todo(tlField, "fields", cls.name, () -> {
            for member in astItem.members {
                when member {
                    case field(astField) = handleClassField(scope, astField, cls)
                    else = ()
                }
            }
        })
    }

    private def handleClassField(self, scope: CJScope, astField: CJAst.Field, cls: CJIR.ClassDef) {
        val fieldType = if val te = astField.type {
            solveType(scope, te)
        } else if val init = astField.init {
            inferTypeOfAst(scope, init)
        } else {
            throw MError("Could not infer type of field", [astField.mark])
        }

        val field = CJIR.Field(
            astField.mark,
            astField.comment,
            astField.modifiers,
            astField.mutable,
            astField.name,
            fieldType)
        annotateField(field, astField.annotations)
        cls.addField(field)

        if val astInit = astField.init {
            todo(tlFieldInit, "fieldinit", cls.name + "." + field.name, () -> {
                val esolver = CJExprSolver(self, scope, null)
                val init = esolver.solveExprEx(astInit, null(field.type))
                field.init = null(init)
            })
        }

        val selfparams: List[CJIR.Local] = if field.static_ { [] } else {
            [CJIR.Local(
                field.mark,
                false,
                "self",
                solveTypeEx(scope, field.mark, "Self", []))]
        }

        val getterMethod = CJIR.Method(
            field.mark,
            field.comment,
            [CJModifier.synthetic],
            [],
            "__get_" + field.name,
            [],
            selfparams,
            fieldType,
            true)
        cls.addMethod(getterMethod)

        if field.mutable {
            val setterMethod = CJIR.Method(
                field.mark,
                field.comment,
                [CJModifier.synthetic],
                [],
                "__set_" + field.name,
                [],
                selfparams + [CJIR.Local(
                    field.mark,
                    false,
                    "value",
                    fieldType)],
                unitType,
                true)
        }
    }

    private def handleUnionCases(self, scope: CJScope, astItem: CJAst.Item, uni: CJIR.UnionDef) {
        todo(tlCase, "cases", uni.name, () -> {
            for member in astItem.members {
                when member {
                    case case_(astCase) = handleUnionCase(scope, astCase, uni)
                    else = ()
                }
            }
        })
    }

    private def handleUnionCase(self, scope: CJScope, astCase: CJAst.Case, uni: CJIR.UnionDef) {
        val types = astCase.types.map(t -> solveType(scope, t))
        val case_ = CJIR.Case(
            astCase.mark,
            astCase.comment,
            astCase.modifiers,
            astCase.name,
            types)
        uni.cases.add(case_)

        val params = List[CJIR.Local].empty()
        for i = 0; i < types.size(); i++ {
            params.add(CJIR.Local(astCase.types[i].mark, false, "a" + i, types[i]))
        }

        val method = CJIR.Method(
            case_.mark,
            case_.comment,
            [CJModifier.synthetic],
            [], # conditions
            case_.name,
            [], # type parameters
            params,
            solveTypeEx(scope, astCase.mark, "Self", []),
            true)
        uni.addMethod(method)

        if not params {
            uni.addMethod(CJIR.Method(
                case_.mark,
                case_.comment,
                [CJModifier.synthetic],
                [], # conditions
                "__get_" + case_.name,
                [], # type parameters
                [], # parameters
                solveTypeEx(scope, astCase.mark, "Self", []),
                true))
        }
    }
}
