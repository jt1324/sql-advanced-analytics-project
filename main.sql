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
    SUM(total_sales) OVER(PARTITION BY year ORDER BY year, month) AS running_total_sales,
    AVG(avg_price) OVER(PARTITION BY year ORDER BY year, month) AS moving_avg_price
FROM (
    SELECT
        strftime('%Y', order_date) AS year,
        strftime('%m', order_date) AS month,
        SUM(sales_amount) AS total_sales,
        AVG(price) AS avg_price
    FROM fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY strftime('%Y', order_date),  strftime('%m', order_date)
);


-- Performance analysis

WITH yearly_prod_sales AS (
    SELECT
        strftime('%Y', s.order_date) AS year,
        SUM(s.sales_amount) AS current_sales,
        p.product_name
    FROM fact_sales s
        LEFT JOIN dim_products p
            ON s.product_key = p.product_key
    WHERE s.order_date IS NOT NULL
    GROUP BY  strftime('%Y', s.order_date), p.product_name
)
SELECT
    year,
    product_name,
    current_sales,
    AVG(current_sales) OVER(PARTITION BY product_name) AS avg_sales,
    (current_sales - AVG(current_sales) OVER(PARTITION BY product_name)) AS variance_avg,
    CASE
        WHEN (current_sales - AVG(current_sales) OVER(PARTITION BY product_name)) > 0 THEN 'Above Avg'
        WHEN (current_sales - AVG(current_sales) OVER(PARTITION BY product_name)) < 0 THEN 'Below Avg'
        ELSE 'Same Avg'
    END AS avg_var_indicator,
    LAG(current_sales) OVER(PARTITION BY product_name ORDER BY year) AS prev_year_sales,
    (current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY year)) AS variance_prev_year_sales,
    CASE
        WHEN (current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY year)) > 0 THEN 'Increase'
        WHEN (current_sales - LAG(current_sales) OVER(PARTITION BY product_name ORDER BY year)) < 0 THEN 'Decrease'
        ELSE 'No Changes'
    END AS prev_year_sale_var_indicator
FROM yearly_prod_sales
ORDER BY product_name, year;


-- Part-to-whole analysis

WITH category AS (
    SELECT
        p.category,
        SUM(s.sales_amount) AS total_sales,
        ROW_NUMBER() OVER( ORDER BY 
            SUM(s.sales_amount) DESC
        ) AS rn
    FROM fact_sales s
        LEFT JOIN dim_products p
            ON p.product_key = s.product_key
    GROUP BY category
)
SELECT
    category,
    printf('%,d', total_sales) AS total_sales,
    printf('%,d', SUM(total_sales) OVER()) AS overal_sales,
    CONCAT(ROUND((CAST(total_sales AS FLOAT) / SUM(total_sales) OVER()) * 100, 2), '%') AS pct_total
FROM category
ORDER BY rn;