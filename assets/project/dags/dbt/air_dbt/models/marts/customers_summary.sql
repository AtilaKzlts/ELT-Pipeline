SELECT
    customer_id,
    INITCAP(first_name) || ' ' || INITCAP(last_name) AS full_name,
    email,
    SPLIT_PART(email, '@', 2) AS email_domain,
    CASE 
        WHEN LOWER(gender) IN ('male', 'm') THEN 'Male'
        WHEN LOWER(gender) IN ('female', 'f') THEN 'Female'
        ELSE 'Other'
    END AS gender_cleaned,
    date_of_birth,
    floor(DATEDIFF('day', date_of_birth, CURRENT_DATE) / 365) AS age,
    registration_date,
    DATEDIFF('day', registration_date, CURRENT_DATE) AS customer_lifetime_days,
    country,
    city
FROM {{ref('stg_customers')}}
