/*
Her müşterinin:

Kaç sipariş verdiği

Ne kadar harcama yaptığı

Ortalama sipariş tutarı

İlk ve son siparişi
*/


select customer_id,
       count(order_id) as total_orders,
       sum(total_amount) as total_spent,
       avg(total_amount) as avg_order_value,
       min(order_date) as first_order_date,
       max(order_date) as last_order_date
from {{ ref('stg_orders') }}
group by customer_id