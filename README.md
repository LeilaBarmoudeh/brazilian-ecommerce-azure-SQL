# brazilian-ecommerce-Azure-SQL
Built a bronze-silver-gold data pipeline for the Olist Brazilian E-Commerce dataset using Azure SQL.

# Project overview
This project builds a cleaned and analytics-ready gold layer from the Brazilian E-Commerce Public Dataset by Olist using Azure SQL.

The pipeline follows a medallion-style approach:
Bronze: raw ingested tables
Silver: cleaned and standardized tables
Gold: business-ready analytical tables

# Objectives
1. Clean raw Olist dataset tables
2. Standardize data types and formats
3. handle missing values and duplicates
4. create trusted gold tables for analytics and reporting
5. document SQL transformations clearly

# Dataset
Source dataset: Brazilian E-Commerce Public Dataset by Olist
Main entities include:
- customers
- orders
- order items
- payments
- products
- sellers
- reviews
- geolocation

# Tech stack
- Azure SQL
- SQL
- GitHub for version control and documentation

# Transformation steps

# Bronze
Raw tables were loaded into Azure SQL with minimal changes.

# Silver
Cleaning and standardization steps included:
- removing duplicates
- fixing null values where needed
- standardizing column names
- converting data types
- validating keys and joins
- handling inconsistent records

# Gold
Gold tables were created for analytics use cases such as:
- sales performance
- customer behavior
- delivery performance
- seller analysis
- payment trends

# Example gold tables
- gold_orders
- gold_customers
- gold_sales_summary
- gold_delivery_metrics
- Data quality checks

# Examples of implemented checks:
- duplicate order IDs
- null primary keys
- invalid payment values
- inconsistent delivery dates
- orphan foreign keys

# Example query
SELECT
    customer_state,
    COUNT(DISTINCT order_id) AS total_orders,
    SUM(payment_value) AS total_revenue
FROM gold_sales_summary
GROUP BY customer_state
ORDER BY total_revenue DESC;









