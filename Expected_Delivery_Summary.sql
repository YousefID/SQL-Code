WITH orders AS (
    SELECT DISTINCT 
        o.sale_ord_id, 
        o.rev_addr_city_id, 
        o.vender_id, 
        o.ord_tm,
        o.complete_tm,
        CASE 
            WHEN o.vender_id = '100086' THEN 'Zode Global'
            WHEN o.vender_id = '100041' THEN 'Retail'
            ELSE 'Marketplace'
        END AS Business_Model_V,
        TRIM(dest_city.dim_city_name) AS Destination_City
    FROM gdm.gdm_m04_cml_ord_det_sum o
    LEFT JOIN dim.dim_cml_city dest_city ON o.rev_addr_city_id = dest_city.city_id
    WHERE o.ord_tm BETWEEN #date# AND #date_end#
      AND o.dt = date_format(date_add('day', -1, CURRENT_DATE), '%Y-%m-%d') 
      AND dest_city.dt = date_format(date_add('day', -1, CURRENT_DATE), '%Y-%m-%d') 
      AND o.ord_status_cd = '30'
),

vendor_data AS (
    SELECT DISTINCT
        vd.vender_id, 
        vd.shop_name,
        TRIM(src_city.dim_city_name) AS Source_City
    FROM gdm.gdm_m01_cml_vender_da vd
    LEFT JOIN fdm.fdm_commer_store_center_sea_warehouse_chain d ON vd.vender_id = d.vender_id
    LEFT JOIN dim.dim_cml_city src_city ON d.city_id = src_city.city_id
    WHERE vd.dt = date_format(date_add('day', -1, CURRENT_DATE), '%Y-%m-%d') 
      AND src_city.dt = date_format(date_add('day', -1, CURRENT_DATE), '%Y-%m-%d')
),

sla_data AS (
    SELECT 
        TRIM(business_model) AS business_model, 
        TRIM(origin_city) AS origin_city, 
        TRIM(destination_city) AS destination_city, 
        order_cut_off, 
        promise_sla,
        TRIM(day_off) AS day_off,
        CASE 
            WHEN order_cut_off LIKE '%AM%' THEN CAST(REGEXP_REPLACE(order_cut_off, '[^0-9]', '') AS INTEGER)
            WHEN order_cut_off LIKE '%PM%' THEN CAST(REGEXP_REPLACE(order_cut_off, '[^0-9]', '') AS INTEGER) + 12
            ELSE NULL
        END AS cut_off_hour,
        CASE 
            WHEN order_cut_off LIKE '<%' THEN '<'
            WHEN order_cut_off LIKE '>%' THEN '>'
            ELSE '='
        END AS cut_off_operator,
        CASE 
            WHEN promise_sla = '<24hrs (0 day)' THEN 0
            WHEN promise_sla LIKE '%hrs%' THEN CAST(REGEXP_REPLACE(promise_sla, '[^0-9]', '') AS DOUBLE) / 24
            WHEN promise_sla LIKE '%days%' THEN CAST(REGEXP_REPLACE(promise_sla, '[^0-9]', '') AS DOUBLE)
            ELSE NULL
        END AS SLA_In_Days
    FROM default.promise_management_new
),

