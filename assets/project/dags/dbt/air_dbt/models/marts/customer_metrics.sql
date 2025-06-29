WITH payment_method_rank AS (
    SELECT 
        customer_id,
        payment_method,
        COUNT(*) as payment_count,
        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY COUNT(*) DESC) as rn
    FROM {{ ref('int_customer_order_summary') }}
    WHERE payment_method IS NOT NULL
    GROUP BY customer_id, payment_method
),

customer_metrics AS (
    SELECT 
        customer_id,
        full_name,
        email_clean,
        registration_date,
        country,
        city,
        age,
        
        -- Order metrics
        COUNT(CASE WHEN order_category = 'successful' THEN order_id END) AS total_orders,
        COUNT(CASE WHEN order_category = 'returned' THEN order_id END) AS returned_orders,
        COUNT(DISTINCT order_id) AS total_order_attempts,
        
        -- Financial metrics
        SUM(CASE WHEN order_category = 'successful' THEN total_amount ELSE 0 END) AS total_spent,
        SUM(CASE WHEN order_category = 'returned' THEN total_amount ELSE 0 END) AS returned_amount,
        AVG(CASE WHEN order_category = 'successful' THEN total_amount END) AS avg_order_value,
        
        -- Item metrics
        SUM(CASE WHEN order_category = 'successful' THEN total_quantity ELSE 0 END) AS total_items_purchased,
        AVG(CASE WHEN order_category = 'successful' THEN avg_discount_rate END) AS avg_discount_rate,
        
        -- Date metrics
        MIN(CASE WHEN order_category = 'successful' THEN order_date END) AS first_order_date,
        MAX(CASE WHEN order_category = 'successful' THEN order_date END) AS last_order_date
        
    FROM {{ ref('int_customer_order_summary') }}
    GROUP BY 1,2,3,4,5,6,7
    
),

customer_segments AS (
    SELECT 
        cm.*,
        pmr.payment_method AS preferred_payment_method,
        -- Calculated fields
        CASE 
            WHEN last_order_date IS NULL THEN 999
            ELSE DATEDIFF('day', last_order_date, CURRENT_DATE())
        END AS days_since_last_order,
        
        CASE 
            WHEN first_order_date IS NULL THEN 0
            ELSE DATEDIFF('day', first_order_date, last_order_date)
        END AS customer_lifetime_days,
        
        CASE 
            WHEN total_orders = 0 THEN 0
            WHEN customer_lifetime_days = 0 THEN 0
            ELSE ROUND(total_orders / (customer_lifetime_days / 30.0), 2)
        END AS orders_per_month,
        
        -- Return rate
        CASE 
            WHEN total_order_attempts = 0 THEN 0
            ELSE ROUND(returned_orders / total_order_attempts::FLOAT, 3)
        END AS return_rate,
        
        -- Customer segmentation
        CASE 
            WHEN total_spent >= 5000 AND total_orders >= 10 THEN 'VIP'
            WHEN total_spent >= 1000 AND total_orders >= 5 THEN 'High_Value'
            WHEN total_spent >= 500 AND total_orders >= 3 THEN 'Regular'
            WHEN total_orders >= 1 THEN 'Low_Value'
            ELSE 'No_Purchase'
        END AS customer_segment,
        
        -- Lifecycle stage
        CASE 
            WHEN days_since_last_order <= 30 THEN 'Active'
            WHEN days_since_last_order <= 90 THEN 'At_Risk'
            WHEN days_since_last_order <= 365 THEN 'Inactive'
            WHEN days_since_last_order > 365 THEN 'Lost'
            ELSE 'Never_Purchased'
        END AS lifecycle_stage
        
    FROM customer_metrics cm
    LEFT JOIN payment_method_rank pmr 
        ON cm.customer_id = pmr.customer_id 
        AND pmr.rn = 1
     WHERE cm.total_orders > 0  
)

SELECT 
    *,
    -- Final calculated metrics
    CURRENT_TIMESTAMP() AS last_updated,
    
    -- Data quality score
    (CASE WHEN email_clean IS NOT NULL THEN 1 ELSE 0 END +
     CASE WHEN age IS NOT NULL AND age BETWEEN 18 AND 100 THEN 1 ELSE 0 END +
     CASE WHEN total_orders > 0 THEN 1 ELSE 0 END) AS data_quality_score

FROM customer_segments