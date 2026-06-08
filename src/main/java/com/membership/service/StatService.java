package com.membership.service;

import java.util.List;
import java.util.Map;

public interface StatService {

    Map<String, Object> financeSummary(String storeId, String startDate, String endDate);

    List<Map<String, Object>> dailyStatements(String storeId, String startDate, String endDate);

    List<Map<String, Object>> revenueStats(String storeId, int days);

    List<Map<String, Object>> memberGrowthStats(String storeId, int days);

    List<Map<String, Object>> hotServicesStats(String storeId, int limit);
}
