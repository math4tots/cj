package crossj.cj.run;

public abstract class CJRunModeVisitor<R, A> {
    public abstract R visitMain(CJRunModeMain m, A a);
    public abstract R visitBlob(CJRunModeBlob m, A a);
    public abstract R visitTest(CJRunModeTest m, A a);
    public abstract R visitWWW(CJRunModeWWW m, A a);
    public abstract R visitNW(CJRunModeNW m, A a);
}
