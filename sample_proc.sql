-- Dont drop databases as we've already run views.sql
USE pos;

-- Alter orderLine table to add unitPrice DECIMAL(6,2)
ALTER TABLE orderLine
ADD unitPrice DECIMAL(6,2);

-- Alter orderLine to add virtual generated column lineTotal DECIMAL(7,2)
ALTER TABLE orderLine
ADD lineTotal DECIMAL(7,2) GENERATED ALWAYS AS (quantity * unitPrice) VIRTUAL;

-- Alter order table to add orderTotal DECIMAL(8,2)
ALTER TABLE `order`
ADD orderTotal DECIMAL(8,2);

-- Alter customer table to drop phone column
ALTER TABLE customer
DROP phone;

/* 
Have to drop the status table, but before that, 
drop the foreign key constraint on the order table
*/
ALTER TABLE `order`
DROP FOREIGN KEY order_ibfk_1;
ALTER TABLE `order`
DROP FOREIGN KEY order_ibfk_2;
ALTER TABLE `order`
ADD FOREIGN KEY (customerID) REFERENCES customer(ID);

DROP TABLE status;

ALTER TABLE `order`
DROP status;

/*
Procedure to replace all blank unitPrice entries in
orderLine with currentPrice from product 
*/
DELIMITER //
CREATE OR REPLACE PROCEDURE proc_FillUnitPrice()
BEGIN
	UPDATE orderLine
	INNER JOIN product ON orderLine.productID = product.ID
	SET orderLine.unitPrice = product.currentPrice
	WHERE orderLine.unitPrice IS NULL;
END //
DELIMITER ;
-- CALL proc_FillUnitPrice();

/*
Procedure in order with the sum of 
all of the lineTotal from all orderLine entries 
tied to a particular order
*/
DELIMITER //
CREATE OR REPLACE PROCEDURE proc_FillOrderTotal()
BEGIN
	UPDATE `order` AS OT
	LEFT OUTER JOIN orderLine ON orderLine.orderID = OT.ID
	SET OT.orderTotal = (SELECT SUM(orderLine.lineTotal) FROM orderLine WHERE orderLine.orderID = OT.ID GROUP BY orderLine.orderID);
END //
DELIMITER ;
-- CALL proc_FillOrderTotal();
-- DROP PROCEDURE proc_FillOrderTotal;

/*
Procedure proc_FillMVCustomerPurchases 
to refresh mv_CustomerPurchases
*/
DELIMITER //
CREATE OR REPLACE PROCEDURE proc_FillMVCustomerPurchases()
BEGIN
	DELETE FROM mv_CustomerPurchases;
	INSERT INTO mv_CustomerPurchases
	SELECT * FROM v_CustomerPurchases;
END //
DELIMITER ;
-- CALL proc_FillMVCustomerPurchases();
