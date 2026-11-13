------------------------------------------------------------------------
-- ٌFRM -----------------------------------------------------------------
------------------------------------------------------------------------
With RFM as (
select
	c.CustomerKey,
	SUM(p.[Profit USD]*S.Quantity) as Monetry,
	Count(distinct [Order Number]) as Frequencey,
	max(S.[Order Date]) as last_Customer_order,
	max(max([Order Date]))over() as last_order
from Customers$ C join Sales$ S 
on C.CustomerKey=S.CustomerKey
left join Products$ p on S.ProductKey=p.ProductKey
group by C.CustomerKey
),Recency as(
Select *,
DATEDIFF(DAY,last_Customer_order,last_order) as Recency
from RFM
),Scores as(
select *,
	NTILE(5)over(order by Recency Desc) AS R,
	Case 
         when Frequencey = 1 Then 1
		 when Frequencey= 2 Then 2
         when Frequencey =3 Then 3
         when Frequencey = 4 Then 4
		 Else 5 end as F ,
    NTILE(5)over(order by Monetry) As M
from Recency
),Segmants as(
SELECT *,
    CASE
        when R >= 4 AND F >= 4 Then 'Champions'
        when R = 1  AND F >= 4 Then 'Cant Lose Them'
        when R <= 2 AND F >= 3 Then 'At Risk'
        when F >= 4            Then 'Loyal'
        when R >= 3 AND F IN (2,3) Then 'Potential Loyalist'
        when R >= 4 AND F = 1  Then 'New Customers'
        when R = 3  AND F = 1  Then 'Promising'
        when R = 2             Then 'About to Sleep'
        when R = 1             Then 'Churn'
        ELSE 'Other'
    END AS Segment
FROM Scores
), CTE as(
select *,
    case
        when Segment ='Champions' then 1
        when Segment='Loyal' then 2
        when Segment='Potential Loyalist' then 3
        when Segment= 'Cant Lose Them' then 4
        when Segment= 'Promising' then 5
        when Segment='New Customers' then 6
        when Segment= 'About to Sleep' then 7
        when Segment='At Risk' then 8
        when Segment='Churn' then 9
        Else 10 End As Ranking
from Segmants
)
select 
    Count(Case when Ranking = 1 then 1 end) AS Champion,
    Count(Case when Ranking = 2 then 1 end) AS Loyal,
    Count(Case when Ranking = 3 then 1 end) AS Potential_Loyalist,
    Count(Case when Ranking = 4 then 1 end) AS [Cant Lose Them],
    Count(Case when Ranking = 5 then 1 end) AS Promising,
    Count(Case when Ranking = 6 then 1 end) AS [New Customers],
    Count(Case when Ranking = 7 then 1 end) AS [About to Sleep],
    Count(Case when Ranking = 8 then 1 end) AS [At Risk],
    Count(Case when Ranking = 9 then 1 end) AS Churn,
    Count(Case when Ranking = 10 then 1 end) AS [Other]
from CTE;


------------------------------------------------------------------------
-- CLV -----------------------------------------------------------------
------------------------------------------------------------------------
WITH CLV AS (
    SELECT
        c.CustomerKey,
        SUM(p.[Profit USD] * s.Quantity)      AS CLV_Profit,
        SUM(p.[Unit Price USD] * s.Quantity)  AS CLV_Revenue,
        COUNT(DISTINCT s.[Order Number])      AS Orders,
        MIN(s.[Order Date])                   AS First_Order,
        MAX(s.[Order Date])                   AS Last_Order
    FROM Customers$ c
    JOIN Sales$ s    ON c.CustomerKey = s.CustomerKey
    JOIN Products$ p ON s.ProductKey  = p.ProductKey
    GROUP BY c.CustomerKey
)
SELECT *,
    NTILE(3) OVER (ORDER BY CLV_Profit, CustomerKey) AS CLV_Tier,
    CASE NTILE(3) OVER (ORDER BY CLV_Profit, CustomerKey)
        WHEN 1 THEN 'Low'
        WHEN 2 THEN 'Medium'
        WHEN 3 THEN 'High'
    END AS CLV_Segment
FROM CLV;
------------------------------------------------------------------------
-- Cohrot --------------------------------------------------------------
------------------------------------------------------------------------
With Formating as (
select C.CustomerKey,
    DATEFROMPARTS(YEAR(S.[Order Date]),MONTH(S.[Order Date]),1) as Order_Month
from Customers$ C join Sales$ S 
on C.CustomerKey=S.CustomerKey
),Cohrot as(
    SELECT *,
      MIN(Order_Month)over(partition by CustomerKey) AS Cohort_Month
    FROM Formating
),Months as (
Select *,
    DATEDIFF(Month,Cohort_Month,Order_Month) AS [Month Number]
from Cohrot
),Agg as(
select Cohort_Month,
       [Month Number],
       count(Distinct CustomerKey) as [Total Cutomers]
From Months
Group by Cohort_Month,[Month Number]
)
SELECT
    Cohort_Month,
    [Month Number],
    [Total Cutomers],
    CAST(100.0 * [Total Cutomers] /FIRST_VALUE([Total Cutomers]) 
         OVER (PARTITION BY Cohort_Month  ORDER BY [Month Number])
         AS DECIMAL(5,2)) AS Retention_Pct
