 -- Кол-во пользователей, которые заходят на сайт
select
	count(distinct visitor_id) as total_visit
from sessions as s 


--Каналы, которые приводят пользователей
select
	count(distinct visitor_id) as visit_source,
	source
from sessions as s
group by source 


--Каналы, которые приводят на сайт посетителей (разбивка по дням и каналу)
select
	extract(day from visit_date) as visit_date,
	count(distinct visitor_id) as visit_source,
	source
from sessions as s
group by
	extract(day from visit_date), 
	source
order by visit_date


--Каналы, которые приводят на сайт посетителей (разбивка по неделям и каналам)
select
	extract(week from visit_date) as visit_week,
	count(distinct visitor_id) as visit_source,
	source,
	medium,
	campaign
from sessions as s
group by
	extract(week from visit_date), 
	source,
	medium,
	campaign
order by visit_week


--Кол-во лидов, которые приходят на сайт
select
	count(lead_id) as total_lead
from leads as l


--Конверсия из клика в лид
with tab1 as (
	select
		count(l.lead_id) as total_lead,
		count(distinct s.visitor_id) as total_visit
	from sessions as s
	left join leads as l
		on s.visitor_id = l.visitor_id
)
select
	round((tab1.total_lead * 100.0 / tab1.total_visit), 2) as conversion_lead
from tab1
	

--Конверсия из лида в оплату
select
	count(lead_id) as total_lead,
 	count(amount)
 		filter (
 			where status_id = 142
 		) as paid_lead,
 	count(amount)
 		filter (
 			where status_id = 142) * 100.0 / count(lead_id) 
 		as conversion_paid
 from leads as l
 
 
 --Траты по каналам в динамике
 with vk_cost as ( --Траты в VK
	select
		date(campaign_date) as campaign_date,
		utm_source,
		utm_medium,
		utm_campaign,
		sum(daily_spent) as total_cost
	from vk_ads as va
	group by
		date(campaign_date),
		utm_source,
		utm_medium,
		utm_campaign 
),
ya_cost as ( --Траты в Yandex
	select
		date(campaign_date) as campaign_date,
		utm_source,
		utm_medium,
		utm_campaign,
		sum(daily_spent) as total_cost
	from ya_ads as ya
	group by
		date(campaign_date),
		utm_source,
		utm_medium,
		utm_campaign 
)
select --Общая таблица трат
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
group by
	campaign_date,
	utm_source,
	utm_medium,
	utm_campaign
order by
	campaign_date asc,
	utm_source asc,
	utm_medium asc,
	utm_campaign asc


/*
 * Окупаемость каналов
 */
with vk_cost as ( --Затраты VK
    select
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from vk_ads as va
    group by
        utm_source,
        utm_medium,
        utm_campaign 
),
ya_cost as ( --Затраты YA
    select
        utm_source,
        utm_medium,
        utm_campaign,
        sum(daily_spent) as total_cost
    from ya_ads as ya
    group by
        utm_source,
        utm_medium,
        utm_campaign 
),
costs as ( --Сводная затрат
    select * from vk_cost
    union all
    select * from ya_cost
),
revenues as ( --Прибыль с лидов
    select
        s.source as utm_source,
        s.medium as utm_medium,
        s.campaign as utm_campaign,
        sum(l.amount) as total_revenue
    from leads as l
    left join sessions as s
    	on l.visitor_id = s.visitor_id
    	and s.visit_date <= l.created_at
    where l.status_id = 142
    group by
        utm_source,
        utm_medium,
        utm_campaign
),
count_vizit as ( --Посетители
	select
		source,
		medium,
		campaign,
		count(distinct visitor_id) as visitors_count
	from sessions as s
	group by
		source,
		medium,
		campaign
),
leads_count as ( --Лиды
	select
		s.source,
		s.medium,
		s.campaign,
		count(lead_id) as leads_count
	from leads as l
	right join sessions as s
		on s.visitor_id = l.visitor_id
	group by 
		s.source,
		s.medium,
		s.campaign
),
purchases_count as ( --Платные лиды
	select
		s.source,
		s.medium,
		s.campaign,
		count(l.lead_id)
        	filter (
        		where l.closing_reason = 'Успешная продажа' or l.status_id = 142
        ) as purchases_count
    from leads as l
	right join sessions as s
		on s.visitor_id = l.visitor_id
		and s.visit_date <= l.created_at
	group by 
		s.source,
		s.medium,
		s.campaign
)
/*
 * ИТОГОВЫЙ запрос с показателями окупаемости 
 */
select
    co.utm_source,
    co.utm_medium,
    co.utm_campaign,
    co.total_cost,
    coalesce(re.total_revenue, 0) as revenue,
    cv.visitors_count,
    lc.leads_count,
    pc.purchases_count,
    case 
    	when cv.visitors_count = 0 then null
    	else round((co.total_cost *1.0 / cv.visitors_count), 2)
    end as cpu,
    case 
    	when lc.leads_count = 0 then null
    	else round((co.total_cost * 1.0 / lc.leads_count), 2)
    end as cpl,
    case 
    	when pc.purchases_count = 0 then null
    	else round((co.total_cost * 1.0 / pc.purchases_count), 2)
    end as cppu,
    case 
    	when co.total_cost = 0 then null
    	else round(((coalesce(re.total_revenue, 0) - co.total_cost) * 100.0 / co.total_cost), 2)
    end as roi
from costs as co
left join revenues as re 
	on co.utm_source = re.utm_source
	and co.utm_medium = re.utm_medium
    and co.utm_campaign = re.utm_campaign
left join count_vizit as cv
	on co.utm_source = cv.source
	and co.utm_medium = cv.medium
    and co.utm_campaign = cv.campaign
left join leads_count as lc
	on co.utm_source = lc.source
	and co.utm_medium = lc.medium
    and co.utm_campaign = lc.campaign
left join purchases_count as pc
	on co.utm_source = pc.source
	and co.utm_medium = pc.medium
    and co.utm_campaign = pc.campaign
order by
	co.utm_source asc,
	co.utm_medium asc,
	co.utm_campaign asc
	

