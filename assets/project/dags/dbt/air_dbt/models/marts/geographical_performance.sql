WITH regional_sales AS (
    SELECT
        c.country,
        c.city,
        o.order_id,
        o.customer_id,
        o.total_amount
    FROM {{ ref('stg_orders') }} o
    JOIN {{ ref('stg_customers') }} c
        ON o.customer_id = c.customer_id
    
)

SELECT
    country,
    city,
    COUNT(order_id) AS total_orders,
    SUM(total_amount) AS total_revenue,
    AVG(total_amount) AS average_order_value,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM regional_sales
GROUP BY 1, 2
ORDER BY total_revenue DESC, total_orders DESC