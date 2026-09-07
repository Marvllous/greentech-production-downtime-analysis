-- Data assesment and understanding the data structure
SELECT * FROM downtime_factors;
SELECT * FROM line_downtime;
SELECT * FROM line_productivity_batches;
SELECT * FROM products;

-- Number of Rows
SELECT COUNT (*) AS NumRows_Downtime_Factors FROM downtime_factors;
SELECT COUNT (*) AS NumRows_Line_Downtime FROM line_downtime;
SELECT COUNT (*) AS NumRows_Line_Productivity_batches FROM line_productivity_batches;
SELECT COUNT (*) AS NumRows_Line_Products FROM products;

-- CHECK FOR NULLS 
-- FACTOR 1 NULL COUNT
SELECT COUNT (*) AS Factor1_null_count FROM line_downtime
WHERE Factor_1 IS NULL;

--  FACTOR 2 NULL COUNT
SELECT COUNT (*) AS Factor2_null_count FROM line_downtime
WHERE Factor_2 IS NULL;

-- ALL FACTORS COUNT OF NULLS
SELECT COUNT (*) AS All_factors_null_count FROM line_downtime
WHERE COALESCE(Factor_1, Factor_2, Factor_3, Factor_4, Factor_5, Factor_6,
Factor_7, Factor_8, Factor_9, Factor_10, Factor_11, Factor_12, Factor_13) IS NULL;

-- Start Date repitition in "Date" and "Start_Time" columns
WITH start_dates AS (
 SELECT Date, CAST(Start_Time AS DATE) AS Start_Date 
 FROM line_productivity_batches) 
SELECT * FROM start_dates
WHERE Date != Start_Date;

-- DATA CLEANING AND TRANSFORMATION
-- HANDLE NULLS IN LINE DOWNTIME (UNPIVOT TABLE AND ENSURE CONSISTENCY IN FACTOR NAME IN RELATION TO THE DOWNTIME FACTORS TABLE)
CREATE VIEW downtimes AS 
SELECT Batch_ID, REPLACE(Factor, 'Factor_', '') as factor_id, Minutes FROM line_downtime
UNPIVOT(Minutes for factor in (Factor_1, Factor_2, Factor_3, Factor_4, Factor_5, Factor_6,
Factor_7, Factor_8, Factor_9, Factor_10, Factor_11, Factor_12, Factor_13)) AS Unpivotdowntimes;

Select * from downtimes
ORDER BY Batch_ID;

-- New batch prodcution table (date as start date, extract time from start start and end time)
create view batch_pd AS
  Select date as start_date, product_id, batch_id, operator, CAST(end_time as date) as end_date,
  CAST(Start_time as time) as start_time, CAST(end_time as time) as end_time, planned_min_batch_hours,
  DATEDIFF(hour, start_time, end_time) as actual_duration, 
  DATEDIFF(hour, start_time, end_time)-Planned_Min_Batch_Hours as extra_time_hr
  From line_productivity_batches

 SELECT * FROM batch_pd

 SELECT *, DATEDIFF(hour, start_time, end_time) as duration from line_productivity_batches

 -- Comparing accounted downtime minutes against extra time per batch
 select batch_pd.batch_id, sum(minutes) as accounted_delay_minutes, extra_time_hr FROM batch_pd
 JOIN downtimes ON batch_pd.Batch_ID = downtimes.Batch_ID
 group by batch_pd.Batch_ID, extra_time_hr;

 -- Analysis
 -- Downtime key factors
 select factor_name, COUNT(batch_id) as frequency, SUM(minutes) as delay_mins from downtimes
 join downtime_factors on downtimes.factor_id = downtime_factors.Factor_ID
 group by Factor_Name
 order by frequency desc;

 -- Operator vs non operator errors
 Select 
   case operator_error
      when 1 then 'yes'
      when 0 then 'no'
      end as operator_error,
      COUNT(batch_id) as frequency, SUM(minutes) as delay_mins from downtimes
join downtime_factors on  downtimes.factor_id = downtime_factors.Factor_ID
group by Operator_Error

-- downtime operator errors
select factor_name, description, COUNT(batch_id) as frequency, SUM(minutes) as delay_mins from downtimes
join downtime_factors on  downtimes.factor_id = downtime_factors.Factor_ID
where Operator_Error = 1
group by factor_name, Description
order by sum(minutes) desc;

-- downtime non operator errors
select factor_name, description, COUNT(batch_id) as frequency, SUM(minutes) as delay_mins from downtimes
join downtime_factors on  downtimes.factor_id = downtime_factors.Factor_ID
where Operator_Error = 0
group by factor_name, Description
order by sum(minutes) desc;