merged_data AS (
    SELECT 
        o.sale_ord_id,
        o.rev_addr_city_id,
        o.vender_id,
        o.ord_tm,
        o.complete_tm,
        CASE 
            WHEN o.vender_id = '100041' THEN 'Zode'
            ELSE vd.shop_name 
        END AS shop_Fullname,
        
        CASE 
            WHEN o.vender_id = '100041' THEN 'Riyadh'
            ELSE COALESCE(vd.Source_City, 'Update Missing City') 
        END AS Source_City,
        
        o.Business_Model_V,
        sla.cut_off_hour,
        o.Destination_City,
        sla.promise_sla,
        sla.order_cut_off,
        sla.SLA_In_Days,
        sla.cut_off_operator,
        sla.day_off,
        
        DATE_ADD('day', CAST(COALESCE(sla.SLA_In_Days, 0) AS INTEGER), DATE_TRUNC('day', DATE_PARSE(o.ord_tm, '%Y-%m-%d %H:%i:%s.%f'))) AS Initial_Expected_Delivery_Date,
        
     CASE 
		WHEN sla.day_off = 'Fri is off' 
         AND (
             (DAY_OF_WEEK(DATE_TRUNC('day', DATE_PARSE(o.ord_tm, '%Y-%m-%d %H:%i:%s.%f'))) <= 5 
              AND DAY_OF_WEEK(DATE_ADD('day', CAST(COALESCE(sla.SLA_In_Days, 0) AS INTEGER), 
              DATE_TRUNC('day', DATE_PARSE(o.ord_tm, '%Y-%m-%d %H:%i:%s.%f')))) >= 5)
             OR (DATE_DIFF('day', DATE_TRUNC('day', DATE_PARSE(o.ord_tm, '%Y-%m-%d %H:%i:%s.%f')), 
              DATE_ADD('day', CAST(COALESCE(sla.SLA_In_Days, 0) AS INTEGER), 
              DATE_TRUNC('day', DATE_PARSE(o.ord_tm, '%Y-%m-%d %H:%i:%s.%f')))) >= 7)
         )
    THEN DATE_ADD('day', 1, DATE_ADD('day', CAST(COALESCE(sla.SLA_In_Days, 0) AS INTEGER), 
         DATE_TRUNC('day', DATE_PARSE(o.ord_tm, '%Y-%m-%d %H:%i:%s.%f'))))
    ELSE DATE_ADD('day', CAST(COALESCE(sla.SLA_In_Days, 0) AS INTEGER), 
         DATE_TRUNC('day', DATE_PARSE(o.ord_tm, '%Y-%m-%d %H:%i:%s.%f')))
	END AS Expected_Delivery_Date
    FROM orders o
    LEFT JOIN vendor_data vd ON o.vender_id = vd.vender_id
    LEFT JOIN sla_data sla 
        ON sla.business_model = o.Business_Model_V
        AND (
            sla.origin_city = COALESCE(vd.Source_City, sla.origin_city)
            OR sla.origin_city IS NULL
        )
        AND (
            sla.destination_city = CASE
                WHEN o.Destination_City IN (SELECT DISTINCT TRIM(destination_city) FROM default.promise_management_new)
                    THEN o.Destination_City
                ELSE 'Rest of cities'
            END
        )
        AND (
            (sla.cut_off_operator = '<' AND HOUR(DATE_PARSE(o.ord_tm, '%Y-%m-%d %H:%i:%s.%f')) < sla.cut_off_hour) OR
            (sla.cut_off_operator = '>' AND HOUR(DATE_PARSE(o.ord_tm, '%Y-%m-%d %H:%i:%s.%f')) > sla.cut_off_hour) OR
            (sla.cut_off_operator = '=' AND HOUR(DATE_PARSE(o.ord_tm, '%Y-%m-%d %H:%i:%s.%f')) = sla.cut_off_hour)
        )
),

sla_summary AS (
    SELECT 
        sale_ord_id AS "Order ID",
        rev_addr_city_id AS Destination_City_ID,
        Destination_City AS "Destination City",
        vender_id,
        cut_off_hour,
        Business_Model_V AS "Business Model",
        shop_Fullname AS "Shop Name",
        ord_tm,
        complete_tm AS "Complete Time",
        Source_City AS "Source City",
        promise_sla,
        cut_off_operator,
        order_cut_off,
        SLA_In_Days,
        Expected_Delivery_Date,
        CASE 
            WHEN DATE_TRUNC('day', DATE_PARSE(complete_tm, '%Y-%m-%d %H:%i:%s.%f')) <= DATE_TRUNC('day', Expected_Delivery_Date)
                THEN 'Within SLA'
            ELSE 'Exceed SLA'
        END AS "SLA_Status"
    FROM merged_data m
),

daily_sla_summary AS (
    SELECT 
        DATE_TRUNC('day', Expected_Delivery_Date) AS Expected_Delivery,
        SLA_Status,
        COUNT(*) AS Order_Count
    FROM sla_summary
    GROUP BY 1, 2
)

SELECT 
    Expected_Delivery,
    COALESCE(SUM(CASE WHEN SLA_Status = 'Within SLA' THEN Order_Count END), 0) AS "Within SLA",
    COALESCE(SUM(CASE WHEN SLA_Status = 'Exceed SLA' THEN Order_Count END), 0) AS "Exceed SLA",
    COALESCE(SUM(Order_Count), 0) AS "Grand Total"
FROM daily_sla_summary
GROUP BY Expected_Delivery
ORDER BY Expected_Delivery;
