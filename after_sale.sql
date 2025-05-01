WITH after_sale AS (
    SELECT 
        a.afs_ser_bill_id,
        a.sale_ord_id,
        a.vender_id,
        b.shop_name,
        a.afs_status_cd,
        a.pay_price,
        a.afs_refund_tm,
        a.apply_tm,
        a.question_type_cid1,
        a.question_desc,
        a.item_sku_id,
        a.sku_name,
        a.afs_refund_qtty,
        a.afs_refund_amt,
        b.pay_mode_cd,
        b.before_prefr_amount AS jd_prc,
        d.afs_service_state,
        d.afs_service_step,
        CASE
            WHEN c.attr_val = 1 THEN 'Non-Returnable'
            ELSE 'Returnable' 
        END AS Returnable_Status
    FROM gdm.gdm_m10_cml_afs_ser_sum_da a
    JOIN fdm.fdm_generic_afs_afs_service_chain d 
        ON a.afs_ser_bill_id = d.afs_service_id
        AND d.dp = 'ACTIVE'
    LEFT JOIN gdm.gdm_m04_cml_ord_det_sum b 
        ON a.sale_ord_id = b.sale_ord_id 
        AND a.item_sku_id = b.item_sku_id
        AND b.dt = DATE_FORMAT(DATE_ADD('day', -1, CURRENT_DATE), '%Y-%m-%d')
    LEFT JOIN gdm.gdm_m03_cml_item_spec_attr_da c 
        ON a.item_sku_id = c.item_sku_id 
        AND c.attr_name = 'bzcsh' 
        AND c.dt = DATE_FORMAT(DATE_ADD('day', -1, CURRENT_DATE), '%Y-%m-%d')
    WHERE a.test_flag = 1
        AND a.dt = DATE_FORMAT(DATE_ADD('day', -1, CURRENT_DATE), '%Y-%m-%d')
        AND a.apply_tm BETWEEN #date# AND #date_end#
),
tracking AS (
    SELECT DISTINCT 
        order_id,
        waybill_code,
        carrier_code,
        service_id,
        Remark
    FROM fdm.fdm_rc_std_domain_waybill_code_chain
    WHERE dp = 'ACTIVE'
),
QualityControl AS (
    SELECT 
       DISTINCT service_id,
        json_extract_scalar(q.json_value, '$.qualityControlEnName') AS qualityControlEnName,
        json_extract_scalar(q.json_value, '$.qualityLevel') AS qualityLevel,
        json_extract_scalar(q.json_value, '$.productsRefundRadio') AS productsRefundRadio,
        json_extract_scalar(q.json_value, '$.shippingFeeRefundRadio') AS shippingFeeRefundRadio
    FROM fdm.fdm_rc_std_domain_waybill_code_chain t
    CROSS JOIN UNNEST(
        CASE 
            WHEN t.remark IS NOT NULL AND t.remark <> ''  
            THEN TRY(CAST(json_parse(t.remark) AS ARRAY(JSON)))  
            ELSE ARRAY[]  
        END
    ) AS q(json_value)
    WHERE dp = 'ACTIVE'
     AND TRY_CAST(json_extract_scalar(q.json_value, '$.nums') AS INTEGER) > 0
    AND json_extract_scalar(q.json_value, '$.qualityControlEnName') IS NOT NULL
   
),
customerInfo AS (
    SELECT DISTINCT 
        fd1.customer_contact_name,
        fd1.customer_tel,
        fd1.order_id,
        src_city.dim_city_name,
        fd1.afs_service_id
    FROM fdm.fdm_generic_afs_afs_service_chain fd1
    LEFT JOIN dim.dim_cml_city src_city 
        ON fd1.pickware_city = src_city.dim_city_id
        AND src_city.dt = DATE_FORMAT(DATE_ADD('day', -1, CURRENT_DATE), '%Y-%m-%d')
    WHERE fd1.dp = 'ACTIVE'
)

SELECT 
    afs.sale_ord_id AS "Order No.",
    afs.afs_ser_bill_id AS "Service Order No",
    
    
    afs.vender_id AS "vender id",
    afs.shop_name,
    CASE 
        WHEN afs.afs_service_state = 30 THEN 
            CASE WHEN afs.afs_service_step = 34 THEN 'To Be Processed' ELSE 'To Be Approved' END
        WHEN afs.afs_service_state = 7000 THEN 'Closed'
        WHEN afs.afs_service_state = 8000 THEN 'Cancelled'
        WHEN afs.afs_service_state IN (1041, 1120) THEN 'Processing'
        WHEN afs.afs_service_state = 9000 THEN 'Completed'
        WHEN afs.afs_service_state = 1039 THEN 'Awaiting Acceptance'
    END AS "Refund Status",
    afs.afs_refund_tm AS "Refund time",
    afs.apply_tm AS "Application time",
    CASE afs.question_type_cid1
        WHEN 1001 THEN 'Goods have not been received'
        WHEN 1002 THEN 'Dislike or inappropriate'
        WHEN 1003 THEN 'Ware does not match page description'
        WHEN 1004 THEN 'Damaged goods/packing problem'
        WHEN 1005 THEN 'Product quality/failure'
    END AS Returning,
    afs.question_desc AS "Return reason",
    afs.item_sku_id AS "SKU No",
    afs.sku_name AS "Product name",
    afs.afs_refund_qtty AS "Quantity",
    afs.afs_refund_amt AS "Refund Amount",
    CASE afs.pay_mode_cd
        WHEN 1 THEN 'COD'
        WHEN 4 THEN 'Online Payment'
    END AS "Payment type",
    c.customer_contact_name AS "Customer name",
    c.customer_tel AS "Contact number",
    c.dim_city_name AS "City",
    t.waybill_code AS "Tracking No",
    t.carrier_code AS "Carrier",
    afs.jd_prc AS "SKU Price",
    afs.Returnable_Status AS "Returnable Status",
    q.qualityControlEnName AS "Quality Control Name",
    q.qualityLevel AS "Quality Level",
    q.productsRefundRadio AS "products Refund %",
    q.shippingFeeRefundRadio AS "Shipping Fee Refund %"
FROM after_sale afs
LEFT JOIN customerInfo c ON afs.afs_ser_bill_id = c.afs_service_id
LEFT JOIN tracking t ON afs.afs_ser_bill_id = t.service_id
LEFT JOIN QualityControl q ON afs.afs_ser_bill_id = q.service_id
