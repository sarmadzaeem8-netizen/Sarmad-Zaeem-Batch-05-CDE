Section A — Set Operators
Q1 — Unified contact list (staff + customers, no duplicates)
SELECT first_name + ' ' + last_name AS full_name, email
FROM  sales.staffs
UNION
SELECT first_name + ' ' + last_name, email
FROM  sales.customers;
Q2 — States with both a store AND customers
SELECT state FROM sales.stores
INTERSECT
SELECT state FROM sales.customers;
Q3 — Store IDs that received zero orders in 2018
SELECT store_id FROM sales.stores
EXCEPT
SELECT store_id
FROM  sales.orders
WHERE YEAR(order_date) = 2018;
Section B — CTEs
Q4 — Products priced above their category average
WITH category_avg AS (
    SELECT category_id,
           AVG(list_price) AS avg_price
    FROM  production.products
    GROUP BY category_id
)
SELECT p.category_id,
       p.product_name,
       p.list_price,
       ca.avg_price AS category_avg_price
FROM  production.products p
JOIN  category_avg ca ON p.category_id = ca.category_id
WHERE p.list_price > ca.avg_price;
Q5 — Staff with order count above average
WITH staff_orders AS (
    SELECT staff_id,
           COUNT(*) AS order_count
    FROM  sales.orders
    GROUP BY staff_id
),
avg_orders AS (
    SELECT AVG(CAST(order_count AS FLOAT)) AS avg_count
    FROM  staff_orders
)
SELECT so.staff_id, so.order_count
FROM  staff_orders so
CROSS JOIN avg_orders ao
WHERE so.order_count > ao.avg_count;
Q6 — Store/year revenue exceeding $1,000,000
WITH store_year_revenue AS (
    SELECT o.store_id,
           YEAR(o.order_date)              AS year,
           SUM(oi.quantity * oi.list_price
               * (1 - oi.discount))          AS total_revenue
    FROM  sales.orders o
    JOIN  sales.order_items oi ON o.order_id = oi.order_id
    GROUP BY o.store_id, YEAR(o.order_date)
)
SELECT store_id, year, total_revenue
FROM  store_year_revenue
WHERE total_revenue > 1000000;
Section C — Constraints (DDL)
Q7 — Loyalty cards table with full constraints
CREATE TABLE sales.loyalty_cards (
    card_number  INT          NOT NULL,
    customer_id  INT          NOT NULL,
    points       INT          NOT NULL,
    tier         VARCHAR(10)  NOT NULL,
    join_date    DATE         NOT NULL,

    CONSTRAINT PK_loyalty_cards
        PRIMARY KEY (card_number),

    CONSTRAINT FK_loyalty_cards_customer
        FOREIGN KEY (customer_id)
        REFERENCES sales.customers (customer_id)
        ON DELETE CASCADE,

    CONSTRAINT CHK_loyalty_points
        CHECK (points >= 0),

    CONSTRAINT CHK_loyalty_tier
        CHECK (tier IN ('Bronze', 'Silver', 'Gold'))
);

-- Valid inserts (should succeed)
INSERT INTO sales.loyalty_cards VALUES (1001, 1, 500,  'Gold',   '2024-01-15');
INSERT INTO sales.loyalty_cards VALUES (1002, 2, 150,  'Silver', '2024-03-22');
INSERT INTO sales.loyalty_cards VALUES (1003, 3, 0,    'Bronze', '2024-06-01');

-- Bad inserts (should all FAIL)
-- INSERT INTO sales.loyalty_cards VALUES (1001, 4,  100, 'Gold',    '2024-07-01'); -- PK duplicate
-- INSERT INTO sales.loyalty_cards VALUES (1004, 1,  -50, 'Silver',  '2024-08-01'); -- negative points
-- INSERT INTO sales.loyalty_cards VALUES (1005, 5,  200, 'Diamond', '2024-09-01'); -- invalid tier
Q8 — Prevent shipped_date before order_date via ALTER TABLE
-- Create and seed the table
CREATE TABLE test_orders (
    order_id     INT  PRIMARY KEY,
    order_date   DATE NOT NULL,
    shipped_date DATE
);

INSERT INTO test_orders VALUES (1, '2024-01-10', '2024-01-13');
INSERT INTO test_orders VALUES (2, '2024-02-05', '2024-02-07');
INSERT INTO test_orders VALUES (3, '2024-03-01', NULL);

-- Add the constraint (NULL shipped_date is allowed — order not yet shipped)
ALTER TABLE test_orders
ADD CONSTRAINT CHK_shipped_after_ordered
    CHECK (shipped_date IS NULL OR shipped_date >= order_date);

-- Should FAIL (shipped before ordered)
-- INSERT INTO test_orders VALUES (4, '2024-04-10', '2024-04-08');

-- Should PASS
INSERT INTO test_orders VALUES (5, '2024-04-10', '2024-04-15');
Section D — CASE Expressions
Q9 — Shipping speed classification
SELECT
    order_id,
    order_date,
    shipped_date,
    CASE
        WHEN shipped_date IS NULL
            THEN 'Pending'
        WHEN DATEDIFF(day, order_date, shipped_date) <= 2
            THEN 'Fast'
        WHEN DATEDIFF(day, order_date, shipped_date) <= 5
            THEN 'Normal'
        ELSE 'Delayed'
    END AS shipping_speed
FROM sales.orders;
Q10 — Stock level labels per product per store
SELECT
    store_id,
    product_id,
    quantity,
    CASE
        WHEN quantity = 0               THEN 'Out of Stock'
        WHEN quantity BETWEEN 1 AND 10  THEN 'Low Stock'
        WHEN quantity BETWEEN 11 AND 50 THEN 'Sufficient'
        ELSE                                   'Well Stocked'
    END AS stock_status
FROM  production.stocks
ORDER BY store_id, quantity ASC;