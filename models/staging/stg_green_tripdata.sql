-- with 

-- source as (

--     select * from {{ source('staging', 'green_tripdata') }}

-- ),

-- renamed as (

--     select
--         vendor_id,
--         pickup_datetime,
--         dropoff_datetime,
--         store_and_fwd_flag,
--         rate_code,
--         passenger_count,
--         trip_distance,
--         fare_amount,
--         extra,
--         mta_tax,
--         tip_amount,
--         tolls_amount,
--         ehail_fee,
--         airport_fee,
--         total_amount,
--         payment_type,
--         distance_between_service,
--         time_between_service,
--         trip_type,
--         imp_surcharge,
--         pickup_location_id,
--         dropoff_location_id,
--         data_file_year,
--         data_file_month

--     from source

-- )

-- select * from renamed
{{
    config(
        materialized='view'
    )
}}

with tripdata as 
(
  select *,
    row_number() over(partition by vendor_id, pickup_datetime) as rn
  from {{ source('staging','green_tripdata') }}
  where vendor_id is not null 
)
select
    -- identifiers
    {{ dbt_utils.generate_surrogate_key(['vendor_id', 'pickup_datetime']) }} as tripid,
    {{ dbt.safe_cast("vendor_id", api.Column.translate_type("integer")) }} as vendorid,
    {{ dbt.safe_cast("rate_code", api.Column.translate_type("integer")) }} as ratecodeid,
    {{ dbt.safe_cast("pickup_location_id", api.Column.translate_type("integer")) }} as pickup_locationid,
    {{ dbt.safe_cast("dropoff_location_id", api.Column.translate_type("integer")) }} as dropoff_locationid,
    
    -- timestamps
    cast(pickup_datetime as timestamp) as pickup_datetime,
    cast(dropoff_datetime as timestamp) as dropoff_datetime,
    
    -- trip info
    store_and_fwd_flag,
    {{ dbt.safe_cast("passenger_count", api.Column.translate_type("integer")) }} as passenger_count,
    cast(trip_distance as numeric) as trip_distance,
    {{ dbt.safe_cast("trip_type", api.Column.translate_type("integer")) }} as trip_type,

    -- payment info
    cast(fare_amount as numeric) as fare_amount,
    cast(extra as numeric) as extra,
    cast(mta_tax as numeric) as mta_tax,
    cast(tip_amount as numeric) as tip_amount,
    cast(tolls_amount as numeric) as tolls_amount,
    cast(ehail_fee as numeric) as ehail_fee,
    cast(imp_surcharge as numeric) as improvement_surcharge,
    cast(total_amount as numeric) as total_amount,
    coalesce({{ dbt.safe_cast("payment_type", api.Column.translate_type("integer")) }},0) as payment_type,
    {{ get_payment_type_description("payment_type") }} as payment_type_description
from tripdata
where rn = 1


-- dbt build --select <model_name> --vars '{'is_test_run': 'false'}'
{% if var('is_test_run', default=true) %}

  limit 100

{% endif %}