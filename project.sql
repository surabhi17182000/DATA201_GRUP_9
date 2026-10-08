DROP DATABASE DataCoDB;
CREATE DATABASE IF NOT EXISTS DataCoDB;

USE DataCoDB;
-- header creation with clean data by text as datatype
CREATE TABLE dataco_raw (
    `Type` TEXT,
    `Days for shipping (real)` TEXT,
    `Days for shipment (scheduled)` TEXT,
    `Benefit per order` TEXT,
    `Sales per customer` TEXT,
    `Delivery Status` TEXT,
    `Late_delivery_risk` TEXT,
    `Category Id` TEXT,
    `Category Name` TEXT,
    `Customer City` TEXT,
    `Customer Country` TEXT,
    `Customer Email` TEXT,
    `Customer Fname` TEXT,
    `Customer Id` TEXT,
    `Customer Lname` TEXT,
    `Customer Password` TEXT,
    `Customer Segment` TEXT,
    `Customer State` TEXT,
    `Customer Street` TEXT,
    `Customer Zipcode` TEXT,
    `Department Id` TEXT,
    `Department Name` TEXT,
    `Latitude` TEXT,
    `Longitude` TEXT,
    `Market` TEXT,
    `Order City` TEXT,
    `Order Country` TEXT,
    `Order Customer Id` TEXT,
    `order date (DateOrders)` TEXT,
    `Order Id` TEXT,
    `Order Item Cardprod Id` TEXT,
    `Order Item Discount` TEXT,
    `Order Item Discount Rate` TEXT,
    `Order Item Id` TEXT,
    `Order Item Product Price` TEXT,
    `Order Item Profit Ratio` TEXT,
    `Order Item Quantity` TEXT,
    `Sales` TEXT,
    `Order Item Total` TEXT,
    `Order Profit Per Order` TEXT,
    `Order Region` TEXT,
    `Order State` TEXT,
    `Order Status` TEXT,
    `Order Zipcode` TEXT,
    `Product Card Id` TEXT,
    `Product Category Id` TEXT,
    `Product Description` TEXT,
    `Product Image` TEXT,
    `Product Name` TEXT,
    `Product Price` TEXT,
    `Product Status` TEXT,
    `shipping date (DateOrders)` TEXT,
    `Shipping Mode` TEXT
) CHARACTER SET utf8mb4;

SHOW VARIABLES LIKE 'local_infile';

SET GLOBAL local_infile = ON;

SHOW GLOBAL VARIABLES LIKE 'local_infile';


-- This command will read the csv file and then load data into the table and ignores first line as we already loaded headers.
LOAD DATA LOCAL INFILE
'/Users/sowmyagumpina/Downloads/DataCoSupplyChainDataset.csv'
INTO TABLE dataco_raw
CHARACTER SET latin1
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;


CREATE TABLE dataco_clean LIKE dataco_raw;
INSERT INTO dataco_clean
SELECT *
FROM dataco_raw;

-- checking data after data is loaded
SELECT *
FROM DataCoDB.dataco_clean
LIMIT 10;

-- concatinating fname and lname into single column, using trim to rmove spaces , nullif to turn empty string to null and concat_ws skips null values and avoiding unnecessary seperator when we find a missing name.alter
ALTER TABLE DataCoDB.dataco_clean
ADD COLUMN CustomerName VARCHAR(101)
AFTER `Customer Lname`;
SET SQL_SAFE_UPDATES = 0;
UPDATE DataCoDB.dataco_clean
SET CustomerName = CONCAT_WS(
    ' ',
    NULLIF(TRIM(`Customer Fname`), ''),
    NULLIF(TRIM(`Customer Lname`), '')
)
WHERE CustomerName IS NULL;
SET SQL_SAFE_UPDATES = 1;

SELECT COUNT(*) AS NameMismatchCount
FROM DataCoDB.dataco_clean
WHERE NOT (
    CustomerName <=> NULLIF(
        TRIM(
            CONCAT_WS(
                ' ',
                NULLIF(TRIM(`Customer Fname`), ''),
                NULLIF(TRIM(`Customer Lname`), '')
            )
        ),
        ''
    )
);

-- dropping fname and lname after merging into single column customer name
ALTER TABLE DataCoDB.dataco_clean
DROP COLUMN `Customer Fname`,
DROP COLUMN `Customer Lname`;

-- printing 10 rows of customer names
SELECT CustomerName
FROM DataCoDB.dataco_clean
LIMIT 10;

