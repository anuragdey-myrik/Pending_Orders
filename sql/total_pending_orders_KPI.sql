SELECT
  COUNT(*) AS "count"
FROM
  (
    SELECT
      COALESCE(w.city, 'Unknown') AS "City Name",
      o.id AS "Order Id",
      COALESCE(NULLIF(o.rider ->> 'name', ''), 'NULL') AS "Customer Name",
      COALESCE(
        NULLIF(o.rider ->> 'mobileNumber', ''),
        NULLIF(o.rider ->> 'phone', ''),
        'NULL'
      ) AS "Customer Number",
      COALESCE(
        NULLIF(o.updated_by_json ->> 'name', ''),
        NULLIF(o.meta_data ->> 'salesRepName', ''),
        'NULL'
      ) AS "Order Created By",
      COALESCE(
        NULLIF(o.updated_by_json ->> 'phone', ''),
        NULLIF(o.updated_by_json ->> 'mobileNumber', ''),
        NULLIF(o.meta_data ->> 'salesRepPhone', ''),
        'NULL'
      ) AS "Order Creator Phone No.",
      o.order_status AS "Order Status",
      CASE
        WHEN o.is_bulk_order = FALSE THEN 'Non-Bulk Order'
        WHEN o.is_bulk_order = TRUE THEN 'Bulk Order'
        ELSE 'Unknown'
      END AS "Order Type",
      CASE
        WHEN EXTRACT(
          EPOCH
          FROM
            (NOW() - o."createdAt")
        ) / 3600 <= 12 THEN 'Fresh Order (0-12 hrs)'
        WHEN EXTRACT(
          EPOCH
          FROM
            (NOW() - o."createdAt")
        ) / 3600 <= 24 THEN 'Priority Attention (12-24 hrs)'
        WHEN EXTRACT(
          EPOCH
          FROM
            (NOW() - o."createdAt")
        ) / 3600 <= 48 THEN 'High Priority (24-48 hrs)'
        ELSE 'Critical Delay (48+ hrs)'
      END AS "Ageing Bucket",
      SUM(oi.price * oi.quantity) AS "Total Original Price",
      o."createdAt" AS "Order Creation Date"
    FROM
      orders o
      LEFT JOIN order_items oi ON o.id = oi.order_id
      LEFT JOIN (
        SELECT
          DISTINCT parent_polygon_id,
          city
        FROM
          warehouses
      ) w ON o.polygon_id = w.parent_polygon_id
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
        (o.meta_data ->> 'is_milk_distribution_order') :: boolean,
        FALSE
      ) = FALSE
      AND COALESCE(
        (o.meta_data ->> 'is_water_distribution_order') :: boolean,
        FALSE
      ) = FALSE
    GROUP BY
      w.city,
      o.id,
      "Customer Name",
      "Customer Number",
      "Order Created By",
      "Order Creator Phone No.",
      "Order Status",
      "Order Type",
      "Ageing Bucket",
      "Order Creation Date"
  ) AS "__mb_source"
