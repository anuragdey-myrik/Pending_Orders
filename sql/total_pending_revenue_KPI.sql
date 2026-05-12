SELECT
  CASE
    WHEN SUM("__mb_source".total_original_price) >= 100000 THEN
      '₹' || ROUND(SUM("__mb_source".total_original_price) / 100000.0, 2) || ' Lakhs'

    WHEN SUM("__mb_source".total_original_price) >= 1000 THEN
      '₹' || ROUND(SUM("__mb_source".total_original_price) / 1000.0, 2) || ' Thousand'

    ELSE
      '₹' || ROUND(SUM("__mb_source".total_original_price), 2)::TEXT
  END AS total_pending_revenue

FROM
(
    SELECT
        COALESCE(w.city, 'Unknown') AS city_name,
        o.id AS order_id,

        COALESCE(
            NULLIF(o.delivery_location ->> 'name', ''),
            'NULL'
        ) AS customer_name,

        COALESCE(
            NULLIF(o.delivery_location ->> 'mobileNumber', ''),
            'NULL'
        ) AS customer_number,

        o.order_status AS order_status,

        CASE
            WHEN o.is_bulk_order = FALSE THEN 'Non-Bulk Order'
            WHEN o.is_bulk_order = TRUE THEN 'Bulk Order'
            ELSE 'Unknown'
        END AS order_type,

        SUM(oi.price * oi.quantity) AS total_original_price,
        o."createdAt" AS created_at

    FROM orders o

    LEFT JOIN order_items oi
        ON o.id = oi.order_id

    LEFT JOIN (
    SELECT DISTINCT
        parent_polygon_id,
        city
    FROM warehouses
) w
    ON o.polygon_id = w.parent_polygon_id

    WHERE
        o.order_status NOT IN (
            'Completed',
            'Cancelled',
            'cancelled',
            'Completed-Milk-Distribution',
            'Initiated'
        )
        AND o.is_partner_order = FALSE
        AND (
            oi.is_free_product = FALSE
            OR oi.is_free_product IS NULL
        )
        AND (
            oi.update_status != 'item_removed'
            OR oi.update_status IS NULL
        )
        AND o.is_stock_transfer_order = FALSE
        AND COALESCE(
            (o.meta_data ->> 'is_milk_distribution_order')::boolean,
            FALSE
        ) = FALSE
        AND COALESCE(
            (o.meta_data ->> 'is_water_distribution_order')::boolean,
            FALSE
        ) = FALSE

    GROUP BY
        city_name,
        o.id,
        customer_name,
        customer_number,
        order_status,
        order_type,
        created_at

) AS "__mb_source"

WHERE 1=1
    [[ AND "__mb_source".city_name IN ({{city_name}}) ]]
    [[ AND "__mb_source".order_type IN ({{order_type}}) ]]
;
