WITH daily_revenue AS (
    SELECT 
        DATE_FORMAT(DATE_PARSE(ord_tm, '%Y-%m-%d %H:%i:%s.%f'), '%Y-%m-%d') AS sale_date,  
        ROUND(SUM(before_prefr_amount) - SUM(sku_offer_amount), 2) AS GMV
    FROM gdm.gdm_m04_cml_ord_det_sum
    WHERE dt = DATE_FORMAT(DATE_ADD('day', -1, CURRENT_DATE), '%Y-%m-%d')
        AND ord_tm BETWEEN #date# AND #date_end#
        AND ord_status_cd != 11
        AND ord_status_cd IN (22, 25, 30)
        AND test_flag = 1
    GROUP BY DATE_FORMAT(DATE_PARSE(ord_tm, '%Y-%m-%d %H:%i:%s.%f'), '%Y-%m-%d')
),
valid_transactions AS (
    SELECT 
        DATE_FORMAT(DATE_PARSE(createdate, '%Y-%m-%d %H:%i:%s.%f'), '%Y-%m-%d') AS valid_transaction_date,
        substr(
            transactioncode, 
            length(transactioncode) - strpos(reverse(transactioncode), '_') + 2
        ) AS transaction_sale_ord_id,
        amount
    FROM fdm.fdm_marketingbeans_transactiondetail_chain
    WHERE dp = 'ACTIVE' 
      AND amount < 0
      AND createdate BETWEEN #date# AND #date_end#
      AND substr(
            transactioncode, 
            length(transactioncode) - strpos(reverse(transactioncode), '_') + 2
        ) IN (
            SELECT parent_sale_ord_id
            FROM gdm.gdm_m04_cml_ord_det_sum
            WHERE dt = DATE_FORMAT(DATE_ADD('day', -1, CURRENT_DATE), '%Y-%m-%d')
              AND ord_tm BETWEEN #date# AND #date_end#
              AND ord_status_cd != 11
              AND ord_status_cd IN (22, 25, 30)
              AND test_flag = 1
        )
),
Count_Orders AS (
    SELECT 
        DATE_FORMAT(DATE_PARSE(ord_tm, '%Y-%m-%d %H:%i:%s.%f'), '%Y-%m-%d') AS sale_date,
        COUNT(DISTINCT sale_ord_id) as sale_ord_count
    FROM gdm.gdm_m04_cml_ord_det_sum
    WHERE dt = DATE_FORMAT(DATE_ADD('day', -1, CURRENT_DATE), '%Y-%m-%d')
        AND ord_tm BETWEEN #date# AND #date_end#
        AND ord_status_cd != 11
        AND ord_status_cd IN (22, 25, 30)
        AND test_flag = 1
    GROUP BY DATE_FORMAT(DATE_PARSE(ord_tm, '%Y-%m-%d %H:%i:%s.%f'), '%Y-%m-%d')
),
Count_Parent_Orders AS (
    SELECT 
    DATE_FORMAT(DATE_PARSE(ord_tm, '%Y-%m-%d %H:%i:%s.%f'), '%Y-%m-%d') AS sale_date,
        COUNT(DISTINCT parent_sale_ord_id) as parent_sale_ord_count
    FROM gdm.gdm_m04_cml_ord_det_sum
    WHERE dt = DATE_FORMAT(DATE_ADD('day', -1, CURRENT_DATE), '%Y-%m-%d')
        AND ord_tm BETWEEN #date# AND #date_end#
        AND ord_status_cd != 11
        AND ord_status_cd IN (22, 25, 30)
        AND test_flag = 1
    GROUP BY DATE_FORMAT(DATE_PARSE(ord_tm, '%Y-%m-%d %H:%i:%s.%f'), '%Y-%m-%d')
),
marketingbeans AS (
    SELECT 
        valid_transaction_date AS points_date, 
        ROUND(SUM(ABS(amount)) / 100, 2) AS points_redeemed,
        COUNT(DISTINCT transaction_sale_ord_id) AS orders_by_points
    FROM valid_transactions
    GROUP BY valid_transaction_date
)
SELECT 
    COALESCE(a.sale_date, c.points_date) AS "Date",
    a.GMV,
    b.sale_ord_count AS "Order Count",
    d.parent_sale_ord_count AS "Parent Order Count",
    c.points_redeemed AS "Redeemed Amount",
    c.orders_by_points AS "Orders Using Points",
    ROUND((a.GMV - LAG(a.GMV) OVER (ORDER BY COALESCE(a.sale_date, c.points_date))) * 100.0 / 
           LAG(a.GMV) OVER (ORDER BY COALESCE(a.sale_date, c.points_date)), 2) AS "Daily Growth (%)"
FROM daily_revenue a
JOIN Count_Orders b
ON a.sale_date = b.sale_date
JOIN Count_Parent_Orders d
ON a.sale_date = d.sale_date
FULL OUTER JOIN marketingbeans c
    ON a.sale_date = c.points_date
ORDER BY COALESCE(a.sale_date, c.points_date);
