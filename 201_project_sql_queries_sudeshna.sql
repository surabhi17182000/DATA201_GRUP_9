use dataco_db;
-- Which payment type is used most often?
SELECT
    payment_type,
    COUNT(*) AS payment_count
FROM orders
GROUP BY payment_type
ORDER BY payment_count DESC
LIMIT 1;

-- Which order region generated the highest total sales revenue?
SELECT
    o.order_region,
    ROUND(
        SUM(p.product_price * oi.order_item_quantity),
        2
    ) AS total_revenue
FROM orders AS o
JOIN order_items AS oi
    ON o.order_id = oi.order_id
JOIN products AS p
    ON oi.product_card_id = p.product_card_id
GROUP BY o.order_region
ORDER BY total_revenue DESC
LIMIT 1;

-- Which 10 customers placed the most orders above the average ordering customer?
SELECT
    c.customer_id,
    c.customer_name,
    (
        SELECT COUNT(*)
        FROM orders AS o2
        WHERE o2.customer_id = c.customer_id
    ) AS order_count
FROM customers AS c
WHERE EXISTS (
    SELECT 1
    FROM orders AS o
    WHERE o.customer_id = c.customer_id
    GROUP BY o.customer_id
    HAVING COUNT(*) >
    (
        SELECT AVG(order_count)
        FROM
        (
            SELECT
                customer_id,
                COUNT(*) AS order_count
            FROM orders
            GROUP BY customer_id
        ) AS customer_order_counts
    )
)
ORDER BY order_count DESC
LIMIT 10;

-- Which product generated the highest total sales within each category, including ties?
SELECT
    p.product_card_id,
    p.product_name,
    p.category_id,
    ROUND(
        SUM(p.product_price * oi.order_item_quantity),
        2
    ) AS total_sales
FROM products AS p
JOIN order_items AS oi
    ON p.product_card_id = oi.product_card_id
GROUP BY
    p.product_card_id,
    p.product_name,
    p.category_id
HAVING SUM(p.product_price * oi.order_item_quantity) >= ALL
(
    SELECT
        SUM(p2.product_price * oi2.order_item_quantity)
    FROM products AS p2
    JOIN order_items AS oi2
        ON p2.product_card_id = oi2.product_card_id
    WHERE p2.category_id = p.category_id
    GROUP BY p2.product_card_id
)
ORDER BY total_sales DESC;




