package com.membership.service.impl;

import com.membership.mapper.ConsumptionRecordMapper;
import com.membership.mapper.MemberMapper;
import com.membership.mapper.RechargeRecordMapper;
import com.membership.service.StatService;
import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.*;

@Service
@RequiredArgsConstructor
public class StatServiceImpl implements StatService {

    private final JdbcTemplate jdbc;

    @Override
    public Map<String, Object> financeSummary(String storeId, String startDate, String endDate) {
        String storeFilter = storeId != null ? " AND store_id = ?" : "";
        String dateFilter = "";
        List<Object> params = new ArrayList<>();

        if (startDate != null && endDate != null) {
            dateFilter = " AND created_at BETWEEN ? AND ?";
            params.add(startDate + " 00:00:00");
            params.add(endDate + " 23:59:59");
        }

        // Consumption summary
        String consumeSql = "SELECT COALESCE(SUM(amount), 0) AS total_consume, " +
                "COALESCE(SUM(original_price), 0) AS total_original, " +
                "COUNT(*) AS consume_count FROM consumption_records WHERE 1=1" +
                storeFilter + dateFilter;
        List<Object> consumeParams = new ArrayList<>();
        if (storeId != null) consumeParams.add(storeId);
        consumeParams.addAll(params);
        Map<String, Object> consume = jdbc.queryForMap(consumeSql, consumeParams.toArray());

        // Recharge summary
        String rechargeSql = "SELECT COALESCE(SUM(amount), 0) AS total_recharge, " +
                "COALESCE(SUM(bonus), 0) AS total_bonus, " +
                "COUNT(*) AS recharge_count FROM recharge_records WHERE 1=1" +
                storeFilter + dateFilter;
        List<Object> rechargeParams = new ArrayList<>();
        if (storeId != null) rechargeParams.add(storeId);
        rechargeParams.addAll(params);
        Map<String, Object> recharge = jdbc.queryForMap(rechargeSql, rechargeParams.toArray());

        Map<String, Object> result = new HashMap<>();
        result.putAll(consume);
        result.putAll(recharge);
        return result;
    }

    @Override
    public List<Map<String, Object>> dailyStatements(String storeId, String startDate, String endDate) {
        LocalDate end = endDate != null ? LocalDate.parse(endDate) : LocalDate.now();
        LocalDate start = startDate != null ? LocalDate.parse(startDate) : end.minusDays(29);

        String storeFilter = storeId != null ? " AND store_id = ?" : "";

        String sql = "SELECT DATE(created_at) AS date, " +
                "COALESCE(SUM(amount), 0) AS consumption_amount, " +
                "COUNT(*) AS consumption_count " +
                "FROM consumption_records WHERE DATE(created_at) BETWEEN ? AND ?" +
                storeFilter + " GROUP BY DATE(created_at) ORDER BY date";

        String rechargeSql = "SELECT DATE(created_at) AS date, " +
                "COALESCE(SUM(amount), 0) AS recharge_amount, " +
                "COUNT(*) AS recharge_count " +
                "FROM recharge_records WHERE DATE(created_at) BETWEEN ? AND ?" +
                storeFilter + " GROUP BY DATE(created_at) ORDER BY date";

        Object[] consumeParams = storeId != null
                ? new Object[]{start, end, storeId}
                : new Object[]{start, end};
        Object[] rechargeParams = storeId != null
                ? new Object[]{start, end, storeId}
                : new Object[]{start, end};

        List<Map<String, Object>> consumptions = jdbc.queryForList(sql, consumeParams);
        List<Map<String, Object>> recharges = jdbc.queryForList(rechargeSql, rechargeParams);

        // Merge by date
        Map<String, Map<String, Object>> merged = new LinkedHashMap<>();
        DateTimeFormatter fmt = DateTimeFormatter.ofPattern("yyyy-MM-dd");
        for (LocalDate d = start; !d.isAfter(end); d = d.plusDays(1)) {
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("date", d.format(fmt));
            row.put("consumption_amount", 0);
            row.put("consumption_count", 0);
            row.put("recharge_amount", 0);
            row.put("recharge_count", 0);
            merged.put(d.format(fmt), row);
        }
        for (Map<String, Object> c : consumptions) {
            String date = c.get("date").toString();
            if (merged.containsKey(date)) {
                merged.get(date).put("consumption_amount", c.get("consumption_amount"));
                merged.get(date).put("consumption_count", c.get("consumption_count"));
            }
        }
        for (Map<String, Object> r : recharges) {
            String date = r.get("date").toString();
            if (merged.containsKey(date)) {
                merged.get(date).put("recharge_amount", r.get("recharge_amount"));
                merged.get(date).put("recharge_count", r.get("recharge_count"));
            }
        }
        return new ArrayList<>(merged.values());
    }

    @Override
    public List<Map<String, Object>> revenueStats(String storeId, int days) {
        LocalDate end = LocalDate.now();
        LocalDate start = end.minusDays(days - 1);
        String storeFilter = storeId != null ? " AND store_id = ?" : "";

        String sql = "SELECT DATE(created_at) AS date, COALESCE(SUM(amount), 0) AS amount " +
                "FROM consumption_records WHERE DATE(created_at) BETWEEN ? AND ?" +
                storeFilter + " GROUP BY DATE(created_at) ORDER BY date";

        Object[] params = storeId != null
                ? new Object[]{start, end, storeId}
                : new Object[]{start, end};
        return jdbc.queryForList(sql, params);
    }

    @Override
    public List<Map<String, Object>> memberGrowthStats(String storeId, int days) {
        LocalDate end = LocalDate.now();
        LocalDate start = end.minusDays(days - 1);
        String storeFilter = storeId != null ? " AND store_id = ?" : "";

        String sql = "SELECT DATE(created_at) AS date, COUNT(*) AS count " +
                "FROM members WHERE DATE(created_at) BETWEEN ? AND ?" +
                storeFilter + " GROUP BY DATE(created_at) ORDER BY date";

        Object[] params = storeId != null
                ? new Object[]{start, end, storeId}
                : new Object[]{start, end};
        return jdbc.queryForList(sql, params);
    }

    @Override
    public List<Map<String, Object>> hotServicesStats(String storeId, int limit) {
        String storeFilter = storeId != null ? " AND c.store_id = ?" : "";

        String sql = "SELECT c.service_name AS name, COUNT(*) AS count, COALESCE(SUM(c.amount), 0) AS revenue " +
                "FROM consumption_records c WHERE c.service_name IS NOT NULL" +
                storeFilter + " GROUP BY c.service_name ORDER BY count DESC LIMIT ?";

        Object[] params = storeId != null ? new Object[]{storeId, limit} : new Object[]{limit};
        return jdbc.queryForList(sql, params);
    }
}
