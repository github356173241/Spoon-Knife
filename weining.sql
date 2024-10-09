SELECT  a.insu_admdvs
                      ,COUNT(DISTINCT a.psn_no) AS 生育参保人数
                      ,COUNT(DISTINCT CASE WHEN b.gend='2' THEN a.psn_no END ) AS 其中女性
              FROM    (
                          SELECT  *
                                  ,ROW_NUMBER() OVER(PARTITION BY psn_no ORDER BY IF (paus_insu_date IS NULL ,updt_time,paus_insu_date) DESC ) AS ranking
                          FROM    (
                                      SELECT  psn_no
                                              ,psn_type
                                              ,psn_insu_stas
                                              ,insu_admdvs
                                              ,emp_no
                                              ,insutype
                                              ,crt_insu_date
                                              ,paus_insu_date
                                              ,psn_insu_rlts_id
                                              ,insutype_retr_flag
                                              ,updt_time
                                      FROM    psn_insu_d_temp
                                      WHERE   insutype IN ('310')
                                      AND     pt = '202409'
                                      AND     crt_insu_date <= '2024-09-30'    --取2024-01-31参保
                                      AND     (paus_insu_date IS NULL OR paus_insu_date >= '2024-09-30')
                                      UNION
                                      SELECT  psn_no
                                              ,psn_type
                                              ,psn_insu_stas
                                              ,insu_admdvs
                                              ,emp_no
                                              ,insutype
                                              ,crt_insu_date
                                              ,paus_insu_date
                                              ,psn_insu_rlts_id
                                              ,insutype_retr_flag
                                              ,updt_time
                                      FROM    psn_insu_his_d_temp
                                      WHERE   insutype IN ('310')
                                      AND     pt = '202409'
                                      AND     crt_insu_date <= '2024-09-30'    --取2024-01-31参保
                                      AND     (paus_insu_date IS NULL OR paus_insu_date >= '2024-09-30')
                                  ) 
                      ) a
              JOIN    (
                          SELECT  *
                          FROM    znjg_prd.psn_info_b_temp b
                          WHERE   pt = '202409'
                          AND     b.vali_flag = '1'
                          AND     b.is_current = '1'
                      ) b
              ON      a.psn_no = b.psn_no
              JOIN    (
                          SELECT  *
                          FROM    znjg_prd.insu_emp_info_b_temp
                          WHERE   pt = '202409'
                          AND     is_current = '1'
                          AND     vali_flag = '1'
                      ) c
              ON      a.emp_no = c.emp_no
              LEFT JOIN (
                            -- 最近六个月有过缴费记录的人员
                            SELECT  DISTINCT psn_no
                            FROM    staf_psn_clct_detl_d_temp_3
                            WHERE   insutype = '310'
                            AND     pt = '202409'
                            AND     accrym_begn BETWEEN '202403'
                            AND     '202408'
                            AND     clct_flag IN ('1','4')
                            AND     revs_flag = 'Z'
                        ) d
              ON      a.psn_no = d.psn_no
              WHERE   a.ranking = 1
              AND     (d.psn_no IS NOT NULL OR a.crt_insu_date >= '2024-03-31')    --6个月内有缴费记录或者新参保人员
              AND     a.insutype_retr_flag = '0'    --职工在职
              AND     b.vali_flag = '1'
              AND     b.is_current = '1'
              AND     c.vali_flag = '1'
              AND     c.is_current = '1'
              AND     CASE WHEN c.emp_mgt_type IN ('02','03','05')
              AND     b.gend = '1' THEN b.brdy >= '1964-09-30' WHEN c.emp_mgt_type IN ('02','03','05')    --灵活就业去掉男60以上 
              AND     b.gend = '2' THEN b.brdy >= '1974-09-30' ELSE 1 = 1 END    --灵活就业去掉女50以上
              GROUP BY a.insu_admdvs