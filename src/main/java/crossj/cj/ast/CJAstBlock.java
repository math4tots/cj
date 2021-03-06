package crossj.cj.ast;

import crossj.base.List;
import crossj.cj.CJMark;

public final class CJAstBlock extends CJAstExpression {
    private final List<CJAstExpression> expressions;

    public CJAstBlock(CJMark mark, List<CJAstExpression> expressions) {
        super(mark);
        this.expressions = expressions;
    }

    public List<CJAstExpression> getExpressions() {
        return expressions;
    }

    @Override
    public <R, A> R accept(CJAstExpressionVisitor<R, A> visitor, A a) {
        return visitor.visitBlock(this, a);
    }
}
