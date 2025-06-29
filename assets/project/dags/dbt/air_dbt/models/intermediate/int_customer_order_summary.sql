WITH customer_orders AS (
    SELECT 
        c.customer_id,
        c.full_name,
        c.email_clean,
        c.registration_date,
        c.country,
        c.city,
        c.age,
        o.order_id,
        o.order_date,
        o.order_status,
        o.payment_method,
        o.total_amount,
        o.order_category
    FROM {{ ref('stg_customers') }} c   
    LEFT JOIN {{ ref('stg_orders') }} o 
        ON c.customer_id = o.customer_id
),

order_items_summary AS (
    SELECT 
        o.order_id,
        COUNT(*) AS items_count,
        SUM(oi.quantity) AS total_quantity,
        SUM(oi.net_amount) AS calculated_order_value,
        AVG(oi.discount) AS avg_discount_rate
    FROM {{ ref('stg_orders') }} o
    LEFT JOIN {{ ref('stg_order_items') }} oi 
        ON o.order_id = oi.order_id
    GROUP BY o.order_id
)

SELECT 
    co.*,
    COALESCE(ois.items_count, 0) AS items_count,
    COALESCE(ois.total_quantity, 0) AS total_quantity,
    COALESCE(ois.calculated_order_value, 0) AS calculated_order_value,
    COALESCE(ois.avg_discount_rate, 0) AS avg_discount_rate

FROM customer_orders co
LEFT JOIN order_items_summary ois 
    ON co.order_id = ois.order_id