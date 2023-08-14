/*
Use database pos
*/
USE pos;

--Run all stored procedures
CALL proc_FillUnitPrice();
CALL proc_FillOrderTotal();
CALL proc_FillMVCustomerPurchases();

/*
Stored procedure for keeping the
materialized view mv_ProductBuyers
upto date after any operation on order 
or orderLine
*/
DELIMITER //
CREATE OR REPLACE PROCEDURE update_mv_ProductBuyers(IN product_ID INT)
BEGIN

    DELETE FROM mv_ProductBuyers
    WHERE mv_ProductBuyers.productID = product_ID;

    INSERT INTO mv_ProductBuyers
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
        WHERE product.ID = product_ID
        GROUP BY product.ID;
END //
DELIMITER ;

/*
Stored procedure for keeping the
materialized view mv_CustomerPurchases
upto date after any operation on order 
or orderLine
*/
DELIMITER //
CREATE OR REPLACE PROCEDURE update_mv_CustomerPurchases(
    IN customer_ID INT)
BEGIN

    DELETE FROM mv_CustomerPurchases
    WHERE ID = customer_ID;

    INSERT INTO mv_CustomerPurchases
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
        WHERE customer.ID = customer_ID
        GROUP BY customer.ID;
END //
DELIMITER ;


--Create table priceChangeLog
CREATE TABLE priceChangeLog (
    `ID` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `oldPrice` DECIMAL(6,2),
    `newPrice` DECIMAL(6,2),
    `changeTimestamp` TIMESTAMP,
    `productid` INT,
    PRIMARY KEY (`ID`),
    FOREIGN KEY (`productid`) REFERENCES product(`ID`)
    )ENGINE = InnoDB DEFAULT CHARSET = latin1;

/*
Trigger on the product table that inserts 
a new row into priceChangeLog
each time the price only of a product is updated.
*/
DELIMITER //
CREATE TRIGGER insert_priceChangeLog BEFORE UPDATE ON product
    FOR EACH ROW
    BEGIN
        IF(OLD.currentPrice <> NEW.currentPrice) THEN
            INSERT INTO priceChangeLog (oldPrice, newPrice, productid) VALUES (
                OLD.currentPrice,
                NEW.currentPrice,
                NEW.ID);
        END IF;
    END //
DELIMITER ;


/*
Trigger on the orderLine table to set the unitPrice 
in orderLine table to be in sync with 
currentPrice of product table
*/
DELIMITER //
CREATE TRIGGER update_orderLine_unitPrice_insert BEFORE INSERT ON `orderLine`
    FOR EACH ROW
    BEGIN
        IF NEW.quantity is NULL THEN
            SET NEW.quantity = 1;
        END IF;

        -- To check with quantity in product

        select qtyOnHand INTO @tempQty FROM product WHERE product.ID = NEW.productID;
        IF NEW.quantity > @tempQty THEN
            signal sqlstate '45000' set message_text = 'Not enough quantity of product available';
        ELSE
            SET NEW.unitPrice = (SELECT currentPrice FROM product WHERE NEW.productID = product.ID);
        END IF;
    END //
DELIMITER ;
DELIMITER //
CREATE TRIGGER update_orderLine_unitPrice_update BEFORE UPDATE ON orderLine
    FOR EACH ROW
    BEGIN
        IF NEW.quantity is NULL THEN
            SET NEW.quantity = 1;
        END IF;

        -- To check with quantity in product

        select qtyOnHand INTO @tempQty FROM product WHERE product.ID = NEW.productID;
        SET @tempQty = @tempQty + OLD.quantity;
        IF NEW.quantity > @tempQty THEN
            signal sqlstate '45000' set message_text = 'Not enough quantity of product available';
        ELSE
            SET NEW.unitPrice = (SELECT currentPrice FROM product WHERE NEW.productID = product.ID);
        END IF;
    END //
DELIMITER ;

--This will imply an update trigger on order table for orderTotal as well
DELIMITER //
CREATE TRIGGER update_order_orderTotal AFTER UPDATE ON orderLine
    FOR EACH ROW
    BEGIN

        IF NEW.quantity < OLD.quantity THEN
            UPDATE product
            SET qtyOnHand = qtyOnHand + OLD.quantity - NEW.quantity
            WHERE ID = OLD.productID;
        ELSE
            UPDATE product
            SET qtyOnHand = qtyOnHand - NEW.quantity + OLD.quantity
            WHERE ID = OLD.productID;
        END IF;
        UPDATE `order`
        SET orderTotal = orderTotal - OLD.lineTotal + NEW.lineTotal
        WHERE ID = OLD.orderID;
        set new.lineTotal = 0;
        CALL update_mv_ProductBuyers(NEW.productID);

        SELECT customerID INTO @cID from `order` where ID = OLD.orderID;
        CALL  update_mv_CustomerPurchases(@cID);
    END //
DELIMITER ;
DELIMITER //
CREATE TRIGGER delete_order_orderTotal AFTER DELETE ON orderLine
    FOR EACH ROW
    BEGIN

        -- Updating quantity in the product table after deleting a product    

        UPDATE product
        SET qtyOnHand = qtyOnHand + OLD.quantity
        WHERE ID = OLD.productID;
        UPDATE `order`
        SET orderTotal = orderTotal - OLD.lineTotal
        WHERE ID = OLD.orderID;
        CALL update_mv_ProductBuyers(OLD.productID);
        SELECT orderTotal INTO @oTtl from `order` where ID = OLD.orderID;
        set old.orderID = 0;
        IF @oTtl = 0.0 THEN
            UPDATE `order`
            SET orderTotal = NULL
            WHERE ID = OLD.orderID;
        END IF;
        SELECT customerID INTO @cID from `order` where ID = OLD.orderID;
        CALL  update_mv_CustomerPurchases(@cID);
    END //
DELIMITER ;

CREATE TRIGGER insert_order_orderTotal AFTER INSERT ON orderLine
    FOR EACH ROW
    BEGIN

        -- Updating quantity in the product table after inserting a product    

        UPDATE product
        SET qtyOnHand = qtyOnHand - NEW.quantity
        WHERE ID = NEW.productID;

        SELECT orderTotal INTO @oTtl from `order` where ID = NEW.orderID;
        IF @oTtl is NULL THEN
            SET @oTtl = 0.0;
        END IF;
        UPDATE `order`
        SET orderTotal = @oTtl + NEW.lineTotal
        WHERE ID = NEW.orderID;

        -- END IF;
        CALL update_mv_ProductBuyers(NEW.productID);

        SELECT customerID INTO @cID from `order` where ID = NEW.orderID;
        CALL  update_mv_CustomerPurchases(@cID);
    END //
DELIMITER ;