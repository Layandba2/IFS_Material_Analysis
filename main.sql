select distinct d.order_no as ipa_order_no,
                        d.release_no as ipa_release_no,
                        d.part_no as ipa_part_no,
                        d.type as ipa_type,
                        d.qty_demand as ipa_qty_demand,
                        d.due_date as ipa_due_date ,
                        d.onhand_qty as ipa_onhand_qty,
                       d.projected_qty as ipa_projected_qty

from 
            (select b.order_no,b.release_no,b.part_no , b.type ,b.qty_demand ,b.due_date,
                        nvl(c.onhand_qty,0) as onhand_qty,
                        nvl(c.onhand_qty,0) + sum(case when b.type = 'Purchase Order' then  b.qty_demand else - b.qty_demand end)
                        over( partition by b.part_no order by rownum asc) as projected_qty
             from
                          (select a.order_no,a.release_no,a.part_no,a.type,a.qty_demand,a.due_date 
                          from
                                    (select order_no as order_no,release_no as release_no,part_no as part_no,'Shop Order' as type,
                                     case when (qty_issued > qty_required) then  0 when (qty_issued < qty_required) then (qty_required - qty_issued)end as qty_demand,
                                     date_required as due_date
                                     from shop_material_alloc_uiv
                                     where contract ='DSI1' and state <> 'Cancelled' and state <> 'Closed' 
                                     union all
                                     select  r.order_no as order_no,r.line_no as release_no,r.part_no as part_no,'Purchase Order' as type,
                                     case when sum(r.qty_in_store) is not null then sum(r.qty_in_store)  else sum(p.buy_qty_due) end as qty_demand,
                                     p.wanted_delivery_date as due_date
                                     from purchase_receipt_stat_uiv r , purchase_order_line_all p
                                     where r.part_no=p.part_no and p.state <> 'Cancelled' and p.state <> 'Closed' and p.contract='DSI1'  
                                     group by r.order_no,r.line_no,r.part_no,p.wanted_delivery_date
                                    ) a
                   
                         order by a.due_date,a.order_no asc) b
                    
            left join 
                       (select ohq.material as material,
                                        (ohq.qty_in_transit + ohq.rm_stock + ohq.wip + ohq.wip2 ) as onhand_qty
                        from
                                    (select  inv.part_no as material,  nvl(sum(inv.qty_in_transit),0) as qty_in_transit,
                                                      sum(case when inv.location_type like 'Picking%' and inv.location_no like 'RM%' then inv.qty_onhand else 0 end ) as rm_stock,
                                                      sum(case when inv.location_type like 'Picking%' and(inv.location_no like 'SP-%'
                                                                                                                                                         or inv.location_no like 'SS-ADM'
                                                                                                                                                         or inv.location_no like 'STA-MP'
                                                                                                                                                         or inv.location_no like 'STA-SP'
                                                                                                                                                         or inv.location_no like 'KP-SUBST'
                                                                                                                                                         or inv.location_no like 'MP-%') then inv.qty_onhand else 0 end ) as wip,
                                                      sum(case when inv.location_type like 'Production%' then inv.qty_onhand else 0 end ) as wip2
                                     from inventory_part_in_stock_uiv inv
                                     group by inv.part_no
                                     ) ohq
                        ) c on c.material=b.part_no
               ) d
left join shop_material_alloc_uiv e
on d.release_no=e.release_no
where d.part_no  like 'I%' or d.part_no like 'L%' or d.part_no like 'R%'
