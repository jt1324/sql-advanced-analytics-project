# Advanced Sales Analytics – SQL

An advanced analysis of a retail sales dataset using **SQLite**. It covers trends over time, cumulative and performance metrics, segmentation, and two reusable report views for customers and products.

## Objective

Go beyond basic exploration to answer business questions such as:
- How do sales change over time?
- How is each product performing against its average and against the previous year?
- Which categories bring in the most revenue?
- How can customers and products be grouped into useful segments?

## Data Model

A **star schema** with one fact table and two dimension tables:

| Table | Type | Description |
|---|---|---|
| `fact_sales` | Fact | Sales transactions with order number, order date, quantity, price and sales amount |
| `dim_customers` | Dimension | Customer details such as name, birthdate and country |
| `dim_products` | Dimension | Product details such as name, category, subcategory and cost |

`fact_sales` links to the dimensions through `customer_key` and `product_key`.

## Analysis Steps

### 1. Changes Over Time
Orders, customers and sales:
- by year
- by month, with all years combined, to spot seasonal patterns
- by year and month

### 2. Cumulative Analysis
Monthly sales with a **running total** and a **running average price** that restart each year, using window functions.

### 3. Performance Analysis
Yearly sales for each product, compared against:
- **the product's own average**, flagged as *Above Avg*, *Below Avg* or *Same Avg*
- **the previous year**, using `LAG()` and flagged as *Increase*, *Decrease* or *No Changes*

### 4. Part-to-Whole Analysis
Each category's share of total sales, as a percentage.

### 5. Data Segmentation
- **Products by cost range**: Below 100, 101–500, 501–1000, Above 1000
- **Customers by spending and lifespan**:
  - **VIP**: at least 12 months of history and over 5,000 spent
  - **Regular**: at least 12 months of history and 5,000 or less spent
  - **New**: less than 12 months of history

### 6. Customer Report (`report_customers` view)
One row per customer with:
- name, age and age group
- customer segment (VIP, Regular or New)
- recency (months since the last order)
- total orders, sales, quantity and products
- lifespan in months
- average order value and average monthly spend

### 7. Product Report (`report_products` view)
One row per product with:
- name, category, subcategory and cost
- product segment (High-Performers, Mid-Range or Low-Performers)
- total orders, sales, quantity and customers
- recency and lifespan in months
- average selling price, average order revenue and average monthly revenue

## SQL Techniques Used

- CTEs, including chained and nested CTEs
- Window functions: `SUM() OVER`, `AVG() OVER`, `LAG()`, `ROW_NUMBER()`
- `CASE` expressions for segmentation and flags
- Date handling with `strftime`, `julianday` and `date('now')`
- Safe division with `NULLIF` and `CASE`
- `NULL` handling with `COALESCE` and `TRIM`
- `CREATE VIEW` for reusable reports

## How to Run

1. Import the CSV files into a SQLite database:
   ```
   sqlite3 sales.db
   .mode csv
   .import dim_customers.csv dim_customers
   .import dim_products.csv dim_products
   .import fact_sales.csv fact_sales
   ```
2. Run the script from PowerShell:
   ```
   Get-Content main.sql | sqlite3 -header -column sales.db
   ```
3. Query the reports:
   ```sql
   SELECT * FROM report_customers;
   SELECT * FROM report_products;
   ```

## Key Skills Demonstrated

- Analysing trends and performance over time
- Segmenting customers and products for business decisions
- Building reusable reporting layers with views
- Writing advanced SQL in SQLite
