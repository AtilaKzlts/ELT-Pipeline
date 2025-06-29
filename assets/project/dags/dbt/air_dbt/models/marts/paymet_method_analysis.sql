
SELECT
    payment_method,
    COUNT(order_id) AS total_orders,
    SUM(total_amount) AS total_revenue
FROM {{ ref('stg_orders') }}

GROUP BY 1
