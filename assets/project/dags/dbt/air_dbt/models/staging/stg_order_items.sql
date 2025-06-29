SELECT 
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    discount,
    
    -- Calculated fields
    quantity * unit_price AS gross_amount,
    quantity * unit_price * discount AS discount_amount,
    quantity * unit_price * (1 - discount) AS net_amount,
    
    -- Data quality flags
    CASE 
        WHEN quantity <= 0 THEN TRUE 
        ELSE FALSE 
    END AS has_invalid_quantity,
    
    CASE 
        WHEN unit_price <= 0 THEN TRUE 
        ELSE FALSE 
    END AS has_invalid_price

FROM {{ source('raw', 'order_items') }}
WHERE order_item_id IS NOT NULL