-- dropping privacy columns
ALTER TABLE DataCoDB.dataco_clean
DROP COLUMN `Customer Password`;

ALTER TABLE DataCoDB.dataco_clean
DROP COLUMN `Customer Email`;

ALTER TABLE DataCoDB.dataco_clean
DROP COLUMN `Customer Street`;

-- dropping unnecessary fields
-- Customer Country	Removed because customer is only from Puerto Rico and E.E. U.U 
ALTER TABLE DataCoDB.dataco_clean
DROP COLUMN `Product Image`,
DROP COLUMN `Product Description`,
DROP COLUMN `Customer Country`,
DROP COLUMN `Latitude`,
DROP COLUMN `Longitude`;


-- checking column names
DESCRIBE DataCoDB.dataco_clean;

-- checking duplicate columns
-- this expression counts rows where the two customer id's are different and get 1 if same values and 0 if different and not reverses the result
-- Inside the comparison: <=> returns 1 when the values match.
-- After NOT: that 1 becomes 0.
-- After SUM: a total of 0 means no rows had different values.

SELECT 
SUM(NOT(`customer id` <=> `order customer id`))
as customeridmismatches
from datacodb.dataco_clean;

SELECT 
SUM(NOT (`Category Id` <=> `Product Category Id`))
AS CategoryIdMismatches
from datacodb.dataco_clean;

select
SUM(NOT (`Product Card Id` <=> `Order Item Cardprod Id`))
AS ProductIdMismatches
from datacodb.dataco_clean;

select
SUM(NOT (`Benefit per order` <=> `Order Profit Per Order`))
AS ProfitMismatches
from datacodb.dataco_clean;

select
SUM(NOT (`Sales per customer` <=> `Order Item Total`))
AS SalesTotalMismatches
FROM DataCoDB.dataco_clean;

SELECT
SUM(NOT (`Product Price` <=> `Order Item Product Price`))
AS PriceMismatches
FROM DataCoDB.dataco_clean;

-- after checking paired columns are redundant and both columns contain matching values in every row, can keep one column from each pair and remove another
ALTER TABLE DataCoDB.dataco_clean
DROP COLUMN `Order Customer Id`,
DROP COLUMN `Order Item Cardprod Id`,
DROP COLUMN `Product Category Id`,
DROP COLUMN `Order Profit Per Order`,
DROP COLUMN `Sales per customer`,
DROP COLUMN `Order Item Product Price`;

-- checking Sales − Order Item Discount ≈ Order Item Total, so dropping the column orderItemtotal
SELECT
    `Sales`,
    `Order Item Discount`,
    `Order Item Total`
FROM DataCoDB.dataco_clean
LIMIT 10;

SELECT COUNT(*) AS SalesDiscountTotalMismatches
FROM DataCoDB.dataco_clean
WHERE ABS(
    (`Sales` - `Order Item Discount`) - `Order Item Total`
) > 0.1;

ALTER TABLE DataCoDB.dataco_clean
DROP COLUMN `Order Item Total`;

-- latedeliveryrisk is determined by delivery status as late = 1 and advance shipping, shipping cancelled and shipping on time = 0
SELECT COUNT(*) AS LateDeliveryRiskMismatches
FROM DataCoDB.dataco_clean
WHERE `Late_delivery_risk` <>
    CASE
        WHEN LOWER(TRIM(`Delivery Status`)) = 'late delivery' THEN 1
        ELSE 0
    END;
    
ALTER TABLE DataCoDB.dataco_clean
DROP COLUMN `Late_delivery_risk`;


-- Order Item Discount Rate	Removed because it can be calculated from quantity, product price, and discount.
-- Order Item discount cannot be dropped instead because it was observed, discount rate was rounded off and might give wrong discount values when calculated

--
-- SELECT COUNT(*) AS DiscountMismatches
-- FROM DataCoDB.dataco_clean
-- WHERE ABS(
--    `Order Item Discount`
--    -
--    (
--        `Order Item Quantity`
--        * `Product Price`
--        * `Order Item Discount Rate`
--    )
-- ) > 5;
--

SELECT COUNT(*) AS DiscountRateMismatches
FROM DataCoDB.dataco_clean
WHERE ABS(
    `Order Item Discount Rate`
    -
    (
        `Order Item Discount`
        /
        (`Order Item Quantity` * `Product Price`)
    )
) > 0.01;

  
  
