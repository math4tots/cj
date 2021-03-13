package crossj.cj;

import crossj.json.JSON;

public final class CJIRRunModeWWW extends CJIRRunModeWWWBase {
    @Override
    public <R, A> R accept(CJIRRunModeVisitor<R, A> visitor, A a) {
        return visitor.visitWWW(this, a);
    }

    public CJIRRunModeWWW(String appId, String appdir, JSON config) {
        super(appId, appdir, config);
    }
}
