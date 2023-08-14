
DROP DATABASE IF EXISTS `pos`;
CREATE DATABASE `pos`;
USE `pos`;

-- Created tables

-- Loading csv files into the tables

-- Loaded product table
LOAD DATA LOCAL INFILE 'products.csv'
INTO TABLE `product`
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(ID, name, @tempCurrentPrice, qtyOnHand)
SET currentPrice = REPLACE(REPLACE(@tempCurrentPrice, '$', ''), ',', '');

/*
For customer and city, 
I created a temp table to do ome cleansing
*/
CREATE TABLE `tempCustomer` (
    `ID` INT,
    `firstName` varchar(64) DEFAULT NULL,
    `lastName` VARCHAR(32) DEFAULT NULL,
    `city` varchar(32) DEFAULT NULL, 
    `state` varchar(4) DEFAULT NULL, 
    `zip` decimal(5,0) unsigned zerofill DEFAULT NULL,
    `email` VARCHAR(128) DEFAULT NULL,
    `address1` VARCHAR(128) DEFAULT NULL,
    `address2` VARCHAR(128) DEFAULT NULL,
    `phone` VARCHAR(32) DEFAULT NULL,
    `birthDate` DATE DEFAULT NULL,
    PRIMARY KEY (`ID`)
    )ENGINE = InnoDB DEFAULT CHARSET = latin1;

LOAD DATA LOCAL INFILE 'customers.csv'
INTO TABLE `tempCustomer`
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(ID, @firstName, @lastName, @city, @state, @zip, @address1, @address2, @email, @tempBirthDate)
SET 
firstName = NULLIF(@firstName,''),
lastName = NULLIF(@lastName,''),
city = NULLIF(@city,''),
state = NULLIF(@state,''),
zip = NULLIF(@zip,''),
address1 = NULLIF(@address1,''),
address2 = NULLIF(@address2,''),
email = NULLIF(@email,''),
birthDate = STR_TO_DATE(NULLIF(@tempBirthDate,''),'%m/%d/%Y');

-- Inserting data into city table 
INSERT INTO `city` (`zip`, `city`, `state`) 
    SELECT `zip`, MIN(`city`) as `city`, `state` 
    FROM `tempCustomer`
    GROUP BY `zip`;

-- Inserting data into customer table 
INSERT INTO `customer` (`ID`, 
        `firstName`, `lastName`, `email`, `address1`, `address2`, `birthDate`, `zip`) 
            SELECT `ID`, `firstName`, 
            `lastName`, `email`, `address1`, `address2`, `birthDate`, `zip`
            FROM `tempCustomer`;

-- Dropping the temporary table tempCustomer
DROP TABLE tempCustomer;   

-- Loaded order table
LOAD DATA LOCAL INFILE 'orders.csv'
INTO TABLE `order`
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(ID, customerID);

/*
For orderLine table, 
I'm creating a temporary table, 
and loading data into it first
*/

CREATE TABLE `tempOrderLine` (
    `orderID` INT,
    `productID` INT
    )ENGINE = InnoDB DEFAULT CHARSET = latin1;

LOAD DATA LOCAL INFILE 'orderlines.csv'
INTO TABLE `tempOrderLine`
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(orderID, productID);

-- Inserting data into orderLine table 
INSERT INTO `orderLine` (`orderID`, `productID`, `quantity`) 
    SELECT `orderID`, `productID`, COUNT(*) AS `quantity`
    FROM `tempOrderLine`
    GROUP BY `orderID`, `productID`
    ORDER BY `orderID`;

-- Dropping the temporary table tempOrderLine
DROP TABLE `tempOrderLine`;

-- LOAD DATA LOCAL INFILE 'customers.csv'
-- INTO TABLE `city`
-- FIELDS TERMINATED BY ','
-- ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 ROWS
-- (@dummy, @dummy, @dummy, city, state, zip, @dummy, @dummy, @dummy, @dummy);

