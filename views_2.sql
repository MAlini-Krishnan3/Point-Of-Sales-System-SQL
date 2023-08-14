-- Dont drop databases as we've already run etl.sql
USE pos;
-- SELECT query for v_CustomerNames (3957 rows)

CREATE VIEW v_CustomerNames AS
SELECT `lastName` AS `LN`,
`firstName` AS `FN`
FROM customer
ORDER BY `lastName` ASC, `firstName` ASC;

--SELECT query for v_Customers (3957 rows)
CREATE VIEW v_Customers AS
SELECT customer.ID AS `customer_number`,
customer.firstName AS `first_name`,
customer.lastName AS `last_name`,
customer.address1 AS `street1`,
customer.address2 AS `street2`,
city.city,
city.state,
customer.zip AS `zip_code`,
customer.email
FROM customer
LEFT JOIN city ON customer.zip = city.zip;

--SELECT query for v_ProductBuyers
CREATE VIEW v_ProductBuyers AS
SELECT product.ID AS `productID`, 
product.name AS `productName`, 
GROUP_CONCAT(
DISTINCT customer.ID," ",customer.firstName," ",customer.lastName
ORDER BY customer.ID SEPARATOR',') AS `customers`
FROM product 
    LEFT OUTER JOIN orderLine 
        ON product.ID = orderLine.productID
    LEFT OUTER JOIN `order`
        ON order.ID = orderLine.orderID
    LEFT OUTER JOIN customer
        ON customer.ID = order.customerID
GROUP BY product.ID;

-- SELECT query for v_CustomerPurchases (3957 rows)
CREATE VIEW v_CustomerPurchases AS
SELECT customer.ID, 
customer.firstName,
customer.lastName,
GROUP_CONCAT(
DISTINCT orderLine.productID," ",product.name 
ORDER BY orderLine.productID SEPARATOR'|') AS `products`
FROM customer 
    LEFT OUTER JOIN `order`
        ON customer.ID = order.customerID
    LEFT OUTER JOIN `orderLine`
        ON order.ID = orderLine.orderID
    LEFT OUTER JOIN product
        ON product.ID = orderLine.productID
GROUP BY customer.ID;

--Materialized Views
CREATE TABLE mv_ProductBuyers AS
SELECT * FROM v_ProductBuyers;

CREATE TABLE mv_CustomerPurchases AS
SELECT * FROM v_CustomerPurchases;

-- creating indexes for email
CREATE INDEX `idx_CustomerEmail`
ON customer(email);
-- ALTER TABLE customer
-- DROP INDEX idx_CustomerEmail;
-- SHOW INDEX from customer;

-- creating index for product name
CREATE INDEX `idx_ProductName`
ON product(name);