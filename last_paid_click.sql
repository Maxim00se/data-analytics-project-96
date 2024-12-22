with tab as (
select
row_number() over(partition by s.visitor_id order by visit_date desc) as rnk,
s.visitor_id,
s.visit_date,
s.source as utm_source,
s.medium as utm_medium,
s.campaign as utm_campaign
from sessions as s
where s.medium <> 'organic'
)
select
tab.visitor_id,
tab.visit_date,
tab.utm_source,
tab.utm_medium,
tab.utm_campaign,
l.lead_id,
l.created_at,
l.amount,
l.closing_reason,
l.status_id
from tab
left join leads as l on tab.visitor_id = l.visitor_id
where tab.rnk = 1
order by
amount desc nulls last,
visit_date asc,
utm_source asc,
utm_medium asc,
utm_campaign asc
limit 10
