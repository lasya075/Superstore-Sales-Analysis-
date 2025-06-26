SHOW DATABASES;

USE sales_app;

SELECT * FROM sales_data;

-- Q1) What percentage of total orders were shipped on the same date?

SELECT ((COUNT(DISTINCT Row_ID)*100)/(SELECT COUNT(DISTINCT Row_ID) FROM sales_data)) AS Samedayshipping_percentage
FROM sales_data
WHERE Order_Date = Ship_Date;

-- Q2) Name top 3 customers with highest total value of orders?

SELECT Customer_Name, SUM(Sales)
FROM sales_data
GROUP BY Customer_Name
ORDER BY SUM(Sales) DESC
LIMIT 3;

-- Q3) Find the top 5 items with the highest average sales per day?

SELECT Product_Name, AVG(Daily_Sales) AS Avg_Daily_Sales
FROM (
    SELECT Order_Date, Product_Name, SUM(Sales) AS Daily_Sales
    FROM sales_data
    GROUP BY Order_Date, Product_Name
) AS Sales_per_day
GROUP BY Product_Name
ORDER BY Avg_Daily_Sales DESC
LIMIT 5;

-- Q4) Write a query to find the average order value for each customer, and rank the customers by their average order value? 

SELECT Customer_ID, Customer_Name, Avg_order_value, RANK() OVER(ORDER BY Avg_order_value DESC) as Customer_Rank
FROM(
SELECT Customer_ID, Customer_Name, AVG(Sales) AS Avg_order_value
FROM sales_data
GROUP BY Customer_ID, Customer_Name
) AS Customer_avg_order_values;

-- Q5) Give the name of customers who ordered highest and lowest orders from each city?

WITH Number_of_orders AS (
    SELECT 
        City, 
        Customer_ID, 
        Customer_Name, 
        COUNT(DISTINCT Row_ID) AS Orders_per_cus
    FROM sales_data
    GROUP BY City, Customer_ID, Customer_Name
),

Max_orders AS (
    SELECT 
        City, 
        Customer_Name AS Highest_orders_cus, 
        Orders_per_cus AS Highest_orders
    FROM Number_of_orders
    WHERE (City, Orders_per_cus) IN (
        SELECT City, MAX(Orders_per_cus)
        FROM Number_of_orders
        GROUP BY City
    )
),

Min_orders AS (
    SELECT 
        City, 
        Customer_Name AS Lowest_orders_cus, 
        Orders_per_cus AS Lowest_orders
    FROM Number_of_orders
    WHERE (City, Orders_per_cus) IN (
        SELECT City, MIN(Orders_per_cus)
        FROM Number_of_orders
        GROUP BY City
    )
)

SELECT 
    max.City,
    Highest_orders_cus,
    Highest_orders,
    Lowest_orders_cus,
    Lowest_orders
FROM Max_orders AS max
JOIN Min_orders AS min
ON max.City = min.City;


-- Q6) What is the most demanded sub-category in the west region?

SELECT Sub_Category, COUNT(Row_ID) AS Demand_of_sub_category
FROM sales_data
WHERE Region = "West"
GROUP BY Sub_Category
ORDER BY Demand_of_sub_category DESC
LIMIT 1;

-- Q7) Which order has the highest number of items? 

SELECT Order_ID, COUNT(Row_ID) AS Highest_items
FROM sales_data
GROUP BY Order_ID
ORDER BY Highest_items DESC
LIMIT 1;

-- Q8) Which order has the highest cumulative value?

SELECT Order_ID, SUM(Sales) AS Highest_cum_value
FROM sales_data
GROUP BY Order_ID
ORDER BY Highest_cum_value DESC
LIMIT 1;

-- Q9) Which segment’s order is more likely to be shipped via first class?

SELECT Segment, Ship_Mode, COUNT(Row_ID) AS max_first_class_shipments
FROM sales_data 
WHERE Ship_Mode = "First Class"
GROUP BY Segment, Ship_Mode
ORDER BY max_first_class_shipments DESC
LIMIT 1;

