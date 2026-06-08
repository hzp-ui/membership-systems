package com.membership.service;

import com.membership.dto.response.DashboardResponse;

public interface DashboardService {
    DashboardResponse getDashboard(String storeId);
}
