WITH orders AS (
    SELECT 
        DISTINCT sale_ord_id AS "saleordid",
        DATE_FORMAT(DATE_PARSE(ord_tm, '%Y-%m-%d %H:%i:%s.%f'), '%Y-%m-%d')    AS  order_date,
        complete_tm,
        pay_tm,
        user_log_acct,
        shop_name,
        CASE 
            WHEN vender_id = '100041' THEN '401-Retail Order'
            WHEN vender_id = '100086' THEN '5-JDI Order'
            ELSE 'Marketplace'
        END AS Order_Kinds,
        CASE 
            WHEN ord_status_cd = 2 THEN 'Cancelled'
            WHEN ord_status_cd = 102 THEN 'Cancelled'
            WHEN ord_status_cd = 22 THEN 'To be delivered'
            WHEN ord_status_cd = 25 THEN 'To confirm receipt'
            WHEN ord_status_cd = 30 THEN 'Completed'
            WHEN ord_status_cd = 122 THEN 'Cancelled'
            ELSE 'Others'
        END AS status_desc,
        CASE 
            WHEN test_flag = 1 THEN 'Non Test Orders'
            ELSE 'Test Orders'
        END AS Flag_test_status
    FROM gdm.gdm_m04_cml_ord_det_sum
    WHERE ord_tm BETWEEN #date# AND #date_end#
      AND dt = date_format(date_add('day', -1, CURRENT_DATE), '%Y-%m-%d') 
      AND ord_status_cd != 11
      AND ord_status_cd = 30
      AND test_flag = 1
),
Shipping AS (
    SELECT
        DISTINCT orderid AS orderid,
        ROUND(CAST(COALESCE(freight, 0) AS BIGINT) / 100, 2) AS "freight"
    FROM fdm.fdm_order_pop_order_new_chain
    WHERE dp = 'ACTIVE'
),
Orders_Details AS (
    SELECT 
        DISTINCT sale_ord_id AS "sale_ord_id",
        reward_points,
        ordertotalfee,
        totalfee,
        cod_service_fee,
        seller_shipping_discount,
        import_fee,
        voucher_discount,
        shipping_discount,
        coupon_code
    FROM gdm.gdm_m04_cml_orderver
    WHERE servicetypeid BETWEEN #date# AND #date_end#
      AND dt = date_format(date_add('day', -1, CURRENT_DATE), '%Y-%m-%d') 
)
SELECT 
    o.order_date AS  "Order Date",
    COUNT(DISTINCT o.saleordid) AS "Free Shipped Orders",
    SUM(ROUND(CAST(COALESCE(v.ordertotalfee, 0) AS DECIMAL(18, 2)), 2)) AS "Order Total"
FROM 
    orders o
LEFT JOIN Orders_Details v ON o.saleordid = v.sale_ord_id
LEFT JOIN Shipping s ON o.saleordid = s.orderid
WHERE 
    ROUND(CAST(COALESCE(s.freight, 0) AS DECIMAL(18, 2)), 2) - 
    ROUND(CAST(COALESCE(v.shipping_discount, 0) AS DECIMAL(18, 2)), 2) <= 0 
    AND o.order_date BETWEEN #date# AND #date_end# 
   
GROUP BY 
    o.order_date
ORDER BY 
    "Order Date"