-- Q10) Which city is least contributing to total revenue?

SELECT City, SUM(Sales) AS least_sales
FROM sales_data
GROUP BY City
ORDER BY least_sales
LIMIT 1;

-- Q11) What is the average time for orders to get shipped after order is placed?

SELECT AVG(Time_to_ship) AS Average_time_to_ship
FROM (SELECT DATEDIFF(Ship_Date,Order_Date) AS Time_to_ship
FROM sales_data) AS daystoship;

/* Q12) Which segment places the highest number of orders from each state 
		and which segment places the largest individual orders from each state? */

WITH Ranked_orders AS (
    SELECT 
        State, 
        Segment, 
        COUNT(DISTINCT Order_ID) AS no_of_orders,
        RANK() OVER (PARTITION BY State ORDER BY COUNT(DISTINCT Order_ID) DESC) AS rnk
    FROM sales_data
    GROUP BY State, Segment
)

SELECT 
    State, 
    Segment, 
    no_of_orders
FROM Ranked_orders
WHERE rnk = 1;

WITH Ranked_indiv_orders AS
(SELECT Segment,State,Order_ID,SUM(Sales) AS indiv_orders,RANK() OVER (PARTITION BY State ORDER BY SUM(Sales) DESC) AS rnk
FROM sales_data
GROUP BY Segment,State,Order_ID)

SELECT State,Segment,Order_ID,indiv_orders
FROM Ranked_indiv_orders
WHERE rnk=1;

/* Q13) Find all the customers who individually ordered on 3 consecutive days 
		where each day’s total order was more than 50 in value?*/

WITH customer_daily_sales AS (
    SELECT 
        Customer_ID,
        Order_Date,
        SUM(Sales) AS daily_sales
    FROM sales_data
    GROUP BY Customer_ID, Order_Date
),

filtered_sales AS (
    SELECT 
        Customer_ID,
        Order_Date,
        daily_sales
    FROM customer_daily_sales
    WHERE daily_sales > 50
),

ranked_orders AS (
    SELECT 
        Customer_ID,
        Order_Date,
        ROW_NUMBER() OVER (PARTITION BY Customer_ID ORDER BY Order_Date) AS rn
    FROM filtered_sales
),

streaks AS (
    SELECT 
        f1.Customer_ID,
        f1.Order_Date AS Day1,
        f2.Order_Date AS Day2,
        f3.Order_Date AS Day3
    FROM ranked_orders f1
    JOIN ranked_orders f2 
        ON f1.Customer_ID = f2.Customer_ID AND f2.rn = f1.rn + 1
    JOIN ranked_orders f3 
        ON f1.Customer_ID = f3.Customer_ID AND f3.rn = f1.rn + 2
    WHERE 
        DATEDIFF(f2.Order_Date, f1.Order_Date) = 1
        AND DATEDIFF(f3.Order_Date, f2.Order_Date) = 1
)

SELECT DISTINCT Customer_ID
FROM streaks;


-- Q14) Find the maximum number of days for which total sales on each day kept rising?

SET @streak := 0;
SET @max_streak := 0;
SET @prev_sales := NULL;
SET @prev_date := NULL;

SELECT MAX(streak) AS max_consecutive_rising_days
FROM (
    SELECT 
        Order_Date,
        daily_sales,
        
        -- Calculate streak
        @streak := IF(
            @prev_date IS NULL 
            OR DATEDIFF(Order_Date, @prev_date) != 1 
            OR daily_sales <= @prev_sales, 
            1, 
            @streak + 1
        ) AS streak,
        
        -- Update trackers
        @prev_sales := daily_sales,
        @prev_date := Order_Date
        
    FROM (
        SELECT 
            Order_Date,
            SUM(Sales) AS daily_sales
        FROM sales_data
        GROUP BY Order_Date
        ORDER BY Order_Date
    ) AS daily_totals
) AS tracked_streaks;