-- Sales	Removed because it can be calculated as quantity multiplied by product price.
SELECT COUNT(*) AS SalesMismatches
FROM DataCoDB.dataco_clean
WHERE ABS(
    `Sales`
    -
        (`Order Item Quantity` * `Product Price`)
) > 0.1;
ALTER TABLE DataCoDB.dataco_clean
DROP COLUMN `Sales`;


-- Order Zipcode	Removed because a large proportion of its values were missing.
-- Product Status	Removed because most values were 0, providing little variation for analysis.
ALTER TABLE DataCoDB.dataco_clean
DROP COLUMN `Order Zipcode`,
DROP COLUMN `Product Status`;

DESCRIBE DataCoDB.dataco_clean;

-- Removing any beginning and ending spaces if exists and convert empty strings to NULL

SET SQL_SAFE_UPDATES = 0;

UPDATE DataCoDB.dataco_clean
SET
    `Type` = NULLIF(TRIM(`Type`), ''),
    `Delivery Status` = NULLIF(TRIM(`Delivery Status`), ''),
    `Category Name` = NULLIF(TRIM(`Category Name`), ''),
    `Customer City` = NULLIF(TRIM(`Customer City`), ''),
    `CustomerName` = NULLIF(TRIM(`CustomerName`), ''),
    `Customer Segment` = NULLIF(TRIM(`Customer Segment`), ''),
    `Customer State` = NULLIF(TRIM(`Customer State`), ''),
    `Customer Zipcode` = NULLIF(TRIM(`Customer Zipcode`), ''),
    `Department Name` = NULLIF(TRIM(`Department Name`), ''),
    `Market` = NULLIF(TRIM(`Market`), ''),
    `Order City` = NULLIF(TRIM(`Order City`), ''),
    `Order Country` = NULLIF(TRIM(`Order Country`), ''),
    `Order Region` = NULLIF(TRIM(`Order Region`), ''),
    `Order State` = NULLIF(TRIM(`Order State`), ''),
    `Order Status` = NULLIF(TRIM(`Order Status`), ''),
    `Product Name` = NULLIF(TRIM(`Product Name`), ''),
    `Shipping Mode` = NULLIF(TRIM(`Shipping Mode`), '');

SET SQL_SAFE_UPDATES = 1;

-- Check for redundant categories 
-- Type
SELECT `Type`, COUNT(*) AS RowCount
FROM DataCoDB.dataco_clean
GROUP BY `Type`
ORDER BY `Type`;
-- Order status
SELECT `Order Status`, COUNT(*) AS RowCount
FROM DataCoDB.dataco_clean
GROUP BY `Order Status`
ORDER BY `Order Status`;
-- Customer support
SELECT `Customer Segment`, COUNT(*) AS RowCount
FROM DataCoDB.dataco_clean
GROUP BY `Customer Segment`
ORDER BY `Customer Segment`;
-- Shipping mode
SELECT `Shipping Mode`, COUNT(*) AS RowCount
FROM DataCoDB.dataco_clean
GROUP BY `Shipping Mode`
ORDER BY `Shipping Mode`;
-- Delivery status
SELECT `Delivery Status`, COUNT(*) AS RowCount
FROM DataCoDB.dataco_clean
GROUP BY `Delivery Status`
ORDER BY `Delivery Status`;

--
-- Change state names to full names
--
SET SQL_SAFE_UPDATES = 0;

