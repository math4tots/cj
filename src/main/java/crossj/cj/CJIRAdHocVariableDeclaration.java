package crossj.cj;

public final class CJIRAdHocVariableDeclaration implements CJIRLocalVariableDeclaration {
    private final CJMark mark;
    private final boolean mutable;
    private final String name;
    private final CJIRType type;

    CJIRAdHocVariableDeclaration(CJMark mark, boolean mutable, String name, CJIRType type) {
        this.mark = mark;
        this.mutable = mutable;
        this.name = name;
        this.type = type;
    }

    @Override
    public CJMark getMark() {
        return mark;
    }

    @Override
    public boolean isMutable() {
        return mutable;
    }

    @Override
    public String getName() {
        return name;
    }

    @Override
    public CJIRType getVariableType() {
        return type;
    }
}