/*
Use database pos
*/
USE pos;

CREATE OR REPLACE VIEW v_JsonView AS
SELECT customer.ID as `customerID`, 
JSON_OBJECT("Name", CONCAT(firstName, " ", lastName),"Orders", JSON_ARRAYAGG(DISTINCT JSON_OBJECT("OrderID", order.ID,"Date Placed", order.datePlaced,"Date Shipped", order.dateShipped,"Products", (SELECT JSON_ARRAYAGG(DISTINCT JSON_OBJECT("Name", product.name, "ID", product.ID, "Unit Price", product.currentPrice, "Quantity Purchased", orderLine.quantity)) AS `products` FROM `order` as od LEFT OUTER JOIN `orderLine`ON od.ID = orderLine.orderID LEFT OUTER JOIN product ON product.ID = orderLine.productID WHERE orderLine.orderID = order.ID)))) AS customerJson 
FROM customer
    LEFT OUTER JOIN `order`
        ON customer.ID = order.customerID
GROUP BY customer.ID;

/*
Stored procedure for looping through the view v_JsonView and writing into a json file
*/

DELIMITER //
CREATE OR REPLACE PROCEDURE json_Generator()
BEGIN
  DECLARE v1 INT DEFAULT 0;
  SELECT count(*) FROM v_JsonView INTO @size;
  WHILE v1 < @size DO
    SET @i = v1;
    SET @queryJson =
    CONCAT ("SELECT customerJson FROM `v_JsonView` WHERE customerID = @i INTO OUTFILE '"
       , @i
       , ".json'"
    );
    PREPARE q1 FROM @queryJson;
    EXECUTE q1;
    DROP PREPARE q1;
    SET v1 = v1 + 1;
  END WHILE;
END //
DELIMITER ;

CALL json_Generator();
