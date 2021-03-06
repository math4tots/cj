package cjx.jvm.main

import cj.Endian
import cj.Math
import cj.BigInt
import cj.Argv
import cj.FS
import cj.DynamicBuffer

## Generate a sample JVM class file.
## References:
##   - https://docs.oracle.com/javase/specs/jvms/se7/html/jvms-4.html
##   - https://en.wikipedia.org/wiki/Java_class_file
class OldSample {

    ## Constant pool tags
    static val cUtf8 = 1
    static val cInteger = 3
    static val cFloat = 4
    static val cLong = 5
    static val cDouble = 6
    static val cClassref = 7
    static val cString = 8
    static val cFieldref = 9
    static val cMethodref = 10
    static val cInterfaceMethodref = 11
    static val cNameAndType = 12

    ## Access flags
    static val cACC_PUBLIC = 0x0001
    static val cACC_PRIVATE = 0x0002
    static val cACC_PROTECTED = 0x0004
    static val cACC_STATIC = 0x0008
    static val cACC_FINAL = 0x0010
    static val cACC_SUPER = 0x0020 # treat superclass methods specially w/invokespecial
    static val cACC_INTERFACE = 0x0200 # interface, not a class
    static val cACC_ABSTRACT = 0x0400
    static val cACC_SYNTHETIC = 0x1000 # synthetic; not present in the source code
    static val cACC_ANNOTATION = 0x2000 # annotation type
    static val cACC_ENUM = 0x4000

    def main() {
        val path = Argv()[0]
        val fullClassName = Argv()[1]

        Assert.withMessage("." not in fullClassName, "Use '/' instead of '.' in class names")

        val ctx = Context()
        val thisClass = ctx.classref(fullClassName)
        val superClass = ctx.classref("java/lang/Object")

        {
            val code = ctx.code()
            code.maxStack = 5
            code.maxLocals = 1
            code.getstatic("java/lang/System", "out", "Ljava/io/PrintStream;")
            code.ldstr("Hello world!")
            code.invokevirtual("java/io/PrintStream", "println", "(Ljava/lang/String;)V")
            code.vreturn()
            val mainMethod = ctx.method(
                cACC_PUBLIC | cACC_STATIC,
                "main",
                "([Ljava/lang/String;)V")
            mainMethod.add(code)
        }

        val b = DynamicBuffer.empty()
        b.endian = Endian.little
        b.addUint32(0xCAFEBABE) # magic
        b.addUint16(0x00) # minor version
        b.addUint16(0x33) # major version (Java SE 7)
        ctx.cp.emit(b) # constantPoolCount and constantPool[]
        b.addUint16(cACC_PUBLIC | cACC_SUPER) # access flags
        b.addUint16(thisClass)
        b.addUint16(superClass)
        b.addUint16(0) # interfacesCount (none for now)
        b.addUint16(0) # fieldsCount (none for now)
        ctx.emitMethods(b)
        b.addUint16(0) # attribuesCount (none for now)
        FS.writeFileBytes(path, b)
    }

    class Context {
        val cp: ConstantPool = Default()
        val methods: List[MethodInfo] = []

        def classref(self, fullClassName: String): Int = cp.classref(fullClassName)

        def method(self, accessFlags: Int, name: String, descriptor: String): MethodInfo = {
            val method = MethodInfo(accessFlags, cp.utf8(name), cp.utf8(descriptor))
            methods.add(method)
            method
        }

        def code(self): Code = Code(self)

        def emitMethods(self, out: DynamicBuffer) {
            out.addUint16(methods.size())
            for method in methods {
                method.emit(out)
            }
        }
    }

    @derive(default)
    class ConstantPool {
        val infos: List[CpInfo] = []
        val classrefMap: Map[String, Int] = Map([])
        val utf8Map: Map[String, Int] = Map([])
        val stringMap: Map[String, Int] = Map([])
        val nameAndTypeMap: Map[Tuple[String, String], Int] = Map([])
        val methodrefMap: Map[Tuple[String, String, String], Int] = Map([])
        val fieldrefMap: Map[Tuple[String, String, String], Int] = Map([])
        val interfaceMethodrefMap: Map[Tuple[String, String, String], Int] = Map([])

        ## Gets the constantPoolCount value as required by the class file spec
        def count(self): Int = {
            1 + infos.map(i -> when i {
                case long(i) = 2
                case double(f) = 2
                else = 1
            }).fold(0, (a, b) -> a + b)
        }

