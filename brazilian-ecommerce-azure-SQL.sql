
USE olist;
GO

CREATE OR ALTER VIEW bronze_orders AS
SELECT *
FROM OPENROWSET(
    BULK 'https://stolistleila2026.blob.core.windows.net/bronze/olist/raw/olist_orders_dataset.csv',
    FORMAT = 'CSV',
    PARSER_VERSION = '2.0',
    FIRSTROW = 2
) AS o;
GO

USE olist;
GO

CREATE OR ALTER VIEW silver_orders AS
SELECT
    o.[C1]  AS order_id,
    o.[C2]  AS customer_id,
    o.[C3]  AS order_status,

    TRY_CONVERT(datetime2, o.[C4]) AS order_purchase_ts,
    TRY_CONVERT(datetime2, o.[C5]) AS order_approved_ts,
    TRY_CONVERT(datetime2, o.[C6]) AS order_delivered_carrier_ts,
    TRY_CONVERT(datetime2, o.[C7]) AS order_delivered_customer_ts,
    TRY_CONVERT(datetime2, o.[C8]) AS order_estimated_delivery_ts,

    CASE
        WHEN TRY_CONVERT(datetime2, o.[C7]) IS NOT NULL
         AND TRY_CONVERT(datetime2, o.[C8]) IS NOT NULL
         AND TRY_CONVERT(datetime2, o.[C7]) > TRY_CONVERT(datetime2, o.[C8])
        THEN 1 ELSE 0
    END AS is_late_delivery
FROM bronze_orders o;
GO

SELECT COUNT(*) AS row_count
FROM silver_orders;

-- quality check
SELECT
  COUNT(*) AS total_orders,
  SUM(CASE WHEN order_purchase_ts IS NULL THEN 1 ELSE 0 END) AS bad_purchase_dates,
  SUM(is_late_delivery) AS late_deliveries
FROM silver_orders;

USE olist;
GO

CREATE OR ALTER VIEW bronze_order_items AS
SELECT *
FROM OPENROWSET(
    BULK 'https://stolistleila2026.blob.core.windows.net/bronze/olist/raw/olist_order_items_dataset.csv',
    FORMAT = 'CSV',
    PARSER_VERSION = '2.0',
    FIRSTROW = 2
) AS oi;
GO

CREATE OR ALTER VIEW silver_order_items AS
SELECT
    oi.C1 AS order_id,
    TRY_CONVERT(int, oi.C2) AS order_item_id,
    oi.C3 AS product_id,
    oi.C4 AS seller_id,
    TRY_CONVERT(datetime2, oi.C5) AS shipping_limit_ts,
    TRY_CONVERT(decimal(18,2), oi.C6) AS price,
    TRY_CONVERT(decimal(18,2), oi.C7) AS freight_value
FROM bronze_order_items oi;
GO

CREATE OR ALTER VIEW bronze_payments AS
SELECT *
FROM OPENROWSET(
    BULK 'https://stolistleila2026.blob.core.windows.net/bronze/olist/raw/olist_order_payments_dataset.csv',
    FORMAT = 'CSV',
    PARSER_VERSION = '2.0',
    FIRSTROW = 2
) AS p;
GO

CREATE OR ALTER VIEW silver_payments AS
SELECT
    p.C1 AS order_id,
    TRY_CONVERT(int, p.C2) AS payment_sequential,
    p.C3 AS payment_type,
    TRY_CONVERT(int, p.C4) AS payment_installments,
    TRY_CONVERT(decimal(18,2), p.C5) AS payment_value
FROM bronze_payments p;
GO


CREATE OR ALTER VIEW gold_fact_sales AS
WITH items AS (
    SELECT
        order_id,
        SUM(price) AS items_value,
        SUM(freight_value) AS freight_value
    FROM silver_order_items
    GROUP BY order_id
),
payments AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM silver_payments
    GROUP BY order_id
)
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_ts,
    o.order_delivered_customer_ts,
    o.order_estimated_delivery_ts,
    o.is_late_delivery,

    i.items_value,
    i.freight_value,
    p.payment_value,

    (i.items_value + i.freight_value) AS gross_value
