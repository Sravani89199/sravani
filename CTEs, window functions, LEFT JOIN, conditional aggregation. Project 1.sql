use teachers;

CREATE TABLE customer (  ####---------------customer
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    city VARCHAR(50),
    age_group VARCHAR(20)
);

INSERT INTO customer VALUES
(1,'Rahul','Hyderabad','18-25'),
(2,'Sneha','Hyderabad','26-35'),
(3,'Amit','Bangalore','26-35'),
(4,'Priya','Chennai','18-25'),
(5,'John','Delhi','36-45'),
(6,'Kiran','Hyderabad','26-35');

CREATE TABLE products (      ####---------------products
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50),
    price DECIMAL(10,2)
);

INSERT INTO products VALUES
(101,'Laptop','Electronics',65000),
(102,'Mouse','Electronics',800),
(103,'Keyboard','Electronics',1500),
(104,'Headphones','Electronics',2500),
(105,'USB Cable','Accessories',400);


CREATE TABLE orders (           ####---------------orders
    order_id INT PRIMARY KEY,
    customer_id INT,
    order_date DATE,
    status VARCHAR(20),
    
    FOREIGN KEY(customer_id)
    REFERENCES customer(customer_id)
);
drop table orders;

INSERT INTO orders VALUES
(1001,1,'2025-01-01','Completed'),
(1002,3,'2025-01-01','Completed'),
(1003,5,'2025-01-02','Completed');

CREATE TABLE order_items (           ####---------------order_items

    order_item_id INT PRIMARY KEY,

    order_id INT,

    product_id INT,

    quantity INT,

    price DECIMAL(10,2),

    FOREIGN KEY(order_id)
    REFERENCES orders(order_id),

    FOREIGN KEY(product_id)
    REFERENCES products(product_id)
);

INSERT INTO order_items VALUES
(1,1001,101,1,65000),
(2,1002,102,2,800),
(3,1003,104,1,2500);

CREATE TABLE cart_events (         ####---------------cart_events
    event_id INT PRIMARY KEY,
    customer_id INT,
    product_id INT,
    event_type VARCHAR(30),
    event_time DATETIME,

    FOREIGN KEY(customer_id)
    REFERENCES customer(customer_id),

    FOREIGN KEY(product_id)
    REFERENCES products(product_id)
);

INSERT INTO cart_events VALUES

(1,1,101,'VIEW_PRODUCT','2025-01-01 09:00:00'),
(2,1,101,'ADD_TO_CART','2025-01-01 09:05:00'),
(3,1,101,'CHECKOUT_STARTED','2025-01-01 09:10:00'),
(4,1,101,'ORDER_PLACED','2025-01-01 09:15:00'),

(5,2,102,'VIEW_PRODUCT','2025-01-01 10:00:00'),
(6,2,102,'ADD_TO_CART','2025-01-01 10:05:00'),

(7,3,102,'VIEW_PRODUCT','2025-01-01 11:00:00'),
(8,3,102,'ADD_TO_CART','2025-01-01 11:10:00'),
(9,3,102,'CHECKOUT_STARTED','2025-01-01 11:20:00'),
(10,3,102,'ORDER_PLACED','2025-01-01 11:30:00'),

(11,4,103,'VIEW_PRODUCT','2025-01-02 09:00:00'),
(12,4,103,'ADD_TO_CART','2025-01-02 09:05:00'),
(13,4,103,'CHECKOUT_STARTED','2025-01-02 09:10:00'),

(14,5,104,'VIEW_PRODUCT','2025-01-02 10:00:00'),
(15,5,104,'ADD_TO_CART','2025-01-02 10:10:00'),
(16,5,104,'CHECKOUT_STARTED','2025-01-02 10:20:00'),
(17,5,104,'ORDER_PLACED','2025-01-02 10:30:00'),

(18,6,105,'VIEW_PRODUCT','2025-01-02 11:00:00'),
(19,6,105,'ADD_TO_CART','2025-01-02 11:05:00');



##---Track events: VIEW_PRODUCT, ADD_TO_CART, CHECKOUT_STARTED, ORDER_PLACED in cart_events

WITH daily_events AS
(
SELECT DATE(event_time) AS event_date,
COUNT(CASE WHEN event_type='VIEW_PRODUCT' THEN 1 END) views,
COUNT(CASE WHEN event_type='ADD_TO_CART' THEN 1 END) carts,
COUNT(CASE WHEN event_type='CHECKOUT_STARTED' THEN 1 END) checkouts,
COUNT(CASE WHEN event_type='ORDER_PLACED' THEN 1 END) orders
FROM cart_events
GROUP BY DATE(event_time)
)

###---------->Calculate funnel conversion rate at each step per day.

SELECT event_date,
views, carts, checkouts, orders,

ROUND(carts*100.0/views,2) AS View_To_Cart,
ROUND(checkouts*100.0/carts,2) AS Cart_To_Checkout,
ROUND(orders*100.0/checkouts,2) AS Checkout_To_Order,
ROUND(orders*100.0/views,2) AS Overall_Conversion
FROM daily_events;


####--------------->Find top 10 products that are most frequently added to cart but not purchased
## Count:
## How many times each product was added to cart.
## How many times it was purchased.
## Difference = Potential abandoned carts.

WITH product_summary AS
(
SELECT product_id,

COUNT(CASE WHEN event_type='ADD_TO_CART' THEN 1 END) AS added,
COUNT(CASE WHEN event_type='ORDER_PLACED' THEN 1 END) AS purchased
FROM cart_events
GROUP BY product_id
)

SELECT p.product_id,
pr.product_name,
added,
purchased,
added-purchased AS not_purchased
FROM product_summary p

JOIN products pr
ON p.product_id=pr.product_id

ORDER BY not_purchased DESC
LIMIT 10;

### For each customer segment (e.g. city or age_group column in customers), compute cart abandonment rate.

WITH customer_cart AS (
    SELECT
        c.customer_id,
        c.city,
        c.age_group,

        MAX(CASE WHEN ce.event_type='ADD_TO_CART' THEN 1 ELSE 0 END) AS added,

        MAX(CASE WHEN ce.event_type='ORDER_PLACED' THEN 1 ELSE 0 END) AS purchased

    FROM customer c
    LEFT JOIN cart_events ce
        ON c.customer_id = ce.customer_id

    GROUP BY
        c.customer_id,
        c.city,
        c.age_group
)

SELECT
    city,

    COUNT(*) AS customer,

    SUM(CASE WHEN added=1 THEN 1 ELSE 0 END) AS customers_added_cart,

    SUM(
        CASE
            WHEN added=1
             AND purchased=0
            THEN 1
            ELSE 0
        END
    ) AS abandoned_customers,

    ROUND(
        100.0 *
        SUM(CASE WHEN added=1 AND purchased=0 THEN 1 ELSE 0 END)
        /
        NULLIF(
            SUM(CASE WHEN added=1 THEN 1 ELSE 0 END),
            0
        ),
        2
    ) AS abandonment_rate

FROM customer_cart
GROUP BY city
ORDER BY abandonment_rate DESC;











