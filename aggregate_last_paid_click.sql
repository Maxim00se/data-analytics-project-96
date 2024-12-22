with tab1 as (
    select
    	s.visitor_id,
        date(s.visit_date) as visit_date,
        s.source,
        s.medium,
        s.campaign,
        l.lead_id,
        date(l.created_at) as created_at,
        l.closing_reason,
        l.status_id,
        l.amount,
        row_number()
            over (
                partition by s.visitor_id
                order by s.visit_date desc
            ) as rnk        
    from sessions as s
    left join leads as l
    	on s.visitor_id = l.visitor_id
    	and s.visit_date <= l.created_at
    where s.medium <> 'organic'
),
filtered_tab1 as (
	select
		source,
		medium,
		campaign,
        visit_date,
        count(visitor_id) as visitors_count,
        count(lead_id) as leads_count,
        count(lead_id) filter (where tab1.closing_reason = 'Успешная продажа' or status_id = 142) as purchases_count, 
        sum(amount) as revenue
    from tab1
    where rnk = 1
    group by
    	visit_date,
    	source,
		medium,
		campaign
),
vk_cost as (
	select
		date(campaign_date) as campaign_date,
		utm_source,
		utm_medium,
		utm_campaign,
		sum(daily_spent) as total_cost
	from vk_ads as va
	group by date(campaign_date), utm_source, utm_medium, utm_campaign 
),
ya_cost as (
	select
		date(campaign_date) as campaign_date,
		utm_source,
		utm_medium,
		utm_campaign,
		sum(daily_spent) as total_cost
	from ya_ads as ya
	group by date(campaign_date), utm_source, utm_medium, utm_campaign 
),
all_cost as (
	select
		campaign_date,
		utm_source,
        utm_medium,
        utm_campaign,
        sum(total_cost) as total_cost
    from (
    	select *
		from vk_cost
		union all
		select *
    	from ya_cost
	) as combined_costs
	group by campaign_date, utm_source, utm_medium, utm_campaign
)
select
	ft.visit_date,
	ft.visitors_count,
	ft.source as utm_source,
	ft.medium as utm_medium,
	ft.campaign as utm_campaign,
	all_cost.total_cost,
	ft.leads_count,
	ft.purchases_count,
	ft.revenue
from filtered_tab1 as ft
left join all_cost
	on ft.visit_date = all_cost.campaign_date
	and ft.source = all_cost.utm_source
	and ft.medium = all_cost.utm_medium
	and ft.campaign = all_cost.utm_campaign
order by
	revenue desc nulls last,
	visit_date asc,
	visitors_count desc,
	utm_source asc,
	utm_medium asc,
	utm_campaign asc
limit 15