UPDATE DataCoDB.dataco_clean
SET `Customer State` =
    CASE UPPER(TRIM(`Customer State`))
        WHEN 'AL' THEN 'Alabama'
        WHEN 'AK' THEN 'Alaska'
        WHEN 'AZ' THEN 'Arizona'
        WHEN 'AR' THEN 'Arkansas'
        WHEN 'CA' THEN 'California'
        WHEN 'CO' THEN 'Colorado'
        WHEN 'CT' THEN 'Connecticut'
        WHEN 'DE' THEN 'Delaware'
        WHEN 'FL' THEN 'Florida'
        WHEN 'GA' THEN 'Georgia'
        WHEN 'HI' THEN 'Hawaii'
        WHEN 'ID' THEN 'Idaho'
        WHEN 'IL' THEN 'Illinois'
        WHEN 'IN' THEN 'Indiana'
        WHEN 'IA' THEN 'Iowa'
        WHEN 'KS' THEN 'Kansas'
        WHEN 'KY' THEN 'Kentucky'
        WHEN 'LA' THEN 'Louisiana'
        WHEN 'ME' THEN 'Maine'
        WHEN 'MD' THEN 'Maryland'
        WHEN 'MA' THEN 'Massachusetts'
        WHEN 'MI' THEN 'Michigan'
        WHEN 'MN' THEN 'Minnesota'
        WHEN 'MS' THEN 'Mississippi'
        WHEN 'MO' THEN 'Missouri'
        WHEN 'MT' THEN 'Montana'
        WHEN 'NE' THEN 'Nebraska'
        WHEN 'NV' THEN 'Nevada'
        WHEN 'NH' THEN 'New Hampshire'
        WHEN 'NJ' THEN 'New Jersey'
        WHEN 'NM' THEN 'New Mexico'
        WHEN 'NY' THEN 'New York'
        WHEN 'NC' THEN 'North Carolina'
        WHEN 'ND' THEN 'North Dakota'
        WHEN 'OH' THEN 'Ohio'
        WHEN 'OK' THEN 'Oklahoma'
        WHEN 'OR' THEN 'Oregon'
        WHEN 'PA' THEN 'Pennsylvania'
        WHEN 'RI' THEN 'Rhode Island'
        WHEN 'SC' THEN 'South Carolina'
        WHEN 'SD' THEN 'South Dakota'
        WHEN 'TN' THEN 'Tennessee'
        WHEN 'TX' THEN 'Texas'
        WHEN 'UT' THEN 'Utah'
        WHEN 'VT' THEN 'Vermont'
        WHEN 'VA' THEN 'Virginia'
        WHEN 'WA' THEN 'Washington'
        WHEN 'WV' THEN 'West Virginia'
        WHEN 'WI' THEN 'Wisconsin'
        WHEN 'WY' THEN 'Wyoming'
        WHEN 'DC' THEN 'District of Columbia'
        WHEN 'PR' THEN 'Puerto Rico'
        ELSE `Customer State`
    END;

SET SQL_SAFE_UPDATES = 1;

-- Check updated values missing states or bad state values
SELECT
    `Customer State`,
    COUNT(*) AS RowCount
FROM DataCoDB.dataco_clean
GROUP BY `Customer State`
ORDER BY `Customer State`;

-- Detected bad states, printing individual ones
SELECT
    `Customer Id`,
    `CustomerName`,
    `Customer City`,
    `Customer State`,
    `Customer Zipcode`
FROM DataCoDB.dataco_clean
WHERE `Customer State` REGEXP '^[0-9]+$';

-- city should be NULL, but data shifted by a column, state showing CA
SET SQL_SAFE_UPDATES = 0;

UPDATE DataCoDB.dataco_clean
SET
    `Customer Zipcode` = `Customer State`,
    `Customer State` = 'California',
    `Customer City` = NULL
WHERE `Customer City` = 'CA'
  AND `Customer State` REGEXP '^[0-9]{5}$'
  AND `Customer Zipcode` IS NULL;

SET SQL_SAFE_UPDATES = 1;

--
-- Remove inconsistencies with datetime and make it only date
--
SET SQL_SAFE_UPDATES = 0;
UPDATE DataCoDB.dataco_clean
SET
    `order date (DateOrders)` =
        CASE
            WHEN `order date (DateOrders)` LIKE '%:%'
            THEN DATE_FORMAT(
                STR_TO_DATE(
                    `order date (DateOrders)`,
                    '%m/%d/%Y %H:%i'
                ),
                '%Y-%m-%d'
            )
            ELSE `order date (DateOrders)`
        END,

    `shipping date (DateOrders)` =
        CASE
            WHEN `shipping date (DateOrders)` LIKE '%:%'
            THEN DATE_FORMAT(
                STR_TO_DATE(
                    `shipping date (DateOrders)`,
                    '%m/%d/%Y %H:%i'
                ),
                '%Y-%m-%d'
            )
            ELSE `shipping date (DateOrders)`
        END;
SET SQL_SAFE_UPDATES = 1;

--
-- Check all INT types have INT only 
--

-- Customer id
SELECT
    SUM(
        `Customer Id` IS NULL
        OR TRIM(`Customer Id`) NOT REGEXP '^[0-9]+$'
    ) AS InvalidCustomerIds,

-- Department id
    SUM(
        `Department Id` IS NULL
        OR TRIM(`Department Id`) NOT REGEXP '^[0-9]+$'
    ) AS InvalidDepartmentIds,

-- Category id
    SUM(
        `Category Id` IS NULL
        OR TRIM(`Category Id`) NOT REGEXP '^[0-9]+$'
    ) AS InvalidCategoryIds,

