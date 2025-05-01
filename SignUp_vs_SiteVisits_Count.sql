WITH Site_Visits AS (
    SELECT 
        session_id, 
        dt 
    FROM gdm.gdm_online_log
    WHERE dt BETWEEN #date# AND #date_end# 
      AND session_id IS NOT NULL
      AND session_id <> ''
      
    UNION ALL 
    
    SELECT 
        session_id, 
        dt 
    FROM gdm.gdm_m14_m_online_log
    WHERE dt BETWEEN #date# AND #date_end# 
      AND session_id IS NOT NULL
      AND session_id <> ''
    
    UNION ALL
    
    SELECT 
        session_id, 
        dt 
    FROM gdm.gdm_m14_cml_wxapp_online_log
    WHERE dt BETWEEN #date# AND #date_end# 
      AND session_id IS NOT NULL
      AND session_id <> ''
),
Site_Login_SignUP AS (
    SELECT 
        user_log_acct, 
        dt 
    FROM gdm.gdm_online_log
    WHERE dt BETWEEN #date# AND #date_end# 
      AND user_log_acct IS NOT NULL
      AND user_log_acct <> ''
    
    UNION ALL 
    
    SELECT 
        user_log_acct, 
        dt 
    FROM gdm.gdm_m14_m_online_log
    WHERE dt BETWEEN #date# AND #date_end# 
      AND user_log_acct IS NOT NULL
      AND user_log_acct <> ''
    
    UNION ALL
    
    SELECT 
        user_log_acct, 
        dt 
    FROM gdm.gdm_m14_cml_wxapp_online_log
    WHERE dt BETWEEN #date# AND #date_end# 
      AND user_log_acct IS NOT NULL
      AND user_log_acct <> ''
),
Sessions_view AS(

  SELECT 
    sn.dt AS SN_Date,
    COUNT(DISTINCT sn.session_id) AS "Sessions"
    
FROM Site_Visits sn
GROUP BY sn.dt
),
Login_Count AS(
  SELECT 
    sg.dt AS SG_Date,
    COUNT(DISTINCT sg.user_log_acct) AS "Login_Sign_up"
FROM Site_Login_SignUP sg
GROUP BY sg.dt
)
SELECT 
    sn.SN_Date AS "Date",
    sn.Sessions AS "Sessions",
    sg.Login_Sign_up  AS "Login/Sign up",
    CAST(sg.Login_Sign_up AS DOUBLE)  / CAST(sn.Sessions AS DOUBLE) *100 AS "Conv (%)"
FROM Sessions_view sn
LEFT JOIN Login_Count sg
ON sn.SN_Date = sg.SG_Date
ORDER BY sn.SN_Date