        def emit(self, out: DynamicBuffer) {
            out.addUint16(count()) # constantPoolCount
            for info in infos {
                info.emit(out)
            }
        }

        private def add(self, info: CpInfo): Int {
            val id = infos.size() + 1
            infos.add(info)
            id
        }

        def utf8(self, data: String): Int = {
            if data not in utf8Map {
                utf8Map[data] = add(CpInfo.utf8(data))
            }
            utf8Map[data]
        }

        def classref(self, fullName: String): Int = {
            if fullName not in classrefMap {
                classrefMap[fullName] = add(CpInfo.classref(utf8(fullName)))
            }
            classrefMap[fullName]
        }

        def string(self, data: String): Int = {
            if data not in stringMap {
                val utf8index = utf8(data)
                stringMap[data] = add(CpInfo.string(utf8index))
            }
            stringMap[data]
        }

        def nameAndType(self, name: String, descriptor: String): Int = {
            val key = (name, descriptor)
            if key not in nameAndTypeMap {
                nameAndTypeMap[key] = add(CpInfo.nameAndType(utf8(name), utf8(descriptor)))
            }
            nameAndTypeMap[key]
        }

        def methodref(self, className: String, name: String, descriptor: String): Int = {
            val key = (className, name, descriptor)
            if key not in methodrefMap {
                methodrefMap[key] = add(CpInfo.methodref(
                    classref(className), nameAndType(name, descriptor)))
            }
            methodrefMap[key]
        }

        def fieldref(self, className: String, name: String, descriptor: String): Int = {
            val key = (className, name, descriptor)
            if key not in fieldrefMap {
                fieldrefMap[key] = add(CpInfo.fieldref(
                    classref(className), nameAndType(name, descriptor)))
            }
            fieldrefMap[key]
        }

        def interfaceMethodref(self, className: String, name: String, descriptor: String): Int = {
            val key = (className, name, descriptor)
            if key not in interfaceMethodrefMap {
                interfaceMethodrefMap[key] = add(CpInfo.interfaceMethodref(
                    classref(className), nameAndType(name, descriptor)))
            }
            interfaceMethodrefMap[key]
        }
    }

    union CpInfo {
        ## Raw utf-8 string data
        case utf8(String)

        ## 32-bit integer constant
        case integer(Int)

        ## 32-bit float constant (IEEE 754)
        case float(Double)

        ## 64-bit integer constant
        case long(BigInt)

        ## 64-bit float constant (IEEE 754)
        case double(Double)

        ## (name-index)
        case classref(Int)

        ## (utf8-index)
        case string(Int)

        ## (class-index, name-and-type-index)
        case fieldref(Int, Int)

        ## (class-index, name-and-type-index)
        case methodref(Int, Int)

        ## (class-index, name-and-type-index)
        case interfaceMethodref(Int, Int)

        ## (name-index, descriptor-index (index to utf8 entry))
        case nameAndType(Int, Int)

        def __get_tag(self): Int = when self {
            case utf8(data) = OldSample.cUtf8
            case integer(i) = OldSample.cInteger
            case float(f) = OldSample.cFloat
            case long(i) = OldSample.cLong
            case double(f) = OldSample.cDouble
            case classref(nameIndex) = OldSample.cClassref
            case string(utf8Index) = OldSample.cString
            case fieldref(ci, nti) = OldSample.cFieldref
            case methodref(ci, nti) = OldSample.cMethodref
            case interfaceMethodref(ci, nti) = OldSample.cInterfaceMethodref
            case nameAndType(ni, di) = OldSample.cNameAndType
        }

        def emit(self, out: DynamicBuffer) {
            out.addUint8(tag)
            when self {
                case utf8(string) = {
                    val utf8 = DynamicBuffer.fromUTF8(string)
                    out.addUint16(utf8.size())
                    out.addBuffer(utf8)
                }
                case integer(i) = out.addInt32(i)
                case float(f) = out.addFloat32(f)
                case long(i) = out.addBigInt64(i)
                case double(f) = out.addFloat64(f)
                case classref(nameIndex) = {
                    out.addUint16(nameIndex)
                }
                case string(utf8Index) = {
                    out.addUint16(utf8Index)
                }
                case fieldref(classIndex, nameAndTypeIndex) = {
                    out.addUint16(classIndex)
                    out.addUint16(nameAndTypeIndex)
                }
                case methodref(classIndex, nameAndTypeIndex) = {
                    out.addUint16(classIndex)
                    out.addUint16(nameAndTypeIndex)
                }
                case interfaceMethodref(classIndex, nameAndTypeIndex) = {
                    out.addUint16(classIndex)
                    out.addUint16(nameAndTypeIndex)
                }
                case nameAndType(nameIndex, descriptorIndex) = {
                    out.addUint16(nameIndex)
                    out.addUint16(descriptorIndex)
                }
            }
        }
    }

