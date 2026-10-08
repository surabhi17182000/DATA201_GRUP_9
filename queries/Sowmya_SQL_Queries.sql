--
-- Basic queries
--

-- Which products are losing money?
SELECT
    p.product_id,
    p.product_name,
    SUM(oi.order_item_quantity) AS total_units_ordered,
    SUM(oi.reported_profit) AS total_reported_profit
FROM DataCoDB.products AS p
JOIN DataCoDB.order_items AS oi
    ON p.product_id = oi.product_id
GROUP BY
    p.product_id,
    p.product_name
HAVING SUM(oi.reported_profit) < 0
ORDER BY total_units_ordered DESC
LIMIT 10;

-- How many orders were delivered late, and what was their average delay?
SELECT
    COUNT(*) AS late_orders,
        AVG(
            days_for_shipping_real
            - days_for_shipment_scheduled
        ) AS average_delay_days
FROM DataCoDB.orders
WHERE delivery_status = 'Late delivery';


--
-- Advanced queries
--

-- Which departments generate the most reported profit? But also what is their profit on average per unit.
SELECT
    d.department_id,
    d.department_name,
    SUM(oi.order_item_quantity) AS total_units_ordered,
    SUM(oi.reported_profit) AS total_reported_profit,
    SUM(oi.reported_profit)
        / NULLIF(SUM(oi.order_item_quantity), 0)
        AS average_profit_per_unit
FROM DataCoDB.departments AS d
JOIN DataCoDB.categories AS c
    ON d.department_id = c.department_id
JOIN DataCoDB.products AS p
    ON c.category_id = p.category_id
JOIN DataCoDB.order_items AS oi
    ON p.product_id = oi.product_id
GROUP BY
    d.department_id,
    d.department_name
ORDER BY total_reported_profit DESC;


-- Which region dominates each product category?
SELECT
    c.category_name,
    o.order_region AS dominant_region
FROM DataCoDB.orders AS o
JOIN DataCoDB.order_items AS oi
    ON o.order_id = oi.order_id
JOIN DataCoDB.products AS p
    ON oi.product_id = p.product_id
JOIN DataCoDB.categories AS c
    ON p.category_id = c.category_id
GROUP BY
    c.category_id,
    c.category_name,
    o.order_region
HAVING COUNT(DISTINCT o.order_id) >= ALL (
    SELECT COUNT(DISTINCT o2.order_id)
    FROM DataCoDB.orders AS o2
    JOIN DataCoDB.order_items AS oi2
        ON o2.order_id = oi2.order_id
    JOIN DataCoDB.products AS p2
        ON oi2.product_id = p2.product_id
    WHERE p2.category_id = c.category_id
    GROUP BY o2.order_region
)
ORDER BY c.category_name, dominant_region;