FROM Agg
order by Cohort_Month ;
------------------------------------------------------------------------
-- Percentage contribution of each subcategory  ------------------------
------------------------------------------------------------------------
with subs as (
select P.Subcategory,
sum(P.[Profit USD]*S.Quantity) as [Total Profit],
sum(p.[Unit Price USD]*S.Quantity)as [Total Revenue],
count(distinct S.[Order Number]) as [Total Orders]
from Products$ P join Sales$ S
on P.ProductKey=S.ProductKey
Group by P.Subcategory
),totals as(
select sum(P.[Profit USD]*S.Quantity)as [Total],
        sum(P.[Unit Price USD]*S.Quantity) as [Totals]
from Products$ P join Sales$ S
on P.ProductKey=S.ProductKey
)
select s.Subcategory,
     s.[Total Orders],
     s.[Total Profit],s.[Total Revenue],
     Round((s.[Total Profit]/t.Total),6)as [Profit PCT],
     Round((s.[Total Revenue]/t.Totals),6) as [Revenue PCT]
from subs s cross join totals t
order by [Profit PCT] desc,[Revenue PCT] desc
------------------------------------------------------------------------
-- Percentage contribution of each Brand  ------------------------------
------------------------------------------------------------------------
with Brands as (
select P.Brand,
sum(P.[Profit USD]*S.Quantity) as [Total Profit],
sum(p.[Unit Price USD]*S.Quantity)as [Total Revenue],
count(distinct S.[Order Number]) as [Total Orders]
from Products$ P join Sales$ S
on P.ProductKey=S.ProductKey
Group by P.Brand
),totals as(
select sum(P.[Profit USD]*S.Quantity)as [Total],
        sum(P.[Unit Price USD]*S.Quantity) as [Totals]
from Products$ P join Sales$ S
on P.ProductKey=S.ProductKey
)
select b.Brand,
     b.[Total Orders],
     b.[Total Profit],b.[Total Revenue],
     Round((b.[Total Profit]/t.Total),6)as [Profit PCT],
     Round((b.[Total Revenue]/t.Totals),6) as [Revenue PCT]
from Brands b cross join totals t
order by [Profit PCT] desc,[Revenue PCT] desc
------------------------------------------------------------------------
-- Top 10 Products -----------------------------------------------------
------------------------------------------------------------------------
with products as(
select P.ProductKey,
sum(P.[Profit USD]*S.Quantity) as [Total Profit],
count(distinct S.[Order Number]) as [Total Orders]
from Products$ P join Sales$ S
on P.ProductKey=S.ProductKey
group by P.ProductKey
), ranking as(
select *,DENSE_RANK()over(order by [Total Profit] desc,[Total Orders] desc) as RK 
from products
)
select * from ranking
where RK<=10
order by RK
------------------------------------------------------------------------
-- Bottom 10 Products --------------------------------------------------
------------------------------------------------------------------------
with products as(
select P.ProductKey,
sum(P.[Profit USD]*S.Quantity) as [Total Profit],
count(distinct S.[Order Number]) as [Total Orders]
from Products$ P join Sales$ S
on P.ProductKey=S.ProductKey
group by P.ProductKey
), ranking as(
select *,DENSE_RANK()over(order by [Total Profit] ,[Total Orders] ) as RK 
from products
)
select * from ranking
where RK<=10
order by RK
------------------------------------------------------------------------
-- Percentage contribution of each color in each Subcategory -----------
------------------------------------------------------------------------
with color_stats as(
select P.Subcategory,
       P.Color,
       sum(P.[Profit USD]*S.Quantity) as [Total Profit],
       sum(P.[Unit Price USD]*S.Quantity) as [Total Revenue]
from Products$ P join Sales$ S
on P.ProductKey=S.ProductKey
group by P.Subcategory,P.Color
)
select Subcategory,
       Color,
       [Total Profit],
       [Total Revenue],
       Round([Total Profit]/sum([Total Profit])over(partition by Subcategory),6) as [Profit PCT],
       Round([Total Revenue]/sum([Total Revenue])over(partition by Subcategory),6) as [Revenue PCT]
from color_stats
order by Subcategory,[Revenue PCT] desc
------------------------------------------------------------------------
-- Top 10 Stores -------------------------------------------------------
------------------------------------------------------------------------
with store_profit as(
select S.StoreKey,
       sum(S.Quantity*P.[Profit USD]) as [Total Profit]
from Sales$ S join Products$ P
on S.ProductKey=P.ProductKey
group by S.StoreKey
), store_years as(
select StoreKey,
       State,
       DATEDIFF(DAY,[Open Date],'2020-01-01')/365.25 as [Years Open]
from Stores$
), ranking as(
select y.StoreKey,
       y.State,
       y.[Years Open],
       p.[Total Profit],
       p.[Total Profit]/y.[Years Open] as [Avg Profit Per Year],
       DENSE_RANK()over(order by p.[Total Profit]/y.[Years Open] desc) as RK
from store_profit p join store_years y
on p.StoreKey=y.StoreKey
)
select * from ranking
where RK<=10
order by RK
------------------------------------------------------------------------
-- Bottom 10 Stores ----------------------------------------------------
------------------------------------------------------------------------
with store_profit as(
select S.StoreKey,
       sum(S.Quantity*P.[Profit USD]) as [Total Profit]
from Sales$ S join Products$ P
on S.ProductKey=P.ProductKey
group by S.StoreKey
), store_years as(
select StoreKey,
       State,
       DATEDIFF(DAY,[Open Date],'2020-01-01')/365.25 as [Years Open]
from Stores$
), ranking as(
select y.StoreKey,
       y.State,
       y.[Years Open],
       p.[Total Profit],
       p.[Total Profit]/y.[Years Open] as [Avg Profit Per Year],
       DENSE_RANK()over(order by p.[Total Profit]/y.[Years Open]) as RK
from store_profit p join store_years y
on p.StoreKey=y.StoreKey
)
select * from ranking
where RK<=10
order by RK