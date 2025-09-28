/* Business Request – 1: Monthly Circulation Drop Check 
Generate a report showing the top 3 months (2019–2024) where any city recorded the 
sharpest month-over-month decline in net_circulation. 
Fields: 
• city_name 
• month (YYYY-MM) 
• net_circulation */

	WITH circulation_changes AS (
		SELECT 
			c.city as city_name,
			DATE_FORMAT(p.printsaledate, '%Y-%m') AS month,
			p.net_circulation as net_circulation,
			net_circulation - lag(p.net_circulation) over (partition by c.city order by p.printsaledate) as change_in_circulation
		FROM 
		fact_print_sales as p
		 join
		dim_city as c
		on p.city_id = c.city_id
		WHERE YEAR(p.printsaledate) BETWEEN 2019 AND 2024
	)
	SELECT 
		city_name,
		month,
		net_circulation
	   -- change_in_circulation
	FROM circulation_changes
	WHERE change_in_circulation < 0
	ORDER BY change_in_circulation ASC
	LIMIT 3;


/*
Business Request – 2: Yearly Revenue Concentration by Category 
Identify ad categories that contributed > 50% of total yearly ad revenue. 
Fields: 
• year 
• category_name 
• category_revenue  
• total_revenue_year  
• pct_of_year_total
*/

		WITH yearly_rev as (   
			select Year as year,ad_category as category_name,ad_revenue as category_revenue
			from fact_ad_revenue
		),
		total_rev as (
		select year ,category_name, sum(category_revenue) as total_yearly_revenue
		from yearly_rev
		group by year,category_name
		order by total_yearly_revenue desc
		)
		select y.year,y.category_name,y.category_revenue,round(t.total_yearly_revenue,2) as total_revenue_year,
		round((y.category_revenue/t.total_yearly_revenue)*100,2) as pct_of_year_total
		from 
		yearly_rev as y
		join
		total_rev as t
		on 
		 y.year = t.year
		 where 
		 (y.category_revenue/t.total_yearly_revenue) > 0.05
		order by y.year,pct_of_year_total desc
		;

/*
	Business Request – 3: 2024 Print Efficiency Leaderboard 
	For 2024, rank cities by print efficiency = net_circulation / copies_printed. Return top 5. 
	Fields: 
	• city_name 
	• copies_printed_2024 
	• net_circulation_2024 
	• efficiency_ratio = net_circulation_2024 / copies_printed_2024 
	• efficiency_rank_2024
*/

		WITH  aggregatedvalues AS (
				SELECT  c.city as city_name, sum(p.copies_sold) as copies_printed_2024, sum(p.net_circulation) as net_circulation_2024
				FROM
				fact_print_sales as p 
				JOIN
				dim_city as c
				ON
                c.city_id = p.city_id
				WHERE  
                year(p.printsaledate)="2024"
				GROUP BY c.city
			)
			SELECT  city_name, copies_printed_2024,net_circulation_2024,
		          (net_circulation_2024/copies_printed_2024) as efficiency_ratio,
		          rank() over (order by (net_circulation_2024/copies_printed_2024) desc) as efficiency_rank
		    FROM 
            aggregatedvalues
		    order by efficiency_rank
			limit 5;
            
/*
	Business Request – 4 : Internet Readiness Growth (2021) 
	For each city, compute the change in internet penetration from Q1-2021 to Q4-2021 
	and identify the city with the highest improvement. 
	Fields: 
	• city_name 
	• internet_rate_q1_2021 
	• internet_rate_q4_2021 
	• delta_internet_rate = internet_rate_q4_2021 − internet_rate_q1_2021
*/     