FROM silver_orders o
LEFT JOIN items i ON o.order_id = i.order_id
LEFT JOIN payments p ON o.order_id = p.order_id;
GO

-- Git readme
SELECT
  FORMAT(order_purchase_ts, 'yyyy-MM') AS month,
  SUM(gross_value) AS revenue
FROM gold_fact_sales
WHERE order_purchase_ts IS NOT NULL
GROUP BY FORMAT(order_purchase_ts, 'yyyy-MM')
ORDER BY month;
GO

SELECT
  AVG(CAST(is_late_delivery AS float)) AS late_delivery_rate
FROM gold_fact_sales;
GO

-- 10 top customer
SELECT TOP 10
  customer_id,
  SUM(gross_value) AS total_value,
  COUNT(*) AS orders
FROM gold_fact_sales
GROUP BY customer_id
ORDER BY total_value DESC;
GO

USE olist;
GO

CREATE OR ALTER VIEW gold_dim_customers AS
SELECT DISTINCT
    c.C1 AS customer_id,
    c.C2 AS customer_unique_id,
    c.C3 AS customer_zip_code_prefix,
    c.C4 AS customer_city,
    c.C5 AS customer_state
FROM OPENROWSET(
    BULK 'https://stolistleila2026.blob.core.windows.net/bronze/olist/raw/olist_customers_dataset.csv',
    FORMAT = 'CSV',
    PARSER_VERSION = '2.0',
    FIRSTROW = 2
) AS c;
GO

CREATE OR ALTER VIEW gold_dim_products AS
SELECT DISTINCT
    p.C1 AS product_id,
    p.C2 AS product_category_name,
    TRY_CONVERT(int, p.C3) AS product_name_length,
    TRY_CONVERT(int, p.C4) AS product_description_length,
    TRY_CONVERT(int, p.C5) AS product_photos_qty,
    TRY_CONVERT(int, p.C6) AS product_weight_g,
    TRY_CONVERT(int, p.C7) AS product_length_cm,
    TRY_CONVERT(int, p.C8) AS product_height_cm,
    TRY_CONVERT(int, p.C9) AS product_width_cm
FROM OPENROWSET(
    BULK 'https://stolistleila2026.blob.core.windows.net/bronze/olist/raw/olist_products_dataset.csv',
    FORMAT = 'CSV',
    PARSER_VERSION = '2.0',
    FIRSTROW = 2
) AS p;
GO

CREATE OR ALTER VIEW gold_dim_sellers AS
SELECT DISTINCT
    s.C1 AS seller_id,
    s.C2 AS seller_zip_code_prefix,
    s.C3 AS seller_city,
    s.C4 AS seller_state
FROM OPENROWSET(
    BULK 'https://stolistleila2026.blob.core.windows.net/bronze/olist/raw/olist_sellers_dataset.csv',
    FORMAT = 'CSV',
    PARSER_VERSION = '2.0',
    FIRSTROW = 2
) AS s;
GO



USE olist;
GO

CREATE OR ALTER VIEW gold_fact_sales_items AS
WITH payments AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_value
    FROM silver_payments
    GROUP BY order_id
),
items AS (
    SELECT
        order_id,
        order_item_id,
        product_id,
        seller_id,
        price,
        freight_value,
        (price + freight_value) AS gross_item_value
    FROM silver_order_items
)
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_ts,
    o.order_delivered_customer_ts,
    o.order_estimated_delivery_ts,
    o.is_late_delivery,

    i.order_item_id,
    i.product_id,
    i.seller_id,
    i.price,
    i.freight_value,
    i.gross_item_value,

    p.payment_value
FROM silver_orders o
JOIN items i ON o.order_id = i.order_id
LEFT JOIN payments p ON o.order_id = p.order_id;
GO

USE olist;
GO
SELECT * FROM gold_fact_sales_items;


