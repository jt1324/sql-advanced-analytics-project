-- Checking data

SELECT
    *
FROM dim_customers
LIMIT 100;

SELECT
    *
FROM dim_products
LIMIT 100;

SELECT
    *
FROM FACT_sales
LIMIT 100;


-- Changes over time analysis

-- Metrics by year

WITH year AS (
    SELECT
        strftime('%Y', order_date) AS order_year,
        quantity,
        sales_amount
    FROM fact_sales
    WHERE order_date IS NOT NULL
)
    SELECT
        order_year,
        printf('%,d', COUNT(quantity)) AS qty_orders,
        printf('%,d', SUM(sales_amount)) AS total_sales
    FROM year
GROUP BY order_year;