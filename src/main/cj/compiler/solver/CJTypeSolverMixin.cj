package compiler.solver

import cjx.parser.MError
import cjx.parser.Mark
import compiler.solver.CJScope
import compiler.CJAst
import compiler.CJIR
import compiler.CJIR.Type
import compiler.CJIR.Trait
import compiler.CJIR.ReifiedType

trait CJTypeSolverMixin {

    def getItemDefOrNull(self, fullName: String): CJIR.ItemDef?

    def solveTrait(self, scope: CJScope, expr: CJAst.Trait): Trait {
        val args = expr.args.map(arg -> solveType(scope, arg))
        solveTraitEx(scope, expr.mark, expr.name, args)
    }

    def solveTraitEx(
            self, scope: CJScope, mark: Mark, shortName: String, args: List[Type]): Trait {
        val dotIndex = shortName.indexOf(".")
        val outerShortName = if dotIndex == -1 { shortName } else { shortName[:dotIndex] }
        if val data = scope.getOrNull(outerShortName) {
            when data {
                case fullName(prefix) {
                    val fullName = if dotIndex == -1 { prefix } else {
                        prefix + "." + shortName[dotIndex + 1:]
                    }
                    getReifiedTrait(mark, fullName, args)
                }
                case type(type) = throw MError("Expected trait but got type", [mark])
                else = throw MError("Expected trait", [mark])
            }
        } else {
            throw MError("Name " + outerShortName + " not found in this scope", [mark])
        }
    }

    def solveType(self, scope: CJScope, expr: CJAst.Type): Type {
        val args = expr.args.map(arg -> solveType(scope, arg))
        solveTypeEx(scope, expr.mark, expr.name, args)
    }

    def solveTypeEx(
            self, scope: CJScope, mark: Mark, shortName: String, args: List[Type]): Type {
        val dotIndex = shortName.indexOf(".")
        val outerShortName = if dotIndex == -1 {
            switch shortName {
                case "Fn" = if args { "Fn" + (args.size() - 1) } else { shortName }
                case "Tuple" = "Tuple" + args.size()
                else = shortName
            }
        } else { shortName[:dotIndex] }
        if val data = scope.getOrNull(outerShortName) {
            when data {
                case fullName(prefix) {
                    val fullName = if dotIndex == -1 { prefix } else {
                        prefix + "." + shortName[dotIndex + 1:]
                    }
                    Type.reified(getReifiedType(mark, fullName, args))
                }
                case type(type) {
                    if args {
                        throw MError("Unexpected type args", [mark])
                    }
                    type
                }
                else = throw MError("Expected type", [mark])
            }
        } else { throw MError("Name " + outerShortName + " not found in this scope", [mark]) }
    }

    def getReifiedType(self, mark: Mark, fullName: String, args: List[Type]): ReifiedType {
        if val itemdef = getItemDefOrNull(fullName) {
            if itemdef.typeParameters and not args.size() and not fullName.endsWith("_") {
                return getReifiedType(mark, fullName + "_", args)
            }
            if itemdef.typeParameters.size() != args.size() {
                throw MError(
                    "Expected " + itemdef.typeParameters.size() +
                    " type args but got " + args.size(), [mark])
            }
            val classOrUnionDef = when itemdef {
                case class_(cls) = CJIR.ClassOrUnionDef.class_(cls)
                case union_(uni) = CJIR.ClassOrUnionDef.union_(uni)
                case trait_(..) = return if not fullName.endsWith("_") {
                    getReifiedType(mark, fullName + "_", args)
                } else { throw MError(fullName + " is a trait, not a type", [mark]) }
            }
            val rtype = ReifiedType(classOrUnionDef, args)
            _checkReifiedTypeTypeArgs(mark, rtype)
            rtype
        } else { throw MError("Item " + fullName + " not found", [mark]) }
    }

    def getReifiedTrait(self, mark: Mark, fullName: String, args: List[Type]): Trait {
        if val itemdef = getItemDefOrNull(fullName) {
            if itemdef.typeParameters.size() != args.size() {
                throw MError(
                    "Expected " + itemdef.typeParameters.size() +
                    " type args but got " + args.size(), [mark])
            }
            val traitdef = when itemdef {
                case trait_(t) = t
                else = throw MError(fullName + " is a type, not a trait", [mark])
            }
            val trait_ = Trait(traitdef, args)
            _checkTraitTypeArgs(mark, trait_)
            trait_
        } else { throw MError("Item " + fullName + " not found", [mark]) }
    }

    def _checkTraitTypeArgs(self, mark: Mark, trait_: Trait) {
        _checkTypeArgs(mark, trait_._getBinding(), trait_.defn.typeParameters, trait_.args)
    }

    def _checkReifiedTypeTypeArgs(self, mark: Mark, rtype: ReifiedType) {
        _checkTypeArgs(mark, rtype._getBinding(), rtype.defn.typeParameters, rtype.args)
    }

    def _checkTypeArgs(
            self,
            mark: Mark,
            binding: CJIR.Binding,
            params: List[CJIR.TypeParameter],
            args: List[Type]) {
        if params.size() != args.size() {
            throw MError(
                "Expected " + params.size() + " type args but got " + args.size(), [mark])
        }
        for i = 0; i < args.size(); i++ {
            val param = params[i]
            val arg = args[i]
            for originalTrait in param.traits {
                val trait_ = originalTrait.applyBinding(mark, binding)
                if not arg.implementsTrait(mark, trait_) {
                    throw MError("" + arg + " does not implement " + trait_, [mark, param.mark])
                }
            }
        }
    }

    def solveTypeCondition(self, scope: CJScope, astCond: CJAst.TypeCondition): CJIR.TypeCondition {
        val traits = astCond.traits.map(t -> solveTrait(scope, t))
        CJIR.TypeCondition(astCond.mark, astCond.variableName, traits)
    }
}