-- Product card id
    SUM(
        `Product Card Id` IS NULL
        OR TRIM(`Product Card Id`) NOT REGEXP '^[0-9]+$'
    ) AS InvalidProductIds,

-- Order id
    SUM(
        `Order Id` IS NULL
        OR TRIM(`Order Id`) NOT REGEXP '^[0-9]+$'
    ) AS InvalidOrderIds,

-- Order item id
    SUM(
        `Order Item Id` IS NULL
        OR TRIM(`Order Item Id`) NOT REGEXP '^[0-9]+$'
    ) AS InvalidOrderItemIds,

-- Order item quantity
    SUM(
        `Order Item Quantity` IS NULL
        OR TRIM(`Order Item Quantity`) NOT REGEXP '^[0-9]+$'
    ) AS InvalidQuantities,

-- Days for shipping - real
    SUM(
        `Days for shipping (real)` IS NULL
        OR TRIM(`Days for shipping (real)`) NOT REGEXP '^[0-9]+$'
    ) AS InvalidRealShippingDays,

-- Days for shipping - scheduled
    SUM(
        `Days for shipment (scheduled)` IS NULL
        OR TRIM(`Days for shipment (scheduled)`) NOT REGEXP '^[0-9]+$'
    ) AS InvalidScheduledShippingDays
FROM DataCoDB.dataco_clean;

--
-- Checking for decimal value types
--

-- Benefit per order
SELECT
    SUM(
        `Benefit per order` IS NULL OR TRIM(`Benefit per order`) 
        NOT REGEXP '^-?[0-9]+([.][0-9]+)?$'
    ) AS InvalidReportedProfit,

-- Order item discount
    SUM(
        `Order Item Discount` IS NULL OR TRIM(`Order Item Discount`) 
        NOT REGEXP '^-?[0-9]+([.][0-9]+)?$'
    ) AS InvalidDiscounts,

-- Order item discount rate
    SUM(
        `Order Item Discount Rate` IS NULL OR TRIM(`Order Item Discount Rate`)
            NOT REGEXP '^-?[0-9]+([.][0-9]+)?$'
    ) AS InvalidDiscountRates,

-- Order item profit ratio 
    SUM(
        `Order Item Profit Ratio` IS NULL OR TRIM(`Order Item Profit Ratio`)
            NOT REGEXP '^-?[0-9]+([.][0-9]+)?$'
    ) AS InvalidProfitRatios,

-- Product price
    SUM(
        `Product Price` IS NULL OR TRIM(`Product Price`)
            NOT REGEXP '^-?[0-9]+([.][0-9]+)?$'
    ) AS InvalidProductPrices
FROM DataCoDB.dataco_clean;

--
-- Assign correct dayatypes
--
ALTER TABLE DataCoDB.dataco_clean
    MODIFY COLUMN `Customer Id` INT,
    MODIFY COLUMN `Department Id` INT,
    MODIFY COLUMN `Category Id` INT,
    MODIFY COLUMN `Product Card Id` INT,
    MODIFY COLUMN `Order Id` INT,
    MODIFY COLUMN `Order Item Id` INT,
    MODIFY COLUMN `Order Item Quantity` INT,
    MODIFY COLUMN `Days for shipping (real)` INT,
    MODIFY COLUMN `Days for shipment (scheduled)` INT,
    MODIFY COLUMN `Benefit per order` DECIMAL(12,2),
    MODIFY COLUMN `Order Item Discount` DECIMAL(12,2),
    MODIFY COLUMN `Order Item Discount Rate` DECIMAL(8,4),
    MODIFY COLUMN `Order Item Profit Ratio` DECIMAL(8,4),
    MODIFY COLUMN `Product Price` DECIMAL(12,2),
    MODIFY COLUMN `Customer Zipcode` VARCHAR(10),
    MODIFY COLUMN `Order Date (DateOrders)` DATE,
    MODIFY COLUMN `Shipping Date (DateOrders)` DATE;
    
    
--
-- Create tables
--

-- Create the departments table
CREATE TABLE departments (
    department_id INT PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL
)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4;
-- Insert unique departments
INSERT INTO departments (
    department_id,
    department_name
)
SELECT DISTINCT
    `Department Id`,
    `Department Name`
FROM dataco_clean;

