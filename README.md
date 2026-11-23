# Advanced Sales Analytics – SQL & Power BI

An advanced analysis of a retail bike sales dataset using **SQLite**, with the results visualised in an interactive **Power BI** dashboard. It covers trends over time, cumulative and performance metrics, segmentation, and two reusable report views for customers and products.

## Dashboard Preview

![Power BI Products Dashboard](Power%20BI%20-%20Products.png)

## Objective

Go beyond basic exploration to answer business questions such as:
- How do sales change over time?
- How is each product performing against its average and against the previous year?
- Which categories bring in the most revenue?
- How can customers and products be grouped into useful segments?

## Repository Contents

| File | Description |
|---|---|
| `main.sql` | The full analysis script, including the report views |
| `db.sql` | Database setup script |
| `datawarehouseanalytics.db` | SQLite database with the loaded data |
| `Bike Business.pbix` | Power BI dashboard file |
| `Power BI - Products.png` | Screenshot of the dashboard |
| `sql-advanced-analytics-project/` | Source datasets (CSV), step-by-step scripts and project docs |

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

## Power BI Dashboard

The `Bike Business.pbix` dashboard is built on top of the SQL report views and gives a one-page view of product performance.

**KPI cards**
- Products sold: **60K**
- Total sales: **£29M**
- Total customers: **59K**
- Average price: **£1.1K**
- Average cost: **£662**

**Visuals**
- **Sales per segment**: a donut chart splitting sales across High-Performers, Mid-Range and Low-Performers
- **Sales quantity**: a bar chart comparing Bikes, Accessories and Clothing
- **Sales per category / subcategory**: a matrix with drill-down from category to subcategory
- **Customers by subcategory**: a treemap showing which subcategories reach the most customers

**Key insights**
- **Bikes** bring in about **£28.3M** of the **£29.4M** total, around 96% of all revenue. Road Bikes alone account for £14.5M.
- **Accessories** (£0.7M) and **Clothing** (£0.34M) sell in smaller amounts, but they reach the widest customer base. *Tires and Tubes*, *Bottles and Cages* and *Helmets* lead the customer count.
- This points to a business where bikes drive revenue and low-cost accessories drive customer reach, which makes accessories a natural entry point for cross-selling.

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
4. Open `Bike Business.pbix` in **Power BI Desktop** to explore the dashboard.

## Key Skills Demonstrated

- Analysing trends and performance over time
- Segmenting customers and products for business decisions
- Building reusable reporting layers with views
- Writing advanced SQL in SQLite
- Building interactive dashboards and KPIs in Power BI
- Turning analysis into clear business insights
