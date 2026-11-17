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

-- Metrics by month (all years together)

WITH month AS (
    SELECT
        strftime('%m', order_date) AS order_month,
        quantity,
        sales_amount
    FROM fact_sales
    WHERE order_date IS NOT NULL
)
    SELECT
        order_month,
        printf('%,d', COUNT(quantity)) AS qty_orders,
        printf('%,d', SUM(sales_amount)) AS total_sales
    FROM month
GROUP BY order_month;

-- Metrics by year & month

WITH year_month AS (
    SELECT
        strftime('%Y', order_date) AS order_year,
        strftime('%m', order_date) AS order_month,
        customer_key,
        quantity,
        sales_amount
    FROM fact_sales
    WHERE order_date IS NOT NULL
)
    SELECT
        order_year,
        order_month,
        printf('%,d', COUNT(DISTINCT(customer_key))) AS qty_customers,
        printf('%,d', COUNT(quantity)) AS qty_orders,
        printf('%,d', SUM(sales_amount)) AS total_sales
    FROM year_month
GROUP BY order_year, order_month;


-- Cumulative analysis

SELECT
    year,
    month,
    total_sales,
    SUM(total_sales) OVER(ORDER BY year, month) AS running_total_sales
FROM (
    SELECT
        strftime('%Y', order_date) AS year,
        strftime('%m', order_date) AS month,
        SUM(sales_amount) AS total_sales
    FROM fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY strftime('%Y', order_date),  strftime('%m', order_date)
);