-- Create the categories table
CREATE TABLE categories (
    category_id INT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    department_id INT NOT NULL,

    CONSTRAINT fk_categories_department
        FOREIGN KEY (department_id)
        REFERENCES departments(department_id)
)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4;
-- Insert unique categories
INSERT INTO categories (
    category_id,
    category_name,
    department_id
)
SELECT DISTINCT
    `Category Id`,
    `Category Name`,
    `Department Id`
FROM dataco_clean;

-- Create the products table
CREATE TABLE products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL,
    category_id INT NOT NULL,
    product_price DECIMAL(12,2) NOT NULL,

    CONSTRAINT fk_products_category
        FOREIGN KEY (category_id)
        REFERENCES categories(category_id)
)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4;
-- Insert unique products
INSERT INTO products (
    product_id,
    product_name,
    category_id,
    product_price
)
SELECT DISTINCT
    `Product Card Id`,
    `Product Name`,
    `Category Id`,
    `Product Price`
FROM dataco_clean;   

-- Create the customers table
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(150) NOT NULL,
    customer_segment VARCHAR(30) NOT NULL,
    customer_city VARCHAR(100),
    customer_state VARCHAR(100),
    customer_zipcode VARCHAR(10)
)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4;
-- Insert unique customers
INSERT INTO customers (
    customer_id,
    customer_name,
    customer_segment,
    customer_city,
    customer_state,
    customer_zipcode
)
SELECT DISTINCT
    `Customer Id`,
    `CustomerName`,
    `Customer Segment`,
    `Customer City`,
    `Customer State`,
    `Customer Zipcode`
FROM dataco_clean;

-- Create the orders table
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date DATE NOT NULL,
    order_city VARCHAR(100) NOT NULL,
    order_state VARCHAR(100) NOT NULL,
    order_country VARCHAR(100) NOT NULL,
    order_region VARCHAR(100) NOT NULL,
    market VARCHAR(50) NOT NULL,
    payment_type VARCHAR(30) NOT NULL,
    order_status VARCHAR(30) NOT NULL,
    shipping_mode VARCHAR(50) NOT NULL,
    shipping_date DATE NOT NULL,
    days_for_shipping_real INT NOT NULL,
    days_for_shipment_scheduled INT NOT NULL,
    delivery_status VARCHAR(50) NOT NULL,

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4;
-- Insert unique orders
INSERT INTO orders (
    order_id,
    customer_id,
    order_date,
    order_city,
    order_state,
    order_country,
    order_region,
    market,
    payment_type,
    order_status,
    shipping_mode,
    shipping_date,
    days_for_shipping_real,
    days_for_shipment_scheduled,
    delivery_status
)
SELECT DISTINCT
    `Order Id`,
    `Customer Id`,
    `order date (DateOrders)`,
    `Order City`,
    `Order State`,
    `Order Country`,
    `Order Region`,
    `Market`,
    `Type`,
    `Order Status`,
    `Shipping Mode`,
    `shipping date (DateOrders)`,
    `Days for shipping (real)`,
    `Days for shipment (scheduled)`,
    `Delivery Status`
FROM dataco_clean;

-- Create the order_items table
CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    order_item_quantity INT NOT NULL,
    order_item_discount DECIMAL(12,2) NOT NULL,
    order_item_discount_rate DECIMAL(8,4) NOT NULL,
    order_item_profit_ratio DECIMAL(8,4) NOT NULL,
    reported_profit DECIMAL(12,2) NOT NULL,

    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id),

    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id)
        REFERENCES products(product_id)
)
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8mb4;
-- Insert all order items
INSERT INTO order_items (
    order_item_id,
    order_id,
    product_id,
    order_item_quantity,
    order_item_discount,
    order_item_discount_rate,
    order_item_profit_ratio,
    reported_profit
)
SELECT
    `Order Item Id`,
    `Order Id`,
    `Product Card Id`,
    `Order Item Quantity`,
    `Order Item Discount`,
    `Order Item Discount Rate`,
    `Order Item Profit Ratio`,
    `Benefit per order`
FROM dataco_clean;


--
-- Checking row count on all tables
--
SELECT 'departments' AS table_name, COUNT(*) AS row_count
FROM departments
UNION ALL
SELECT 'categories', COUNT(*)
FROM categories
UNION ALL
SELECT 'products', COUNT(*)
FROM products
UNION ALL
SELECT 'customers', COUNT(*)
FROM customers
UNION ALL
SELECT 'orders', COUNT(*)
FROM orders
UNION ALL
SELECT 'order_items', COUNT(*)
FROM order_items;

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


-- Which region has the highest number of distinct orders for each product category, including ties?
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