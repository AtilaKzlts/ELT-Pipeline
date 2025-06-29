SELECT 
    order_id,
    customer_id,
    order_date,
    shipping_address,
    order_status,
    payment_method,
    total_amount,
    
    -- Data quality checks
    CASE 
        WHEN total_amount < 0 THEN TRUE 
        ELSE FALSE 
    END AS is_negative_amount,

    CASE 
        WHEN order_status = 'completed' THEN 'successful'
        WHEN order_status = 'returned' THEN 'returned'
        WHEN order_status = 'cancelled' THEN 'failed'
        ELSE 'other'
    END AS order_category,

    -- Date extractions
    EXTRACT(YEAR FROM order_date) AS order_year,
    EXTRACT(MONTH FROM order_date) AS order_month,
    EXTRACT(DAY FROM order_date) AS order_day

FROM {{ source('raw', 'orders') }}
WHERE order_id IS NOT NULL 
and order_status = 'completed'