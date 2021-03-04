package crossj.cj.js;

import crossj.base.Map;

public final class CJJSMethodNameRegistry {
    private final Map<String, Integer> bindingToId = Map.of();

    public String getName(String itemName, String methodName, CJJSTypeBinding binding) {
        return getNonGenericName(itemName, methodName) + (binding.isEmpty() ? "" : "$" + getBindingId(binding));
    }

    public String getNonGenericName(String itemName, String methodName) {
        return itemName.replace(".", "$") + "$" + methodName;
    }

    public String nameForReifiedMethod(CJJSReifiedMethod reifiedMethod) {
        return getName(reifiedMethod.getOwner().getItem().getFullName(), reifiedMethod.getMethod().getName(),
                reifiedMethod.getBinding());
    }

    private int getBindingId(CJJSTypeBinding binding) {
        return bindingToId.getOrInsert(binding.toString(), () -> bindingToId.size());
    }
}