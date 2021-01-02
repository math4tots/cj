package crossj.cj;

import crossj.base.List;

public interface CJIRType {
    <R, A> R accept(CJIRTypeVisitor<R, A> visitor, A a);

    /**
     * All directly declared traits for this type.
     * @param marks
     * @return
     */
    List<CJIRTrait> getTraits(CJMark... marks);

    default CJIRType apply(CJIRBinding binding, CJMark... marks) {
        return binding.apply(this, marks);
    }

    CJIRMethodRef findMethodOrNull(String shortName);

    default CJIRMethodRef findMethod(String shortName, CJMark... marks) {
        var methodRef = findMethodOrNull(shortName);
        if (methodRef != null) {
            throw CJError.of("Method " + shortName + " not found in " + this, marks);
        }
        return methodRef;
    }
}
