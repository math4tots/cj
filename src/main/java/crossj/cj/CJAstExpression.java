package crossj.cj;

public abstract class CJAstExpression extends CJAstNode {
    CJAstExpression(CJMark mark) {
        super(mark);
    }

    abstract public <R, A> R accept(CJAstExpressionVisitor<R, A> visitor, A a);
}
