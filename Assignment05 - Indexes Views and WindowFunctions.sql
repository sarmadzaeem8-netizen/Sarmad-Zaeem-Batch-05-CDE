-- ============================================================
--   ASSIGNMENT 05 — INDEXES, VIEWS & WINDOW FUNCTIONS
--   Database  : BikeStores
--   Topics    : Indexes (Clustered & Non-Clustered)
--               Views
--               ROW_NUMBER / RANK / DENSE_RANK
--               LAG / LEAD
--               COALESCE
-- ============================================================
-- SECTION A — INDEXES
-- ============================================================

-- Q1
CREATE NONCLUSTERED INDEX IX_products_brand_id
ON production.products(brand_id);

SELECT product_id,
       product_name,
       list_price
FROM production.products
WHERE brand_id = 3;


-- Q2
CREATE NONCLUSTERED INDEX IX_orders_order_date
ON sales.orders(order_date);

SELECT order_id,
       customer_id,
       order_date
FROM sales.orders
WHERE order_date BETWEEN '2018-01-01' AND '2018-06-30';



-- ============================================================
-- SECTION B — VIEWS
-- ============================================================

-- Q3
CREATE VIEW vw_pending_processing_orders
AS
SELECT
    o.order_id,
    c.first_name + ' ' + c.last_name AS customer_name,
    c.phone,
    c.email,
    o.order_date,
    CASE
        WHEN o.order_status = 1 THEN 'Pending'
        WHEN o.order_status = 2 THEN 'Processing'
    END AS order_status
FROM sales.orders o
JOIN sales.customers c
    ON o.customer_id = c.customer_id
WHERE o.order_status IN (1,2);
GO

SELECT *
FROM vw_pending_processing_orders
ORDER BY order_date DESC;



-- Q4
CREATE VIEW vw_store_inventory
AS
SELECT
    s.store_name,
    p.product_name,
    b.brand_name,
    c.category_name,
    st.quantity
FROM production.stocks st
JOIN sales.stores s
    ON st.store_id = s.store_id
JOIN production.products p
    ON st.product_id = p.product_id
JOIN production.brands b
    ON p.brand_id = b.brand_id
JOIN production.categories c
    ON p.category_id = c.category_id;
GO

SELECT *
FROM vw_store_inventory
WHERE quantity < 3;



-- ============================================================
-- SECTION C — ROW_NUMBER, RANK & DENSE_RANK
-- ============================================================

-- Q5
WITH sales_summary AS
(
    SELECT
        o.store_id,
        oi.product_id,
        SUM(oi.quantity) AS total_quantity
    FROM sales.orders o
    JOIN sales.order_items oi
        ON o.order_id = oi.order_id
    GROUP BY o.store_id, oi.product_id
),
ranked_products AS
(
    SELECT *,
           RANK() OVER
           (
               PARTITION BY store_id
               ORDER BY total_quantity DESC
           ) AS sales_rank
    FROM sales_summary
)
SELECT
    store_id,
    product_id,
    total_quantity,
    sales_rank
FROM ranked_products
WHERE sales_rank <= 2
ORDER BY store_id, sales_rank;



-- Q6
WITH ranked_products AS
(
    SELECT
        category_id,
        product_name,
        list_price,
        DENSE_RANK() OVER
        (
            PARTITION BY category_id
            ORDER BY list_price DESC
        ) AS price_rank
    FROM production.products
)
SELECT
    category_id,
    product_name,
    list_price,
    price_rank
FROM ranked_products
WHERE price_rank = 2
ORDER BY category_id;



-- Q7
CREATE TABLE test_customers (
    customer_id INT,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    phone VARCHAR(20),
    city VARCHAR(50)
);

INSERT INTO test_customers VALUES
(1,'Ali','Khan','0300-1111111','Karachi'),
(2,'Sara','Ahmed','0321-2222222','Lahore'),
(3,'Ali','Khan','0300-1111111','Karachi'),
(4,'Usman','Malik','0333-3333333','Islamabad'),
(5,'Sara','Ahmed','0321-2222222','Lahore'),
(6,'Sara','Ahmed','0321-2222222','Lahore'),
(7,'Hina','Raza','0312-4444444','Peshawar');

WITH duplicate_rows AS
(
    SELECT *,
           ROW_NUMBER() OVER
           (
               PARTITION BY first_name, last_name, phone
               ORDER BY customer_id
           ) AS rn
    FROM test_customers
)
SELECT
    customer_id,
    first_name,
    last_name,
    phone,
    city
FROM duplicate_rows
WHERE rn > 1;



-- ============================================================
-- SECTION D — LAG, LEAD & COALESCE
-- ============================================================

-- Q8
WITH monthly_sales AS
(
    SELECT
        MONTH(o.order_date) AS sales_month,
        SUM(
            oi.quantity *
            oi.list_price *
            (1 - oi.discount)
        ) AS net_sales
    FROM sales.orders o
    JOIN sales.order_items oi
        ON o.order_id = oi.order_id
    WHERE YEAR(o.order_date) = 2017
    GROUP BY MONTH(o.order_date)
)
SELECT
    sales_month,
    net_sales,
    LAG(net_sales) OVER
    (
        ORDER BY sales_month
    ) AS previous_month_sales,
    net_sales -
    COALESCE(
        LAG(net_sales) OVER
        (
            ORDER BY sales_month
        ),
        0
    ) AS sales_difference
FROM monthly_sales
ORDER BY sales_month;



-- Q9
SELECT
    category_id,
    product_name,
    list_price,
    LEAD(list_price) OVER
    (
        PARTITION BY category_id
        ORDER BY list_price DESC
    ) AS next_lower_price
FROM production.products
ORDER BY category_id, list_price DESC;



-- Q10
SELECT
    first_name + ' ' + last_name AS customer_name,
    COALESCE(
        NULLIF(phone,''),
        NULLIF(email,''),
        'No Contact Info'
    ) AS contact_info,
    phone,
    email
FROM sales.customers
ORDER BY last_name, first_name;