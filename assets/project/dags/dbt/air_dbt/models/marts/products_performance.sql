WITH product_sales AS (
    SELECT
        oi.product_id,
        SUM(oi.quantity) AS total_units_sold,
        SUM(oi.unit_price * oi.quantity) AS gross_revenue,
        SUM(oi.unit_price * oi.quantity - oi.discount) AS net_revenue,
        SUM(oi.discount) AS total_discount_given,
        COUNT(DISTINCT o.order_id) AS total_orders_containing_product,
        COUNT(oi.order_item_id) AS total_order_item_entries
    FROM {{ ref('stg_order_items') }} oi
    JOIN {{ ref('stg_orders') }} o ON oi.order_id = o.order_id
   
    GROUP BY oi.product_id
)

SELECT
    p.product_id,
    p.product_name,
    p.category,
    p.brand,
    ps.total_units_sold,
    ps.gross_revenue,
    ps.net_revenue,
    ps.total_discount_given,
    ps.total_orders_containing_product,
    -- Hesaplanan Metrikler
    CASE
        WHEN ps.total_units_sold > 0 THEN ps.gross_revenue / ps.total_units_sold
        ELSE 0
    END AS average_unit_price,
    CASE
        WHEN ps.gross_revenue > 0 THEN ps.total_discount_given / ps.gross_revenue
        ELSE 0
    END AS average_discount_rate_on_product
FROM product_sales ps
LEFT JOIN {{ ref('stg_products') }} p ON ps.product_id = p.product_id
WHERE ps.total_units_sold > 0
ORDER BY ps.net_revenue DESC