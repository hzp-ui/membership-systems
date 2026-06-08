package com.membership.security;

import com.membership.common.BusinessException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.stereotype.Component;

/**
 * Store-level access control utility.
 * Extracts storeId from JWT credentials and enforces data isolation.
 */
@Component
public class StoreAccessUtil {

    /**
     * Resolve the storeId filter for the current user.
     * Returns null for super_admin (can see all stores),
     * returns the user's storeId for store_admin.
     */
    public String resolveStoreId(Authentication auth) {
        if (auth == null) return null;
        if (auth.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_SUPER_ADMIN"))) {
            return null; // Can see all
        }
        return (String) auth.getCredentials();
    }

    /**
     * Check if current user can access the target store's data.
     * super_admin passes always; store_admin can only access their own store.
     */
    public void checkStoreAccess(String targetStoreId, Authentication auth) {
        if (auth == null) return;
        if (auth.getAuthorities().stream()
                .anyMatch(a -> a.getAuthority().equals("ROLE_SUPER_ADMIN"))) {
            return;
        }
        String myStoreId = (String) auth.getCredentials();
        if (myStoreId != null && !myStoreId.equals(targetStoreId)) {
            throw new BusinessException(403, "无权访问其他门店数据");
        }
    }
}
