SELECT 
    DISTINCT(customer_id),
    first_name,
    last_name,
    first_name || ' ' || last_name AS full_name,
    email,
    LOWER(email) AS email_clean,
    gender,
    date_of_birth,
    registration_date,
    country,
    city,
    -- Data quality flags
    CASE 
        WHEN email IS NULL OR email = '' THEN FALSE 
        ELSE TRUE 
    END AS has_valid_email,
    
    CASE 
        WHEN date_of_birth IS NULL THEN FALSE 
        ELSE TRUE 
    END AS has_birth_date,
    
    -- Calculated fields
    DATEDIFF('year', date_of_birth, CURRENT_DATE()) AS age,
    DATEDIFF('day', registration_date, CURRENT_DATE()) AS days_since_registration

FROM {{ source('raw', 'customer') }}
WHERE customer_id IS NOT NULL
    and registration_date > '1995-01-01'