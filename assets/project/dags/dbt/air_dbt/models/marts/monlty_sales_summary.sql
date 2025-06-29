
-- Bu model, aylık satış özetini oluşturur.

select date_trunc('month', order_date) as month,
       count(order_id) as total_orders,
       sum(total_amount) as total_spent,
       avg(total_amount) as avg_order_value,
       count(distinct customer_id) as unique_customers
from {{ ref('stg_orders') }}

group by 1
order by 1