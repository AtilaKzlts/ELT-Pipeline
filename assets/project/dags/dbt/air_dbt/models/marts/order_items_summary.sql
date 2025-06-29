-- depends_on: {{ ref('stg_order_items') }}
-- depends_on: {{ ref('stg_orders') }}

select 
    date_trunc('day', stg_orders.order_date) as order_day,
    sum(quantity) as total_quantity,
    sum(unit_price * quantity) as total_revenue,
    sum(discount) as total_discount,
    count(distinct order_item_id) as total_order_items
from {{ ref('stg_order_items') }}
join {{ ref('stg_orders') }}
    on stg_order_items.order_id = stg_orders.order_id

group by date_trunc('day', stg_orders.order_date)