    class MethodInfo {
        val accessFlags: Int
        val nameIndex: Int
        val descriptorIndex: Int
        val attributes: List[AttributeInfo] = []

        def emit(self, out: DynamicBuffer) {
            out.addUint16(accessFlags)
            out.addUint16(nameIndex)
            out.addUint16(descriptorIndex)
            out.addUint16(attributes.size())
            for attribute in attributes {
                attribute.emit(out)
            }
        }

        def add[C: ToAttribute](self, c: C) {
            self.attributes.add(c.toAttribute())
        }
    }

    trait ToAttribute {
        def toAttribute(self): AttributeInfo
    }

    class AttributeInfo {
        val attributeNameIndex: Int
        val data: AttributeInfoData

        def emit(self, out: DynamicBuffer) {
            out.addUint16(attributeNameIndex)
            val updatePos = out.size()
            out.addUint32(0)
            val startPos = out.size()
            data.emit(out)
            val endPos = out.size()
            out.setUint32(updatePos, endPos - startPos)
        }
    }

    union AttributeInfoData {
        case code(CodeAttribute)
        def emit(self, out: DynamicBuffer) = when self {
            case code(code) = code.emit(out)
        }
    }

    class CodeAttribute {
        val maxStack: Int
        val maxLocals: Int
        val code: DynamicBuffer
        val exceptionTable: List[ExceptionTableEntry] = []
        val attributes: List[AttributeInfo] = []

        def emit(self, out: DynamicBuffer) {
            out.addUint16(maxStack)
            out.addUint16(maxLocals)
            out.addUint32(code.size())
            {
                val start = out.size()
                out.addBuffer(code)
                val end = out.size()
                Assert.equal(code.size(), end - start)
            }
            Assert.equal(exceptionTable.size(), 0) # TODO
            out.addUint16(exceptionTable.size())
            for entry in exceptionTable {
                entry.emit(out)
            }
            Assert.equal(attributes.size(), 0) # TODO
            out.addUint16(attributes.size())
            for attribute in attributes {
                attribute.emit(out)
            }
        }
    }

    class ExceptionTableEntry {
        val startPc: Int
        val endPc: Int
        val handlerPc: Int
        val catchType: Int

        def emit(self, out: DynamicBuffer) {
            throw "TODO"
        }
    }

    class Opcode {
        static val ldc = 0x12
        static val ldc_w = 0x13
        static val ldc2_w = 0x14
        static val getstatic = 0xB2
        static val invokevirtual = 0xB6
    }

    ## Bytecode builder
    class Code : ToAttribute {
        val ctx: Context
        var maxLocals = 0
        var maxStack = 0
        val buffer: DynamicBuffer = {
            val b = DynamicBuffer.empty()
            b.endian = Endian.big
            b
        }

        ## Return void
        def vreturn(self) {
            # return opcode
            buffer.addUint8(0xb1)
        }

        ## Load a constant string onto the stack
        def ldstr(self, string: String) {
            ldc(ctx.cp.string(string))
        }

        ## Load a constant onto the stack given its index in the constant pool
        def ldc(self, index: Int) {
            if index < 128 {
                buffer.addUint8(Opcode.ldc)
                buffer.addUint8(index)
            } else {
                buffer.addUint8(Opcode.ldc_w)
                buffer.addUint16(index)
            }
        }

        def getstatic(self, className: String, fieldName: String, type: String) {
            val index = ctx.cp.fieldref(className, fieldName, type)
            buffer.addUint8(Opcode.getstatic)
            buffer.addUint16(index)
        }

        def invokevirtual(self, className: String, methodName: String, type: String) {
            val index = ctx.cp.methodref(className, methodName, type)
            buffer.addUint8(Opcode.invokevirtual)
            buffer.addUint16(index)
        }

        def toCodeAttribute(self): CodeAttribute = {
            CodeAttribute(maxStack, maxLocals, buffer)
        }

        def toAttribute(self): AttributeInfo = AttributeInfo(
            ctx.cp.utf8("Code"),
            AttributeInfoData.code(toCodeAttribute()))
    }
}
