SELECT  ROW_NUMBER() OVER() as rn,TO_CHAR(DATEADD(GETDATE(),-1,'mm'),'yyyymm') ym,DECODE(a.admdvs,'330102','上城区','330105','拱墅区','330106','西湖区','330108','滨江区','330109','萧山区','330110','余杭区','330111','富阳区','330183','富阳区','330112','临安区','330113','临平区','330114','钱塘区','330122','桐庐县','330127','淳安县','330182','建德市','杭州市本级') 医保区划名称
,sum(d.生育参保人数) 生育参保人数
,sum(d.其中女性) 其中女性
,sum(b.计划生育手术人次) 计划生育手术人次
,sum(b.参保女职工生育人数) 参保女职工生育人数
,sum(b.产前检查人次) 产前检查人次
,sum(b.住院分娩人次) 住院分娩人次
,sum(c.津贴待遇人次) 津贴待遇人次,to_char(GETDATE(),'yyyymmdd') as diff_date,'INSERT' diff_type
FROM    (
  SELECT  DISTINCT admdvs
  ,admdvs_name
  FROM    znjg_prd.admdvs_dim_a
  WHERE   admdvs LIKE '3301%'
) a
LEFT JOIN (
  SELECT  insu_admdvs
  ,SUM(参保女职工生育人数) 参保女职工生育人数
  ,SUM(计划生育手术人次) 计划生育手术人次
  ,SUM(产前检查人次) 产前检查人次
  ,SUM(住院分娩人次) 住院分娩人次
  FROM    (
    SELECT  a.insu_admdvs
    ,COUNT(
            DISTINCT CASE    WHEN ((a.setl_type='2' AND c.手术类别 IN ('顺产','剖宫产')) OR (a.setl_type='1' AND a.medfee_sumamt>1500 AND a.med_type LIKE '52%')) AND a.gend='2' THEN a.psn_no
                             END
            ) AS 参保女职工生育人数
    ,COUNT(
            DISTINCT CASE    WHEN c.手术类别 IN ('流产','其他计划生育') AND a.gend='2' THEN a.mdtrt_id
                             END
            ) AS 计划生育手术人次
    ,SUM(
              CASE    WHEN f.setl_id IS NOT NULL AND a.gend='2' AND ((a.setl_type='2' AND c.手术类别 IN ('顺产','剖宫产')) OR (a.setl_type='1' AND a.medfee_sumamt>1500 AND a.med_type LIKE '52%')) THEN f.产前检查就诊人次
                             END
            ) AS 产前检查人次
    ,COUNT(
            DISTINCT CASE    WHEN ((a.setl_type='2' AND c.手术类别 IN ('顺产','剖宫产')) OR (a.setl_type='1' AND a.medfee_sumamt>1500 AND a.med_type LIKE '52%')) AND a.gend='2' THEN a.psn_no
                             END
            ) AS 住院分娩人次
    FROM    znjg_prd.setl_d_temp a
    LEFT JOIN (
      SELECT  a.setl_id
      ,a.psn_no
      ,b.手术类别
      ,SUM(a.det_item_fee_sumamt) AS det_item_fee_sumamt
      FROM    znjg_prd.fee_list_d_temp a
      JOIN    tmp_matn_type_info b
      ON      a.hilist_code = b.目录编码
      WHERE   vali_flag = '1'
      AND     a.pt = TO_CHAR(DATEADD(GETDATE(),-1,'mm'),'yyyymm')
      GROUP BY a.setl_id
      ,a.psn_no
      ,b.手术类别
    ) c
    ON      a.setl_id = c.setl_id
    -- 2列在住院分娩前8个月（发生11种项目编码交易的前8个月）相关科室发生的产检人次，按4个同一统计
    AND     a.psn_no = c.psn_no LEFT
    JOIN    (
    --   先取出这些所有女职工就医对应8个月内有过的产前检查的就医记录，汇总金额、人次，然后与a表关联过滤出生育人员金额
      SELECT  a.setl_id
      ,a.psn_no
      ,COUNT(
              DISTINCT CONCAT(
          b.psn_no
        ,b.fixmedins_code
        ,nvl(b.bilg_dept_codg,'0')
        ,to_char(b.setl_time,'yyyyMMdd')
        )
              ) AS 产前检查就诊人次
      FROM    znjg_prd.setl_d_temp a
      JOIN    (
        SELECT  a.psn_no
        ,a.setl_time
        ,a.insu_admdvs
        ,a.fixmedins_code
        ,c.adm_dept_codg AS bilg_dept_codg
        ,a.hifp_pay
        FROM    znjg_prd.setl_d_temp a
        JOIN    (
          SELECT  DISTINCT setl_id
          ,psn_no
          FROM    znjg_prd.fee_list_d_temp b
          WHERE   b.vali_flag = '1'
          AND     b.pt IN ('20231202',TO_CHAR(DATEADD(GETDATE(),-1,'mm'),'yyyymm'))
          AND     b.bilg_dept_codg IN ('A05','A05.01','A05.02','A05.03','A05.04','A05.05','A05.06','A06','A06.02','A50.03','B09')
        ) b
        ON      a.setl_id = b.setl_id
        AND     a.psn_no = b.psn_no
        JOIN    znjg_prd.mdtrt_d_temp c
        ON      a.psn_no = c.psn_no
        AND     a.mdtrt_id = c.mdtrt_id
        WHERE   a.vali_flag = '1'
        AND     a.pt IN ('20231202',TO_CHAR(DATEADD(GETDATE(),-1,'mm'),'yyyymm'))
        AND     c.pt IN ('20231202',TO_CHAR(DATEADD(GETDATE(),-1,'mm'),'yyyymm'))
        AND     a.refd_setl_flag = '0'
        AND     a.insu_admdvs LIKE '33%'
        AND     a.insutype = '310'
        AND     a.gend = '2'
        AND     a.setl_type IN ('1','2')
        AND     c.vali_flag = '1'
      ) b
      ON      a.psn_no = b.psn_no
      AND     DATEDIFF(a.setl_time,b.setl_time,'mm') > 0
      AND     DATEDIFF(a.setl_time,b.setl_time,'mm') <= 8
      WHERE   a.vali_flag = '1'
      AND     a.refd_setl_flag = '0'
      AND     TO_CHAR(a.setl_time,'yyyy') = TO_CHAR(DATEADD(GETDATE(),-1,'mm'),'yyyy')
      AND     a.pt = TO_CHAR(DATEADD(GETDATE(),-1,'mm'),'yyyymm')
      AND     a.insu_admdvs LIKE '33%'
      AND     a.insutype = '310'
      AND     a.gend = '2'
      AND     a.setl_type IN ('1','2')
      GROUP BY a.setl_id
      ,a.psn_no
    ) f
    ON      a.setl_id = f.setl_id
    AND     a.psn_no = f.psn_no
    JOIN    (
      SELECT  *
      FROM    znjg_prd.insu_emp_info_b_temp
      WHERE   pt = TO_CHAR(DATEADD(GETDATE(),-1,'mm'),'yyyymm')
      AND     is_current = '1'
      AND     vali_flag = '1'
    ) emp
    ON      a.emp_no = emp.emp_no
    WHERE   a.vali_flag = '1'
    AND     a.pt = TO_CHAR(DATEADD(GETDATE(),-1,'mm'),'yyyymm')
    AND     a.refd_setl_flag = '0'
    AND     TO_CHAR(a.setl_time,'yyyy') = TO_CHAR(DATEADD(GETDATE(),-1,'mm'),'yyyy')
    AND     a.insu_admdvs LIKE '33%'
    AND     a.insutype = '310'
    AND     a.setl_type IN ('1','2')
    GROUP BY a.insu_admdvs
    ,emp.rpt_emp_type
    ,emp.rpt_emp_mgt_type
  ) a
  GROUP BY a.insu_admdvs
) b
ON      a.admdvs = b.insu_admdvs LEFT
JOIN    (
  SELECT  a.insu_admdvs
  ,COUNT(
          DISTINCT CASE    WHEN a.crter_id NOT IN ('66666','55555') THEN a.matn_alwn_reg_id
                           END
          ) AS 津贴待遇人次
  FROM    znjg_prd.matn_alwn_reg_d_temp a
  JOIN    znjg_prd.matn_alwn_crtf_d_temp b
  ON      a.psn_no = b.psn_no
  AND     a.matn_alwn_reg_id = b.matn_alwn_reg_id
  JOIN    (
    SELECT  *
    FROM    znjg_prd.insu_emp_info_b_temp
    WHERE   pt = TO_CHAR(DATEADD(GETDATE(),-1,'mm'),'yyyymm')
    AND     is_current = '1'
    AND     vali_flag = '1'
  ) emp
  ON      a.emp_no = emp.emp_no
  WHERE   a.vali_flag = '1'
  AND     b.vali_flag = '1'
  AND     a.pt = TO_CHAR(DATEADD(GETDATE(),-1,'mm'),'yyyymm')
  AND     b.pt = TO_CHAR(DATEADD(GETDATE(),-1,'mm'),'yyyymm')
  AND     a.insu_admdvs LIKE '33%'
  AND     nvl(b.matn_alwn_sumamt,0) > 0
  AND     TO_CHAR(b.opt_time,'yyyy') = TO_CHAR(DATEADD(GETDATE(),-1,'mm'),'yyyy')
  GROUP BY a.insu_admdvs
) c
ON      a.admdvs = c.insu_admdvs
LEFT JOIN (
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
      FROM    znjg_prd.psn_insu_d_temp
      WHERE   insutype IN ('310')
      AND     pt = TO_CHAR(DATEADD(GETDATE(),-1,'mm'),'yyyymm')
      AND     crt_insu_date <= TO_CHAR(LASTDAY(DATEADD(GETDATE(),-1,'mm')),'yyyy-mm-dd')    --取2024-01-31参保
      AND     (paus_insu_date IS NULL OR paus_insu_date >= '2024-06-30')
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
      FROM    znjg_prd.psn_insu_his_d_temp
      WHERE   insutype IN ('310')
      AND     pt = TO_CHAR(DATEADD(GETDATE(),-1,'mm'),'yyyymm')
      AND     crt_insu_date <= TO_CHAR(LASTDAY(DATEADD(GETDATE(),-1,'mm')),'yyyy-mm-dd')   --取2024-01-31参保
      AND     (paus_insu_date IS NULL OR paus_insu_date >= '2024-06-30')
    )
  ) a
  JOIN    (
    SELECT  *
    FROM    znjg_prd.psn_info_b_temp b
    WHERE   pt = TO_CHAR(DATEADD(GETDATE(),-1,'mm'),'yyyymm')
    AND     b.vali_flag = '1'
    AND     b.is_current = '1'
  ) b
  ON      a.psn_no = b.psn_no
  JOIN    (
    SELECT  *
    FROM    znjg_prd.insu_emp_info_b_temp
    WHERE   pt = TO_CHAR(DATEADD(GETDATE(),-1,'mm'),'yyyymm')
    AND     is_current = '1'
    AND     vali_flag = '1'
  ) c
  ON      a.emp_no = c.emp_no
  LEFT JOIN (
  -- 最近六个月有过缴费记录的人员
    SELECT  DISTINCT psn_no
    FROM    znjg_prd.staf_psn_clct_detl_d_temp_3
    WHERE   insutype = '310'
    AND     pt = TO_CHAR(DATEADD(GETDATE(),-1,'mm'),'yyyymm')
    AND     accrym_begn BETWEEN TO_CHAR(LASTDAY(DATEADD(GETDATE(),-7,'mm')),'yyyymm')
    AND     TO_CHAR(LASTDAY(DATEADD(GETDATE(),-2,'mm')),'yyyymm')
    AND     clct_flag IN ('1','4')
    AND     revs_flag = 'Z'
  ) d
  ON      a.psn_no = d.psn_no
  WHERE   a.ranking = 1
  AND     (d.psn_no IS NOT NULL OR a.crt_insu_date >= TO_CHAR(LASTDAY(DATEADD(GETDATE(),-7,'mm')),'yyyy-mm-dd'))    --6个月内有缴费记录或者新参保人员
  AND     a.insutype_retr_flag = '0'    --职工在职
  AND     b.vali_flag = '1'
  AND     b.is_current = '1'
  AND     c.vali_flag = '1'
  AND     c.is_current = '1'
  AND     CASE WHEN c.emp_mgt_type IN ('02','03','05')
  AND     b.gend = '1' THEN b.brdy >= to_char(LASTDAY(DATEADD(GETDATE(),-60*12-1,'mm')),'yyyy-MM-dd') WHEN c.emp_mgt_type IN ('02','03','05')    --灵活就业去掉男60以上
  AND     b.gend = '2' THEN b.brdy >= to_char(LASTDAY(DATEADD(GETDATE(),-50*12-1,'mm')),'yyyy-MM-dd') ELSE 1 = 1 END    --灵活就业去掉女50以上
  GROUP BY a.insu_admdvs
) d
ON      a.admdvs = d.insu_admdvs
group by DECODE(a.admdvs,'330102','上城区','330105','拱墅区','330106','西湖区','330108','滨江区','330109','萧山区','330110','余杭区','330111','富阳区','330183','富阳区','330112','临安区','330113','临平区','330114','钱塘区','330122','桐庐县','330127','淳安县','330182','建德市','杭州市本级')
;