package compiler.solver

import compiler.CJIR

union CJData {
    case fullName(String)
    case type(CJIR.Type)
    case local(CJIR.Local)
}
