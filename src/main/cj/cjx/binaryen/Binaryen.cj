package cjx.binaryen

import cj.Uint8Array

native class Binaryen {
    def __get_none(): Type = js!(Type, "binaryen.none")
    def __get_i32(): Type = js!(Type, "binaryen.i32")
    def __get_i64(): Type = js!(Type, "binaryen.i64")
    def __get_f32(): Type = js!(Type, "binaryen.f32")
    def __get_f64(): Type = js!(Type, "binaryen.f64")
    def __get_auto(): Type = js!(Type, "binaryen.auto")
    def __get_unreachable(): Type = js!(Type, "binaryen.unreachable")

    def getDebugInfo(): Bool = js!(Bool, "binaryen.getDebugInfo()")
    def setDebugInfo(on: Bool) = js!(Unit, "binaryen.setDebugInfo(", on, ")")

    def createType(types: List[Type]): Type = js!(Type, "binaryen.createType(", types, ")")
    def getExpressionType(e: Expression): Type = js!(Type, "binaryen.getExpressionType(", e, ")")

    native class Module {
        def(): Self = js!(Self, "new binaryen.Module()")
        def __get_local(self): ModuleLocal = js!(ModuleLocal, self, ".local")
        def __get_global(self): ModuleGlobal = js!(ModuleGlobal, self, ".global")
        def __get_memory(self): ModuleMemory = js!(ModuleMemory, self, ".memory")
        def __get_i32(self): ModuleI32 = js!(ModuleI32, self, ".i32")
        def __get_i64(self): ModuleI64 = js!(ModuleI64, self, ".i64")
        def return_(self, value: Expression): Expression = js!(
            Expression, self, ".return(", value, ")")
        def returnVoid(self): Expression = js!(Expression, self, ".return()")
        def unreachable(self): Expression = js!(Expression, self, ".unreachable()")
        def nop(self): Expression = js!(Expression, self, ".nop()")
        def drop(self, value: Expression): Expression = js!(
            Expression, self, ".drop(", value, ")")
        def if_(self, cond: Expression, ifTrue: Expression, ifFalse: Expression): Expression = js!(
            Expression, self, ".if(", cond, ",", ifTrue, ",", ifFalse, ")")
        def emitText(self): String = js!(String, self, ".emitText()")
        def emitBinary(self): Uint8Array = js!(Uint8Array, self, ".emitBinary()")
        def emitBinaryWithSourceMap(self, sourceMapUrl: String): BinaryWithSourceMap = js!(
            BinaryWithSourceMap, self, ".emitBinary(", sourceMapUrl, ")")
        def optimize(self) = js!(Unit, self, ".optimize()")
        def validate(self): Bool = js!(Bool, self, ".validate()")
        def dispose(self) = js!(Unit, self, ".dispose()")
        def addGlobal(self, name: String, type: Type, mutable: Bool, value: Expression) = js!(
            Unit, self, ".addGlobal(", name, ",", type, ",", mutable, ",", value, ")")
        def setMemory(self, init: Int, max: Int) = js!(Unit, self, ".setMemory(", init, ",", max, ")")
        def addMemoryExport(self, internalName: String, externalName: String) = js!(
            Unit, self, ".addMemoryExport(", internalName, ",", externalName, ")")
        def addMemoryImport(
            self,
            internalName: String,
            externalModuleName: String,
            externalBaseName: String) = js!(
                Unit,
                self,
                ".addMemoryImport(", internalName,
                ",", externalModuleName,
                ",", externalBaseName, ")")
        def interpret(self) = js!(Unit, self, ".interpret()")
        def setStart(self, start: Function) = js!(
            Unit, self, ".setStart(", start, ")")
        def getFunction(self, name: String): Function = js!(
            Function, self, ".getFunction(", name, ")")
        def addFunction(
                self,
                name: String,
                params: Type,
                results: Type,
                vars: List[Type],
                body: Expression): Function = js!(
                    Function,
                    self, ".addFunction(", name, ",", params, ",", results, ",", vars, ",", body, ")")
        def addFunctionExport(self, internalName: String, externalName: String) = js!(
            Unit, self, ".addFunctionExport(", internalName, ",", externalName, ")")
        def addFunctionImport(
            self,
            internalName: String,
            externalModuleName: String,
            externalBaseName: String,
            params: Type,
            results: Type) = js!(
                Unit,
                self,
                ".addFunctionImport(", internalName,
                ",", externalModuleName,
                ",", externalBaseName,
                ",", params,
                ",", results, ")")
        def addDebugInfoFileName(self, filename: String): Int = js!(
            Int, self, ".addDebugInfoFileName(", filename, ")")
        def setDebugLocation(
            self,
            func: Function,
            expr: Expression,
            fileIndex: Int,
            lineNumber: Int,
            columnNumber: Int) = js!(
                Unit,
                self,
                ".setDebugLocation(", func,
                ",", expr,
                ",", fileIndex,
                ",", lineNumber,
                ",", columnNumber, ")")

        def call(self, name: String, operands: List[Expression], returnType: Type): Expression {
            js!(Expression, self, ".call(", name, ",", operands, ",", returnType, ")")
        }

        def block(self, label: Nullable[String], exprs: List[Expression], type: Type): Expression {
            js!(Expression, self, ".block(", label, ",", exprs, ",", type, ")")
        }
        def loop(self, label: Nullable[String], expr: Expression): Expression {
            js!(Expression, self, ".loop(", label, ",", expr, ")")
        }
        def br(self, label: String): Expression {
            js!(Expression, self, ".br(", label, ")")
        }
        def br_if(self, label: String, cond: Expression): Expression {
            js!(Expression, self, ".br(", label, ",", cond, ")")
        }
        def br_if_with_value(self, label: String, cond: Expression, v: Expression): Expression {
            js!(Expression, self, ".br(", label, ",", cond, ",", v, ")")
        }
    }
    native class BinaryWithSourceMap {
        def __get_binary(self): Uint8Array = js!(Uint8Array, self, ".binary")
        def __get_sourceMap(self): String = js!(String, self, ".sourceMap")
    }
    native class ModuleMemory {
        def size(self): Expression = js!(Expression, self, ".size()")
    }
    native class ModuleLocal {
        def get(self, index: Int, type: Type): Expression = js!(
            Expression, self, ".get(", index, ",", type, ")")
        def set(self, index: Int, value: Expression): Expression = js!(
            Expression, self, ".set(", index, ",", value, ")")
        def tee(self, index: Int, value: Expression, type: Type): Expression = js!(
            Expression, self, ".tee(", index, ",", value, ",", type, ")")
    }
    native class ModuleGlobal {
        def get(self, name: String, type: Type): Expression = js!(
            Expression, self, ".get(", name, ",", type, ")")
        def set(self, name: String, value: Expression): Expression = js!(
            Expression, self, ".set(", name, ",", value, ")")
    }
    trait MemOps {
        def load(self, offset: Int, align: Int, ptr: Expression): Expression = js!(
            Expression, self, ".load(", offset, ",", align, ",", ptr, ")")
        def store(self, offset: Int, align: Int, ptr: Expression, v: Expression): Expression = js!(
            Expression, self, ".store(", offset, ",", align, ",", ptr, ",", v, ")")
    }
    trait IntOps : MemOps {
        def trunc_s_f32(self, value: Expression): Expression = js!(
            Expression, self, ".trunc_s.f32(", value, ")")
        def trunc_s_f64(self, value: Expression): Expression = js!(
            Expression, self, ".trunc_s.f64(", value, ")")
        def trunc_u_f32(self, value: Expression): Expression = js!(
            Expression, self, ".trunc_u.f32(", value, ")")
        def trunc_u_f64(self, value: Expression): Expression = js!(
            Expression, self, ".trunc_u.f64(", value, ")")
        def reinterpret(self, value: Expression): Expression = js!(
            Expression, self, ".reinterpret(", value, ")")
        def load8_s(self, offset: Int, align: Int, ptr: Expression): Expression = js!(
            Expression, self, ".load8_s(", offset, ",", align, ",", ptr, ")")
        def load8_u(self, offset: Int, align: Int, ptr: Expression): Expression = js!(
            Expression, self, ".load8_u(", offset, ",", align, ",", ptr, ")")
        def load16_s(self, offset: Int, align: Int, ptr: Expression): Expression = js!(
            Expression, self, ".load16_s(", offset, ",", align, ",", ptr, ")")
        def load16_u(self, offset: Int, align: Int, ptr: Expression): Expression = js!(
            Expression, self, ".load16_u(", offset, ",", align, ",", ptr, ")")
        def store8(self, offset: Int, align: Int, ptr: Expression, v: Expression): Expression = js!(
            Expression, self, ".store8(", offset, ",", align, ",", ptr, ",", v, ")")
        def store16(self, offset: Int, align: Int, ptr: Expression, v: Expression): Expression = js!(
            Expression, self, ".store16(", offset, ",", align, ",", ptr, ",", v, ")")
        def const(self, value: Int): Expression = js!(
            Expression, self, ".const(", value, ")")
        def clz(self, value: Expression): Expression = js!(
            Expression, self, ".clz(", value, ")")
        def ctz(self, value: Expression): Expression = js!(
            Expression, self, ".ctz(", value, ")")
        def popcnt(self, value: Expression): Expression = js!(
            Expression, self, ".popcnt(", value, ")")
        def eqz(self, value: Expression): Expression = js!(
            Expression, self, ".eqz(", value, ")")
        def add(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".add(", left, ",", right, ")")
        def sub(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".sub(", left, ",", right, ")")
        def mul(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".mul(", left, ",", right, ")")
        def div_s(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".div_s(", left, ",", right, ")")
        def div_u(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".div_u(", left, ",", right, ")")
        def rem_s(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".rem_s(", left, ",", right, ")")
        def rem_u(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".rem_u(", left, ",", right, ")")
        def and_(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".and(", left, ",", right, ")")
        def or_(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".or(", left, ",", right, ")")
        def xor(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".xor(", left, ",", right, ")")
        def shl(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".shl(", left, ",", right, ")")
        def shr_u(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".shr_u(", left, ",", right, ")")
        def shr_s(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".shr_s(", left, ",", right, ")")
        def rotl(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".rotl(", left, ",", right, ")")
        def rotr(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".rotr(", left, ",", right, ")")
        def eq(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".eq(", left, ",", right, ")")
        def ne(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".ne(", left, ",", right, ")")
        def lt_s(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".lt_s(", left, ",", right, ")")
        def lt_u(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".lt_u(", left, ",", right, ")")
        def le_s(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".le_s(", left, ",", right, ")")
        def le_u(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".le_u(", left, ",", right, ")")
        def gt_s(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".gt_s(", left, ",", right, ")")
        def gt_u(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".gt_u(", left, ",", right, ")")
        def ge_s(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".ge_s(", left, ",", right, ")")
        def ge_u(self, left: Expression, right: Expression): Expression = js!(
            Expression, self, ".ge_u(", left, ",", right, ")")
    }
    native class ModuleI32 : IntOps {
        def wrap(self, value: Expression): Expression = js!(
            Expression, self, ".wrap(", value, ")")
    }
    native class ModuleI64 : IntOps {
        def extend_s(self, value: Expression): Expression = js!(
            Expression, self, ".extend_s(", value, ")")
        def extend_u(self, value: Expression): Expression = js!(
            Expression, self, ".extend_u(", value, ")")
    }
    native class Function {}
    native class Expression {}
    native class Type: Eq, Repr {
        def __eq(self, other: Self): Bool = self is other
        def repr(self): String {
            if self == Binaryen.none { return "none" }
            if self == Binaryen.i32 { return "i32" }
            if self == Binaryen.i64 { return "i64" }
            if self == Binaryen.f32 { return "f32" }
            if self == Binaryen.f64 { return "f64" }
            if self == Binaryen.auto { return "auto" }
            if self == Binaryen.unreachable { return "unreachable" }
            "unknown(" + js!(String, "''+", self) + ")"
        }
    }
}
