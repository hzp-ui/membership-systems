package com.membership.controller;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/test")
public class TestController {

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @GetMapping("/charset")
    public Map<String, Object> getCharset() {
        List<Map<String, Object>> result = jdbcTemplate.queryForList("SHOW VARIABLES LIKE 'character_set%'");
        return Map.of("code", 200, "data", result);
    }
}