-- products and dowtimes frequency and delay (mins)
select batch_pd.product_id, product_name, count(downtimes.batch_id) as frequency, sum(minutes) as delay_mins from batch_pd
join downtimes on batch_pd.batch_id = downtimes.Batch_ID
join products on batch_pd.product_id = products.Product_ID
group by batch_pd.product_id, product_name

-- how many factors are invovled in each product downtime?
select batch_pd.product_id, product_name, COUNT(distinct factor_id) as distinct_factors_count from batch_pd
join products on batch_pd.product_id = products.Product_ID
join downtimes on batch_pd.batch_id = downtimes.batch_id
group by batch_pd. product_id, Product_Name

-- top 5 factors for product 1 downtime
select top 5 factor_name, sum(minutes) as prod001_delay_mins from downtimes
join downtime_factors on downtimes.factor_id = downtime_factors.Factor_ID
join batch_pd on batch_pd.batch_id = downtimes.Batch_ID
where product_id = 'prd001'
group by Factor_Name
order by sum(minutes) desc;


-- top 5 factors for product 2 downtime
select top 5 factor_name, sum(minutes) as prod002_delay_mins from downtimes
join downtime_factors on downtimes.factor_id = downtime_factors.Factor_ID
join batch_pd on batch_pd.batch_id = downtimes.Batch_ID
where product_id = 'prd002'
group by Factor_Name
order by sum(minutes) desc;


-- top 5 factors for product 3 downtime
select top 5 factor_name, sum(minutes) as prod003_delay_mins from downtimes
join downtime_factors on downtimes.factor_id = downtime_factors.Factor_ID
join batch_pd on batch_pd.batch_id = downtimes.Batch_ID
where product_id = 'prd003'
group by Factor_Name
order by sum(minutes) desc;


-- top 5 factors for product 4 downtime
select top 5 factor_name, sum(minutes) as prod004_delay_mins from downtimes
join downtime_factors on downtimes.factor_id = downtime_factors.Factor_ID
join batch_pd on batch_pd.batch_id = downtimes.Batch_ID
where product_id = 'prd004'
group by Factor_Name
order by sum(minutes) desc;

-- production lead operators
select operator, count(batch_id) as number_of_batches, count(distinct product_id) as number_of_products
from batch_pd
group by operator

-- production lead operator and downtime duration, perentage delayed batches
select Operator,
count(distinct batch_pd.batch_id) as total_batches,
   count(distinct downtimes.Batch_ID) as number_of_delayed_batches,
   count(downtimes.batch_id) as number_of_downtimes,
   sum(minutes) as delay_mins,
   cast((count(distinct downtimes.Batch_ID)*100.0)/(count(distinct batch_pd.batch_id)) as decimal(10,2)) 
   as percentage_delayed_batches
   from batch_pd
   left join downtimes on batch_pd.batch_id = Downtimes.batch_id
   group by operator
   order by percentage_delayed_batches desc

-- factors causing downtime for top 3 lead operators with the most delay duration
-- 1. paul
select factor_name, sum(Minutes) as delay_mins from downtime_factors
join downtimes on downtime_factors.Factor_ID = downtimes.factor_id
join batch_pd on batch_pd.batch_id = downtimes.Batch_ID
where operator = 'paul'
group by factor_name
order by sum(minutes) desc;

-- 2. James
select factor_name, sum(Minutes) as delay_mins from downtime_factors
join downtimes on downtime_factors.Factor_ID = downtimes.factor_id
join batch_pd on batch_pd.batch_id = downtimes.Batch_ID
where operator = 'james'
group by factor_name
order by sum(minutes) desc;

-- 3. Emily
select factor_name, sum(Minutes) as delay_mins from downtime_factors
join downtimes on downtime_factors.Factor_ID = downtimes.factor_id
join batch_pd on batch_pd.batch_id = downtimes.Batch_ID
where operator = 'emily'
group by factor_name
order by sum(minutes) desc;

-- Factors causing downtime for the top 3 operators with most percentage
-- delayed baatches
-- 1. Linda
select factor_name, sum(Minutes) as delay_mins from downtime_factors
join downtimes on downtime_factors.Factor_ID = downtimes.factor_id
join batch_pd on batch_pd.batch_id = downtimes.Batch_ID
where operator = 'Linda'
group by factor_name
order by sum(minutes) desc;

-- 2. Sophia
select factor_name, sum(Minutes) as delay_mins from downtime_factors
join downtimes on downtime_factors.Factor_ID = downtimes.factor_id
join batch_pd on batch_pd.batch_id = downtimes.Batch_ID
where operator = 'Sophia'
group by factor_name
order by sum(minutes) desc;

-- 3. Rita
select factor_name, sum(Minutes) as delay_mins from downtime_factors
join downtimes on downtime_factors.Factor_ID = downtimes.factor_id
join batch_pd on batch_pd.batch_id = downtimes.Batch_ID
where operator = 'Rita'
group by factor_name
order by sum(minutes) desc;