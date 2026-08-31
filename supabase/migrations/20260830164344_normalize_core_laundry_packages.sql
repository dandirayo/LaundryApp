with desired_services as (
  select *
  from (
    values
      ('Cuci Setrika', 'Cuci Setrika', 'Reguler', 72, false, 10),
      ('Cuci Setrika', 'Cuci Setrika', 'Express', 24, true, 11),
      ('Cuci Setrika', 'Cuci Setrika', 'Kilat', 8, true, 12),
      ('Cuci Lipat', 'Cuci Lipat', 'Reguler', 72, false, 20),
      ('Cuci Lipat', 'Cuci Lipat', 'Express', 24, true, 21),
      ('Cuci Lipat', 'Cuci Lipat', 'Kilat', 8, true, 22),
      ('Setrika', 'Setrika', 'Reguler', 72, false, 30),
      ('Setrika', 'Setrika', 'Express', 24, true, 31),
      ('Setrika', 'Setrika', 'Kilat', 8, true, 32)
  ) as service(
    category_name,
    item_name,
    size_variant,
    estimated_hours,
    is_express,
    sort_order
  )
),
matched_services as (
  select
    shop.id as shop_id,
    desired_services.category_name,
    desired_services.item_name,
    desired_services.size_variant,
    desired_services.estimated_hours,
    desired_services.is_express,
    desired_services.sort_order,
    service.id as service_id,
    row_number() over (
      partition by
        shop.id,
        desired_services.category_name,
        desired_services.item_name,
        desired_services.size_variant
      order by
        service.is_active desc nulls last,
        service.sort_order nulls last,
        service.created_at nulls last,
        service.id nulls last
    ) as match_rank
  from public.shops as shop
  cross join desired_services
  left join public.services as service
    on service.shop_id = shop.id
   and upper(service.unit) = 'KG'
   and lower(service.size_variant) = lower(desired_services.size_variant)
   and (
      (
        lower(desired_services.category_name) <> 'setrika'
        and lower(service.category_name) = lower(desired_services.category_name)
        and lower(service.item_name) = lower(desired_services.item_name)
      )
      or (
        lower(desired_services.category_name) = 'setrika'
        and lower(service.category_name) in ('setrika', 'setrika lipat')
        and lower(service.item_name) in ('setrika', 'setrika lipat')
      )
   )
),
updated_services as (
  update public.services as service
  set
    category_name = matched_services.category_name,
    item_name = matched_services.item_name,
    size_variant = matched_services.size_variant,
    material_variant = '',
    unit = 'KG',
    price = 7000,
    estimated_hours = matched_services.estimated_hours,
    is_express = matched_services.is_express,
    is_active = true,
    sort_order = matched_services.sort_order
  from matched_services
  where matched_services.service_id = service.id
    and matched_services.match_rank = 1
  returning service.id
),
inserted_services as (
  insert into public.services (
    shop_id,
    category_name,
    item_name,
    size_variant,
    material_variant,
    unit,
    price,
    estimated_hours,
    is_express,
    is_active,
    sort_order
  )
  select
    matched_services.shop_id,
    matched_services.category_name,
    matched_services.item_name,
    matched_services.size_variant,
    '',
    'KG',
    7000,
    matched_services.estimated_hours,
    matched_services.is_express,
    true,
    matched_services.sort_order
  from matched_services
  where matched_services.service_id is null
    and matched_services.match_rank = 1
  returning id
)
update public.services as service
set is_active = false
from matched_services
where matched_services.service_id = service.id
  and matched_services.match_rank > 1;
