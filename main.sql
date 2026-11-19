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


-- Data segmentation
-- Volume by cost range

WITH prod_segments AS (
    SELECT
        product_key,
        product_name,
        cost,
        CASE
            WHEN cost <= 100 THEN 'Below 100'
            WHEN cost <= 500 THEN '101-500'
            WHEN cost <= 1000 THEN '501-1000'
            ELSE 'Above 1000'
        END AS cost_range
    FROM dim_products
)
SELECT
    cost_range,
    COUNT(product_key) AS total_products
FROM prod_segments
GROUP BY cost_range
ORDER BY COUNT(product_key) DESC;

-- Customer segmentation by purchases

WITH cust_segment AS (
    WITH cust_orders AS (
        SELECT
            c.customer_key,
            SUM(s.sales_amount) AS total_purchase,
            MIN(order_date) AS first_order,
            MAX(order_date) AS last_order,
            (CAST(strftime('%Y', MAX(order_date)) AS INTEGER) * 12 + CAST(strftime('%m', MAX(order_date)) AS INTEGER))
            - (CAST(strftime('%Y', MIN(order_date)) AS INTEGER) * 12 + CAST(strftime('%m', MIN(order_date)) AS INTEGER)) AS lifespan
        FROM fact_sales s
            LEFT JOIN dim_customers c
                ON c.customer_key = s.customer_key
        GROUP BY c.customer_key
    )
    SELECT
        customer_key,
        total_purchase,
        lifespan,
        CASE
            WHEN lifespan >= 12 AND total_purchase > 5000 THEN 'VIP'
            WHEN lifespan >= 12 AND total_purchase <= 5000 THEN 'Regular'
            ELSE 'New'
        END AS customer_segment
    FROM cust_orders
)
SELECT
    customer_segment,
    printf('%,d', COUNT(customer_key)) AS qty_customers
FROM cust_segment
GROUP BY customer_segment
ORDER BY COUNT(customer_key) DESC;


-- Build customer report

DROP VIEW IF EXISTS report_customers;

CREATE VIEW report_customers AS 
WITH base_query AS (
    SELECT
        s.order_number,
        s.product_key,
        s.order_date,
        s.quantity,
        s.sales_amount,
        c.customer_key,
        c.customer_number,
        TRIM(COALESCE(c.first_name, '') || ' ' || COALESCE(c.last_name, '')) AS customer_name,
        CAST((julianday('now') - julianday(c.birthdate)) / 365.25 AS INTEGER) AS age
    FROM fact_sales s
        LEFT JOIN dim_customers c
            ON s.customer_key = c.customer_key
    WHERE s.order_date IS NOT NULL
) , customer_aggregation AS (

    SELECT
        customer_key,
        customer_number,
        customer_name,
        age,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT product_key) AS total_products,
        MAX(order_date) AS last_order_date,
        (CAST(strftime('%Y', MAX(order_date)) AS INTEGER) * 12 + CAST(strftime('%m', MAX(order_date)) AS INTEGER))
        - (CAST(strftime('%Y', MIN(order_date)) AS INTEGER) * 12 + CAST(strftime('%m', MIN(order_date)) AS INTEGER)) AS lifespan
    FROM base_query
    GROUP BY customer_key, customer_number, customer_name, age
)
SELECT
    customer_key,
    customer_number,
    customer_name,
    age,
    CASE
        WHEN age < 20 THEN 'Under 20'
        WHEN age < 29 THEN '20-30'
        WHEN age < 39 THEN '30-40'
        WHEN age < 49 THEN '40-50'
        ELSE '50 and Above'
    END AS age_rage,
    CASE
        WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,
    (CAST(strftime('%Y', 'now') AS INTEGER) * 12 + CAST(strftime('%m', 'now') AS INTEGER))
    - (CAST(strftime('%Y', last_order_date) AS INTEGER) * 12 + CAST(strftime('%m', last_order_date) AS INTEGER)) AS recency,
    total_orders,
    total_sales,
    total_quantity,
    total_products,
    lifespan,
    CASE 
        WHEN total_sales = 0 THEN 0
        ELSE total_sales / total_orders 
    END AS avg_order_value,
    CASE 
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan 
    END AS avg_monthly_spend
FROM customer_aggregation;


SELECT
    *
FROM report_customers;


-- Build product report

DROP VIEW IF EXISTS report_products;

CREATE VIEW report_products AS 
WITH prod_data AS (
    SELECT
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost,
        s.order_number,
        s.order_date,
        s.quantity,
        s.sales_amount,
        s.customer_key
    FROM fact_sales s
        LEFT JOIN dim_products p
            ON s.product_key = p.product_key
    WHERE order_date IS NOT NULL
), product_aggregation AS (
SELECT
    product_key,
    product_name,
    category,
    subcategory,
    cost,
    COUNT(DISTINCT order_number) AS total_orders,
    SUM(sales_amount) AS total_sales,
    SUM(quantity) AS total_quantity,
    COUNT(DISTINCT customer_key) AS total_customers,
    MAX(order_date) AS last_order_date,
    (CAST(strftime('%Y', MAX(order_date)) AS INTEGER) * 12 + CAST(strftime('%m', MAX(order_date)) AS INTEGER))
    - (CAST(strftime('%Y', MIN(order_date)) AS INTEGER) * 12 + CAST(strftime('%m', MIN(order_date)) AS INTEGER)) AS lifespan,
    ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity, 0)),1) AS avg_selling_price
FROM prod_data
GROUP BY  product_key, product_name, category, subcategory
)
SELECT
    product_key,
    product_name,
    category,
    subcategory,
    total_cost,
    total_orders,
    total_sales,
    total_quantity,
    total_customers,
    CASE
        WHEN total_sales > 100000 THEN 'High-Performers'
        WHEN total_sales > 50000 THEN 'Mid-Range'
        ELSE 'Low-Performers'
    END AS product_segment,
    (CAST(strftime('%Y', 'now') AS INTEGER) * 12 + CAST(strftime('%m', 'now') AS INTEGER))
    - (CAST(strftime('%Y', last_order_date) AS INTEGER) * 12 + CAST(strftime('%m', last_order_date) AS INTEGER)) AS recency,
    CASE 
        WHEN total_sales = 0 THEN 0
        ELSE total_sales / total_orders 
    END AS avg_order_value,
    CASE 
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan 
    END AS avg_monthly_spend,
    CASE 
        WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders 
    END AS avg_order_revenue,
    lifespan,
    avg_selling_price
FROM product_aggregation;