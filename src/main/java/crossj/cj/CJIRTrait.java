package crossj.cj;

import crossj.base.List;

public final class CJIRTrait extends CJIRTraitOrClassType {
    CJIRTrait(CJIRItem item, List<CJIRType> args) {
        super(item, args);
    }

    public CJIRTrait apply(CJIRBinding binding, CJMark... marks) {
        return new CJIRTrait(getItem(), getArgs().map(arg -> binding.apply(arg, marks)));
    }

    @Override
    public boolean equals(Object obj) {
        if (!(obj instanceof CJIRTrait)) {
            return false;
        }
        var other = (CJIRTrait) obj;
        return getItem() == other.getItem() && getArgs().equals(other.getArgs());
    }

    CJIRTrait getImplementingTraitByItemOrNull(CJIRItem item) {
        if (getItem() == item) {
            return this;
        }
        for (var subtrait : getTraits()) {
            var ret = subtrait.getImplementingTraitByItemOrNull(item);
            if (ret != null) {
                return ret;
            }
        }
        return null;
    }

    boolean extendsTrait(CJIRTrait trait) {
        if (this.equals(trait)) {
            return true;
        }
        for (var subtrait : this.getTraits()) {
            if (subtrait.extendsTrait(trait)) {
                return true;
            }
        }
        return false;
    }
}