/*Answer - Kanpur with the highest internet penetration */
with 
	int_q1_2021 as
	(
		select
			c.city as city_name , r.internet_penetration as internet_rate_q1_2021 
		from  
			FACT_CITY_READINESS as r
		join
			dim_city as c
		on
			c.city_id = r.city_id
		where qtr = "Q1"
		and
		year = 2021
    ),
  int_q4_2021   as
    (
    select 
		c.city as city_name , r.internet_penetration as internet_rate_q4_2021 
	from
		FACT_CITY_READINESS as r
	join
		dim_city as c
	on
		c.city_id = r.city_id
	where qtr = "Q4"
	and
	year = 2021
    )
    
    select    
		q1.city_name , q1.internet_rate_q1_2021, q4.internet_rate_q4_2021 ,
         round((q4.internet_rate_q4_2021 - q1.internet_rate_q1_2021),2) as  delta_internet_rate
	from 
		int_q1_2021 q1
	join
		int_q4_2021 q4
	on
		q1.city_name = q4.city_name
	order by  delta_internet_rate desc
    ;       

/* 
Business Request – 5: Consistent Multi-Year Decline (2019→2024) 
Find cities where both net_circulation and ad_revenue decreased every year from 2019 
through 2024 (strictly decreasing sequences). 
Fields: 
• city_name 
• year 
• yearly_net_circulation 
• yearly_ad_revenue 
• is_declining_print (Yes/No per city over 2019–2024) 
• is_declining_ad_revenue (Yes/No) 
• is_declining_both (Yes/No)
*/


/* answer - 
net_circulation - from  2019-2024 all  cities show  a continous decline
ad_revenue - from 2019-2024 - we cn see some revenue growth years inspite of declining net_circulation
no there are no cities with decline in both both net_circulation and ad_revenue decreased every year from 2019 
*/

with total_circulation as 
(
select c.city as city_name,p.year,sum(p.net_circulation) as net_circulation,
p.edition_id,
lag(sum(p.net_circulation)) over (partition by c.city order by p.year) as previous_year_netcirculation,
sum(p.net_circulation) - lag(sum(p.net_circulation)) over (partition by c.city order by p.year) as yearlydifference_netcirculation
from
fact_print_sales as p
join
dim_city as c
on c.city_id = p.city_id
group by c.city, p.year,p.edition_id
order by c.city
),
totalrev as
(
select year as revyear,round(sum(currency_inr),2) as ad_revenue,edition_id as edition_id
from
fact_ad_revenue 
group by  year, edition_id
order by  year
)
select 
tc.city_name,tc.year,tc.net_circulation,
tc.previous_year_netcirculation,tc.yearlydifference_netcirculation,
tr.ad_revenue,
lag(tr.ad_revenue) over (partition by tc.city_name order by tr.revyear) as previousyearrev,
round(tr.ad_revenue - lag(tr.ad_revenue) over (partition by tc.city_name order by tr.revyear),2) as diff_in_ad_rev
from
total_circulation tc
join
totalrev tr
on
tc.year = tr.revyear
and
tc.edition_id = tr.edition_id
order by tc.city_name
;


/*
Business Request – 6 : 2021 Readiness vs Pilot Engagement Outlier 
In 2021, identify the city with the highest digital readiness score but among the bottom 3 
in digital pilot engagement. 
readiness_score = AVG(smartphone_rate, internet_rate, literacy_rate) 
“Bottom 3 engagement” uses the chosen engagement metric provided (e.g., 
engagement_rate, active_users, or sessions). 
Fields: 
• city_name 
• readiness_score_2021 
• engagement_metric_2021 
• readiness_rank_desc 
• engagement_rank_asc 
• is_outlier (Yes/No)
*/



with readiness as 
(
select c.city as city_name, r.year as city_year,
round(sum(literacy_rate + smartphone_penetration + internet_penetration)/3,2) as readiness_score_2021
-- rank() over (partition by city_id order by readiness_score_2021) as readinesss_rank
from
fact_city_readiness r
join
dim_city c
on c.city_id = r.city_id
where 
r.year ="2021"
group by c.city,r.year
order by readiness_score_2021 desc
),
users as 
(
select year(launch_date) as launchyear , users_reached as active_users
from 
fact_digital_pilot2
-- group by launchyear
-- order by active_users asc
)
select r.city_name, r.readiness_score_2021, sum(u.active_users) as ac
from
readiness r
join
users u
on u.launchyear = r.city_year
group by r.city_name,r.readiness_score_2021;