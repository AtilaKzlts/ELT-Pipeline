SELECT
    product_id,
    product_name, -- product_n sütununu product_name olarak yeniden adlandırıyoruz
    category,
    brand,
    price AS unit_price,
    currency,
    is_active
FROM {{ source('raw', 'products') }}
