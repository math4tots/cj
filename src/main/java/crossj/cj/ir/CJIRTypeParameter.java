package crossj.cj.ir;

import crossj.base.List;
import crossj.cj.CJAnnotationProcessor;
import crossj.cj.ast.CJAstTypeParameter;
import crossj.cj.ir.meta.CJIRTrait;

public final class CJIRTypeParameter extends CJIRNode<CJAstTypeParameter> {
    private final CJAnnotationProcessor annotation;
    private final List<CJIRTrait> traits = List.of();

    public CJIRTypeParameter(CJAstTypeParameter ast) {
        super(ast);
        this.annotation = CJAnnotationProcessor.processTypeParameter(ast);
    }

    public CJAnnotationProcessor getAnnotation() {
        return annotation;
    }

    public boolean isGeneric() {
        return annotation.isGeneric();
    }

    public String getName() {
        return ast.getName();
    }

    public List<CJIRTrait> getTraits() {
        return traits;
    }

    public boolean isItemLevel() {
        return ast.isItemLevel();
    }

    public boolean isMethodLevel() {
        return ast.isMethodLevel();
    }
}
