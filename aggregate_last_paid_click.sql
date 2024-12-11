/*
 * Создаем витрину aggregate_last_paid_click
 */
with vk_cost as (                             --Затраты на рекламу vk
	select
        vk.campaign_date as visit_date,
        vk.utm_source,
        vk.utm_medium,
        vk.utm_campaign,
        vk.utm_content,
        SUM(vk.daily_spent) as total_spent
    from vk_ads as vk
    group by 
    	vk.campaign_date,
    	vk.utm_source,
    	vk.utm_medium,
    	vk.utm_campaign,
    	vk.utm_content
),
ya_cost as (                                  --Затраты на рекламу yandex
	select
		ya.campaign_date as visit_date,
		ya.utm_source,
    	ya.utm_medium,
    	ya.utm_campaign,
    	ya.utm_content,
    	SUM(ya.daily_spent) as total_spent
	from ya_ads as ya
	group by
		ya.campaign_date,
		ya.utm_source,
		ya.utm_medium,
		ya.utm_campaign,
		ya.utm_content
),
all_cost as (                                 --Соединяем затраты в одну таблицу с помошью UNION ALL
	select
		vk_cost.visit_date,
        vk_cost.utm_source,
        vk_cost.utm_medium,
        vk_cost.utm_campaign,
        vk_cost.utm_content,
        vk_cost.total_spent
	from vk_cost
	union all
	select
		ya_cost.visit_date,
		ya_cost.utm_source,
    	ya_cost.utm_medium,
    	ya_cost.utm_campaign,
    	ya_cost.utm_content,
    	ya_cost.total_spent
    from ya_cost
)
--Основной запрос: собираем данные
select
	DATE(s.visit_date) as visit_date,         --Дата визита
	s.source as utm_source,                   --Канал
	s.medium as utm_medium,                   --Тип трафика
	s.campaign as utm_campaign,               --Компания
	count(s.visitor_id) as visitors_count,    --Кол-во посещений
	sum(all_cost.total_spent) as total_spent, --Суммируем затраты из all_cost по категориям
	count(l.lead_id) as leads_count,          --Кол-во лидов
	COUNT(
        case
            when
                l.closing_reason = 'Успешно реализовано' or l.status_id = 142
                then l.lead_id
        end
    ) as purchases_count,                     --Кол-во успешно закрытых лидов
	SUM(
        case
            when
                l.closing_reason = 'Успешно реализовано' or l.status_id = 142
                then l.amount
        end
    ) as revenue                              --Общая прибыль
from sessions as s
/*
 * Соединяем таблицы, 
 * выставляем фильтры (только платные источники), 
 * группируем и сортируем
 */
left join all_cost 
	on s.source = all_cost.utm_source
	and s.medium = all_cost.utm_medium
	and s.campaign = all_cost.utm_campaign
	and DATE(s.visit_date) = all_cost.visit_date
left join leads as l
	on l.visitor_id = s.visitor_id 
	and date(l.created_at) >= date(s.visit_date)
where s.medium in ('cpc', 'cpm', 'cpa', 'youtube',
'cpp', 'tg', 'social')
group by DATE(s.visit_date), s.source, s.medium,
s.campaign
order by
	revenue desc nulls last,
	visit_date asc,
	visitors_count desc,
	utm_source asc,
	utm_medium asc,
	utm_campaign asc
limit 15