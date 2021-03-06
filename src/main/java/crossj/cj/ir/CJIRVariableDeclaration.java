package crossj.cj.ir;

import crossj.cj.ast.CJAstExpression;
import crossj.cj.ir.meta.CJIRType;

public final class CJIRVariableDeclaration extends CJIRExpression {
    private final boolean mutable;
    private final CJIRAssignmentTarget target;
    private final CJIRExpression expression;

    public CJIRVariableDeclaration(CJAstExpression ast, CJIRType type, boolean mutable, CJIRAssignmentTarget target,
            CJIRExpression expression) {
        super(ast, type);
        this.mutable = mutable;
        this.target = target;
        this.expression = expression;
    }

    public boolean isMutable() {
        return mutable;
    }

    public CJIRAssignmentTarget getTarget() {
        return target;
    }

    public CJIRExpression getExpression() {
        return expression;
    }

    @Override
    public <R, A> R accept(CJIRExpressionVisitor<R, A> visitor, A a) {
        return visitor.visitVariableDeclaration(this, a);
    }
}
