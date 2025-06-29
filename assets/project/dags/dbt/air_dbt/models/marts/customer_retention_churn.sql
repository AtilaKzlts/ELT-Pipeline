WITH customer_monthly_active_status AS (
    -- Her müşterinin her ay için aktif olup olmadığını belirle
    SELECT
        DATE_TRUNC('month', order_date) AS activity_month,
        customer_id
    FROM {{ ref('stg_orders') }}
    WHERE order_status = 'completed'
    GROUP BY 1, 2 -- Sadece aktif olduğu ayı ve müşteri ID'yi grupluyoruz
),

customer_first_order_info AS (
    -- Her müşterinin ilk sipariş tarihini customer_metrics mart'ından al
    SELECT
        customer_id,
        first_order_date
    FROM {{ ref('customer_metrics') }} -- Var olan customer_metrics mart'ını kullanıyoruz
),

customer_activity_with_type AS (
    -- Aylık aktivite bilgisini ilk sipariş tarihi ile birleştirerek müşteri tipini belirle
    SELECT
        cmas.activity_month,
        cmas.customer_id,
        cfo.first_order_date,
        -- Müşterinin o ay için yeni mi yoksa mevcut mu olduğunu belirle
        CASE
            WHEN DATE_TRUNC('month', cfo.first_order_date) = cmas.activity_month THEN 'New'
            ELSE 'Existing'
        END AS customer_type_this_month
    FROM customer_monthly_active_status cmas
    JOIN customer_first_order_info cfo
        ON cmas.customer_id = cfo.customer_id
),

monthly_cohorts_counts AS (
    -- Her ay için yeni ve geri dönen müşteri sayılarını topla
    SELECT
        activity_month,
        COUNT(DISTINCT CASE WHEN customer_type_this_month = 'New' THEN customer_id END) AS new_customers,
        COUNT(DISTINCT CASE WHEN customer_type_this_month = 'Existing' THEN customer_id END) AS retained_customers
    FROM customer_activity_with_type
    GROUP BY activity_month
)

SELECT
    mc.activity_month,
    mc.new_customers,
    mc.retained_customers,
    -- Toplam aktif müşteri sayısı (o ay sipariş veren tüm benzersiz müşteriler)
    (mc.new_customers + mc.retained_customers) AS total_active_customers_this_month,
    -- Önceki ayın toplam aktif müşteri sayısını getiriyoruz (tutma oranı hesaplaması için)
    LAG((mc.new_customers + mc.retained_customers), 1, 0) OVER (ORDER BY mc.activity_month) AS total_active_customers_last_month
    -- Churn (müşteri kaybı) hesaplaması daha karmaşık mantık gerektirdiği için
    -- bu modelde doğrudan bir sütun olarak eklenmedi. Genellikle belirli bir
    -- hareketsizlik süresi (örn. 3 ay sipariş vermeme) baz alınarak BI araçlarında
    -- veya ayrı bir karmaşık modelde hesaplanır.
FROM monthly_cohorts_counts mc
ORDER BY mc.activity_month