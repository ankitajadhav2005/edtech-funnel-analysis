use edtech_db;

-- Total Leads
select count(lead_id) as total_leads from leads_basic_details ;

-- Total Conversion Rate
SELECT ROUND((SELECT COUNT(DISTINCT lead_id) 
FROM leads_interaction_details
WHERE lead_stage = 'conversion') * 100.0
/ (SELECT COUNT(DISTINCT lead_id) FROM leads_basic_details), 2) 
AS conversion_rate;

-- Total leads distributed at each cycle
select cycle, count(lead_id )
as total_leads
from sales_managers_assigned_leads_details
group by cycle;

-- Difference of days between each cycle
with Uniquedates as (
SELECT distinct assigned_date from sales_managers_assigned_leads_details)
select assigned_date,
LAG(assigned_date) OVER (ORDER BY assigned_date) AS previous_unique_date,
DATEDIFF(assigned_date, Lag(assigned_date) OVER (ORDER BY assigned_date))
AS days_difference
FROM Uniquedates
order by assigned_date;

-- Total converted leads at each cycle
with leads_at_conversion_stage as (
select distinct lead_id from leads_interaction_details
where lead_stage = 'conversion')
select cycle,
count(distinct t1.lead_id) as total_leads from
leads_at_conversion_stage t1
join sales_managers_assigned_leads_details t2
on t2.lead_id = t1.lead_id 
group by cycle;

/*
A total of 360 leads entered the funnel, with an overall conversion rate 
of 17.78%.
Leads were fairly evenly distributed across cycles: 94 in Cycle 1, 91 
in Cycle 2, 87 in Cycle 3, and 88 in Cycle 4. The gap between cycles 
is typically around 7 days, although Cycle 3 extends longer, lasting 
about 35 days.
In terms of conversions, Cycle 3 performed the best with 37 conversions,
followed by Cycle 1 with 19. Cycle 2 and Cycle 4 had significantly lower
 conversions, with 3 and 5 respectively.
 */



--                    TOTAL LEADS AT EACH STAGE

WITH funnel AS (SELECT 
lead_id,
MAX(CASE WHEN lead_stage = 'lead' THEN 1 ELSE 0 END) as lead_stage,
MAX(CASE WHEN lead_id IN (SELECT lead_id FROM leads_demo_watched_details) THEN 1 ELSE 0 END) as awareness,
MAX(CASE WHEN call_reason = 'interested_for_conversion' THEN 1 ELSE 0 END) as consideration,
MAX(CASE WHEN call_reason = 'successful_conversion' THEN 1 ELSE 0 END) as conversion
FROM leads_interaction_details
GROUP BY lead_id
)
select sum(lead_stage) as total_leads_at_lead_stage,
sum(awareness)  as total_leads_at_awareness ,
sum(consideration) as total_leads_at_consideration,
sum(conversion) as total_leads_at_conversion from funnel ;
/*
The funnel shows a steady drop in leads at each stage,
moving from 329 (Lead) to 194 (Awareness) to 115 (Consideration) 
to 64 (Conversion).
The largest drop occurs between Lead and Awareness, indicating a major
leakage at the top of the funnel.
A significant number of leads are not progressing beyond the initial 
stage, suggesting issues in early engagement 
(e.g., demo attendance or initial interest).
While fewer leads reach later stages, the conversion from Consideration 
to Conversion is relatively stronger compared to earlier transitions.

Insight:
The primary bottleneck lies in the early funnel stage (Lead to Awareness)
where most leads are lost, highlighting a need to improve initial 
engagement and demo participation.
*/



--                 DROP RATE AT EACH STAGE	

WITH funnel_counts AS (SELECT 
(SELECT COUNT(DISTINCT lead_id) FROM leads_basic_details) AS total_leads,
(SELECT COUNT(DISTINCT lead_id) FROM leads_demo_watched_details) 
AS awareness_leads,
(SELECT COUNT(DISTINCT lead_id) 
FROM leads_interaction_details 
WHERE call_reason = 'interested_for_conversion') AS consideration_leads,
(SELECT COUNT(DISTINCT lead_id) FROM leads_interaction_details 
WHERE lead_stage = 'conversion') AS conversion_leads
)
SELECT 
ROUND((total_leads - awareness_leads) * 100.0 / total_leads, 2) 
AS lead_to_awareness_drop_rate,
ROUND((awareness_leads - consideration_leads) * 100.0 / awareness_leads, 2) 
AS awareness_to_consideration_drop_rate,
ROUND((consideration_leads - conversion_leads) * 100.0 / consideration_leads, 2) 
AS consideration_to_conversion_drop_rate
FROM funnel_counts;

/*
The funnel shows consistently high drop rates across all stages, 
with nearly 40–46% of leads dropping at each transition.
The highest drop occurs at the top of the funnel 
(Lead → Awareness: 46.11%), indicating weak initial engagement or 
low demo attendance.
The drop from Awareness to Consideration (40.72%) suggests that 
even after engagement, many leads are not convinced to move forward.
A 44.35% drop at the final stage (Consideration → Conversion) highlights 
challenges in closing interested leads.

Insight: The funnel is leaking heavily at every stage, 
not just one point. While the biggest issue is at the top of the funnel,
there is also a significant drop in intent and conversion,
indicating problems in both engagement quality and sales follow-up.
*/


--             ENGAGEMENT OF SALES MANAGER WITH LEADS
-- Awareness Stage
-- leads contacted for lead introduction
select count(distinct lead_id) as total_leads_for_introduction
from leads_interaction_details
where lead_stage = 'lead' and call_status = 'successful' 
and call_reason = 'lead_introduction' ;
-- Total 329 leads were contacted for lead introduction

-- leads contacted for demo_scheduled
select count(distinct lead_id) as total_demo_scheduled_leads
from leads_interaction_details
where lead_stage = 'lead' and call_status = 'successful' 
and call_reason = 'demo_schedule' ;
-- total 321 leads were scheduled demo on calls

-- leads that actually attended the demo
select count(distinct lead_id) as total_leads_that_watched_demo
from leads_demo_watched_details; 
-- total 194 leads were actually attended demo

/*
There is a significant gap between demo scheduled leads and 
actual demo attendance, indicating low participation even after
scheduling.
A large number of leads do not attend the demo despite being 
scheduled, highlighting a drop in engagement at this step.
This gap is likely a key contributor to the high drop from 
Lead to Awareness stage.

Insight:
Poor demo attendance is a major bottleneck, suggesting issues in
lead intent, follow-up effectiveness, or demo scheduling quality.
 */
 
-- Consideration Stage
-- check how many leads were contacted for post-demo-followup
select count(distinct lead_id) as 
total_contacted_leads_for_post_demo_follow_up
from leads_interaction_details 
where lead_stage = 'awareness' and call_status = 'successful' and 
call_reason = 'post_demo_followup' ;
-- all the leads were contacted 

-- check how many leads were contacted to follow up for consideration
select count(distinct lead_id) as 
total_contacted_leads_for_followup_to_consider
from leads_interaction_details 
where lead_stage = 'awareness' and call_status = 'successful' and 
call_reason = 'followup_for_consideration' ;
-- this shows only 30 leads were contacted for followup for consideration

-- check how many leads never contacted at awareness stage
SELECT DISTINCT lead_id
FROM leads_interaction_details
WHERE lead_stage = 'awareness'
GROUP BY lead_id
HAVING SUM(CASE WHEN call_status = 'successful' THEN 1 ELSE 0 END) = 0 ;

/*
All leads were contacted for post-demo follow-up, indicating strong 
initial engagement by the sales team.
However, only 30 leads were contacted for follow-up 
towards consideration, showing a sharp drop in follow-up efforts at 
the next step.
Since call connectivity is not an issue, the gap is likely due to 
lack of consistent follow-up strategy rather than reachability.

Insight: The drop from Awareness to Consideration is not driven by
connectivity issues but by insufficient follow-up actions to move leads
forward in the funnel.
*/

-- Conversion Stage
-- total leads that are interested to consider
select count(distinct lead_id)
as total_leads_interested_to_consider
from leads_interaction_details 
where lead_stage = 'consideration' and call_status = 'successful' and
call_reason = 'interested_for_conversion' ;
-- total 114 leads are interested to conversion

-- this shows leads contacted those were interested for conversion
select count(distinct lead_id) as 
total_leads_followed_up_for_conversion
from leads_interaction_details 
where lead_stage = 'consideration' and call_status = 'successful' and
call_reason = 'followup_for_conversion' ;
-- this shows 102 leads were followup up for conversion

-- total calls not connected at consideration stage
SELECT DISTINCT lead_id
FROM leads_interaction_details
WHERE lead_stage = 'consideration'
GROUP BY lead_id
HAVING SUM(CASE WHEN call_status = 'successful' THEN 1 ELSE 0 END) = 0;
-- this shows no call connectivity is not the issue

/*
A total of 114 leads showed interest for conversion, indicating a strong
pool of high-intent leads at the consideration stage.
Out of these, 102 leads were followed up for conversion, showing 
relatively good follow-up coverage by the sales team.
Call connectivity is not an issue, as all leads at this stage were 
successfully contacted.

Insight: Despite strong intent and good follow-up efforts, a 
significant number of leads still do not convert, indicating that the 
issue lies in conversion strategy, pricing, or value proposition rather 
than engagement or reachability.
*/

--               Reasons for Not Interested (per stage)
-- Awareness Stage
select reasons_for_not_interested_in_demo,
count(lead_id) as total_leads from leads_reason_for_no_interest
group by reasons_for_not_interested_in_demo
having reasons_for_not_interested_in_demo is not null
order by total_leads desc;

-- Consideration Stage
select reasons_for_not_interested_to_consider,
count(lead_id) as total_leads_not_interested_to_consider
from leads_reason_for_no_interest
group by reasons_for_not_interested_to_consider
having reasons_for_not_interested_to_consider is not null
order by total_leads_not_interested_to_consider desc;

-- Conversion Stage
select t2.current_education, reasons_for_not_interested_to_convert,
 count(t1.lead_id) as
total_leads
from leads_reason_for_no_interest t1
join leads_basic_details t2
on t1.lead_id = t2.lead_id 
where reasons_for_not_interested_to_convert is not null
group by current_education, reasons_for_not_interested_to_convert
order by total_leads desc;


/*
The top reasons for drop remain consistent across all stages,
with "Can’t afford", "Wants offline classes", and 
"Not interested in domain" appearing repeatedly.
At the demo stage, preference for offline classes (56 leads) and 
affordability (48 leads) are the biggest barriers, indicating a mismatch 
in product offering and pricing.
At the consideration stage, "Can’t afford" continues to be the primary 
reason, showing that pricing concerns persist even after initial 
engagement.
At the conversion stage, "Can’t afford" remains the top reason, 
followed by lack of interest in the domain and preference for offline 
classes.

Insight:
The drop is not stage-specific but driven by fundamental issues like 
pricing, product format (online vs offline), and low domain interest,
which consistently impact conversion throughout the funnel.

*/


--             Demographics of Leads Who Dropped
--                      Awareness Stage
-- segment leads reasons not interested in demo by education
select t2.current_education, reasons_for_not_interested_in_demo, 
count(t1.lead_id) as
total_leads
from leads_reason_for_no_interest t1
join leads_basic_details t2
on t1.lead_id = t2.lead_id 
where reasons_for_not_interested_in_demo is not null
group by current_education, reasons_for_not_interested_in_demo 
order by total_leads desc;

-- segment leads reasons not interested in demo by age
select t2.age, reasons_for_not_interested_in_demo, count(t1.lead_id) as
total_leads
from leads_reason_for_no_interest t1
join leads_basic_details t2
on t1.lead_id = t2.lead_id 
where reasons_for_not_interested_in_demo is not null
group by age, reasons_for_not_interested_in_demo 
order by total_leads desc;

-- segment leads reasons not interested in demo by city
select current_city, reasons_for_not_interested_in_demo, count(t1.lead_id) as
total_leads
from leads_reason_for_no_interest t1
join leads_basic_details t2
on t1.lead_id = t2.lead_id 
where reasons_for_not_interested_in_demo is not null
group by current_city, reasons_for_not_interested_in_demo 
order by total_leads desc;

/*
Leads who did not attend the demo mainly fall into specific segments with
clear patterns.
Job seekers are a major group, where 26 leads cited affordability issues, 
indicating price sensitivity in this segment.
B.Tech and job-seeking leads also show low interest in the domain 
(19 leads), suggesting weak alignment between the course offering and 
their career goals.
A significant number of leads prefer offline classes, especially 
concentrated in cities like Visakhapatnam and Kochi, highlighting a 
mismatch in delivery format.
From a lead source perspective, platforms like social media, website, 
and SEO are generating leads who either prefer offline learning or 
cannot afford the program, indicating lower-quality or mismatched
targeting.

Insight:
The drop in demo attendance is driven by specific lead segments
(B.Tech students and job seekers) who are either price-sensitive, not 
aligned with the course domain, or prefer offline learning. 
This indicates an issue with targeting and lead quality rather than 
just engagement, as multiple factors (education, intent, location, and 
source) are interconnected and contributing to the drop.
 */

--                   Consideration Stage
-- segment leads reasons not interested to consider by education
select t2.current_education, reasons_for_not_interested_to_consider, count(t1.lead_id) as
total_leads
from leads_reason_for_no_interest t1
join leads_basic_details t2
on t1.lead_id = t2.lead_id 
where reasons_for_not_interested_to_consider is not null
group by current_education, reasons_for_not_interested_to_consider
order by total_leads desc;

-- segment leads reasons not interested in consider by age
select age, reasons_for_not_interested_to_consider,
 count(t1.lead_id) as
total_leads
from leads_reason_for_no_interest t1
join leads_basic_details t2
on t1.lead_id = t2.lead_id 
where reasons_for_not_interested_to_consider is not null
group by age, reasons_for_not_interested_to_consider
order by total_leads desc;


-- segment leads reasons not interested to consider by city
select current_city, reasons_for_not_interested_to_consider,
 count(t1.lead_id) as
total_leads
from leads_reason_for_no_interest t1
join leads_basic_details t2
on t1.lead_id = t2.lead_id 
where reasons_for_not_interested_to_consider is not null
group by current_city, reasons_for_not_interested_to_consider
order by total_leads desc;


/*
Leads who are not moving to the consideration stage show patterns similar 
to those who skipped the demo, indicating a consistent issue across 
early funnel stages.
Job seekers remain highly price-sensitive, with 16 leads citing 
"Can’t afford" and 10 preferring offline classes, showing low alignment 
with the offering.
B.Tech students continue to show low domain interest (9 leads), 
reinforcing weak product–audience fit.
From an age perspective, 21–22 age group shows higher affordability 
concerns, while slightly older leads show preference for offline learning,
again linking back to earlier demo-stage behavior.
Cities like Chennai and Hyderabad consistently show 
"Can’t afford" as the top reason, with Chennai also showing a strong 
preference for offline classes.

Insight:
The same segments (job seekers and B.Tech students) that dropped at the 
demo stage continue to drop at the consideration stage due to 
affordability issues, low domain interest, and preference for offline 
learning. This confirms that the problem is not stage-specific but rooted
in poor targeting and mismatch between lead expectations and the product
offering.
*/

--                        Conversion Stage
-- segment leads reasons not interested to convert by education
select t2.current_education, reasons_for_not_interested_to_convert,
 count(t1.lead_id) as
total_leads
from leads_reason_for_no_interest t1
join leads_basic_details t2
on t1.lead_id = t2.lead_id 
where reasons_for_not_interested_to_convert is not null
group by current_education, reasons_for_not_interested_to_convert
order by total_leads desc;

-- segment leads reasons not interested in demo by age
select age, reasons_for_not_interested_to_convert,
 count(t1.lead_id) as
total_leads
from leads_reason_for_no_interest t1
join leads_basic_details t2
on t1.lead_id = t2.lead_id 
where reasons_for_not_interested_to_convert is not null
group by age, reasons_for_not_interested_to_convert
order by total_leads desc;

-- segment leads reasons not interested in demo by city
select current_city, reasons_for_not_interested_in_demo, count(t1.lead_id) as
total_leads
from leads_reason_for_no_interest t1
join leads_basic_details t2
on t1.lead_id = t2.lead_id 
where reasons_for_not_interested_in_demo is not null
group by current_city, reasons_for_not_interested_in_demo 
order by total_leads desc;
/*   Insights :
a high drop is between leads to awareness many leads has scheduled demo yet 
leads haven't attended the demo due to some common reaons. 
top 3 reasons are 
want offline classes, can't afford, student not interested in domain 
if we categorize this leads
on the basis of current education we get to know that
leads that searching for a job can't afford and then 
Btech leads highly give reasons can't afford, not interested in domain & 
has time issue
highest leads age between 25-20 are not attending demo
if we segment these reasons based on lead generation sources we get to know
social media, website generate high number of
leads that wants offline classes  then social media and user_refferals 
generate leads that can't afford 
*/

--                        Hypothesis
/*
1) Lead quality is a key issue, with a high share of leads mainly B.Tech students
and job seekers dropping off due to affordability concerns preference for
offline learning or lack of domain interest
*/

-- Drop rate by education
SELECT 
CASE 
	WHEN current_education = 'Looking for Job' THEN 'Job Seekers'
	WHEN current_education = 'B.Tech' THEN 'B.Tech'
	ELSE 'Others'
    END AS education_group,
COUNT(DISTINCT lbd.lead_id) AS total_leads,
      COUNT(DISTINCT CASE 
	  WHEN lid.lead_stage = 'conversion' THEN lbd.lead_id 
    END) AS converted_leads,
COUNT(DISTINCT lbd.lead_id) 
    - COUNT(DISTINCT CASE 
        WHEN lid.lead_stage = 'conversion' THEN lbd.lead_id 
    END) AS dropped_leads,
ROUND( 
       (
        (COUNT(DISTINCT lbd.lead_id) - COUNT(DISTINCT CASE 
		WHEN lid.lead_stage = 'conversion' THEN lbd.lead_id 
        END)) * 100.0 
        / COUNT(DISTINCT lbd.lead_id)), 2) AS drop_rate
        FROM leads_basic_details lbd
LEFT JOIN leads_interaction_details lid
ON lbd.lead_id = lid.lead_id
GROUP BY education_group
order by drop_rate desc;
/*
All education segments show high drop rates (>80%), with job seekers
having the highest drop rate at ~84%, slightly higher than B.Tech and 
other segments.
Drop is not limited to one segment it’s a widespread issue, 
but job seekers are slightly more prone to dropping.
*/

-- Reasons within each Segment
SELECT lbd.current_education, lrn.reasons_for_not_interested_in_demo
AS reason,
COUNT(DISTINCT lbd.lead_id) AS leads_count,
ROUND(COUNT(DISTINCT lbd.lead_id) * 100.0 /
SUM(COUNT(DISTINCT lbd.lead_id)) OVER (PARTITION BY lbd.current_education),
    2) AS percentage_contribution
FROM leads_reason_for_no_interest lrn
JOIN leads_basic_details lbd
ON lrn.lead_id = lbd.lead_id
WHERE lrn.reasons_for_not_interested_in_demo IS NOT NULL
GROUP BY lbd.current_education,
    lrn.reasons_for_not_interested_in_demo
ORDER BY 
    lbd.current_education, percentage_contribution DESC ;
    
 /*
For job seekers, affordability is the primary barrier (55%), 
followed by preference for offline classes (40%).
For B.Tech leads, drop reasons are more distributed, with lack of domain
interest (28%), affordability (24%), and offline preference (24%) being 
the top drivers
Job seekers drop mainly due to financial constraints, while B.Tech leads 
show mixed intent issues including lack of interest and engagement.
 */
 
 -- Stage-wise Drop Distribution
SELECT lbd.current_education,
   CASE 
   WHEN ldd.lead_id IS NULL THEN 'Dropped at Demo Stage'
	WHEN ldd.lead_id IS NOT NULL 
	AND lbd.lead_id NOT IN (
	SELECT lead_id 
	FROM leads_interaction_details 
	WHERE call_reason = 'interested_for_conversion')
	THEN 'Dropped at Consideration Stage'
	WHEN lbd.lead_id IN (
	SELECT lead_id FROM leads_interaction_details 
                 WHERE call_reason = 'interested_for_conversion')
             AND lbd.lead_id NOT IN (
                 SELECT lead_id FROM leads_interaction_details 
                 WHERE lead_stage = 'conversion')
        THEN 'Dropped at Conversion Stage'
        ELSE 'Converted'
		END AS drop_stage,
        COUNT(DISTINCT lbd.lead_id) AS total_leads
        FROM leads_basic_details lbd
LEFT JOIN leads_demo_watched_details ldd
ON lbd.lead_id = ldd.lead_id
GROUP BY lbd.current_education, drop_stage
ORDER BY lbd.current_education, total_leads DESC;

/*
Across all education segments, the highest drop occurs at the demo stage, indicating weak initial engagement.
B.Tech (69 leads) and job seekers (48 leads) contribute the most to 
early-stage drop-offs.
*/

/*
Insights :
The analysis indicates that drop-offs are highest at the demo stage 
across all segments, highlighting poor initial engagement. 
Job seekers are more affected by affordability constraints, leading to 
drop-offs across all stages, while B.Tech leads exhibit mixed intent 
issues, including lack of interest and preference mismatches. 
This suggests both lead quality issues and misalignment between offering 
and user expectations.
*/


-- Impact of fixing Can’t Afford
-- If we solve affordability how many leads could convert?
SELECT 
    COUNT(DISTINCT lead_id) AS potential_conversions
FROM leads_reason_for_no_interest
WHERE reasons_for_not_interested_in_demo = "Can't afford"
   OR reasons_for_not_interested_to_consider = "Can't afford"
   OR reasons_for_not_interested_to_convert = "Can't afford";
   
/*
Up to 99 leads could potentially be recovered by addressing affordability 
constraints.
*/

-- Impact of improving Demo
-- How many leads dropped before demo
SELECT 
    COUNT(DISTINCT lbd.lead_id) AS dropped_before_demo
FROM leads_basic_details lbd
LEFT JOIN leads_demo_watched_details ldd
ON lbd.lead_id = ldd.lead_id
WHERE ldd.lead_id IS NULL;

/*
Improving demo attendance can impact up to 166 leads currently dropping 
at the top of the funnel.
*/

-- Leads interested but not followed up properly
  SELECT  COUNT(DISTINCT lead_id) AS missed_followups
FROM leads_interaction_details
WHERE lead_stage = 'consideration'
AND call_reason = 'interested_for_conversion'
AND lead_id NOT IN (
    SELECT lead_id 
    FROM leads_interaction_details
    WHERE call_reason = 'followup_for_conversion'
);

/*
13 interested leads were not properly followed up, 
representing missed conversion opportunities.
*/

/*
While exact impact requires experimentation, analysis shows that 
addressing affordability, demo engagement, and follow-up gaps can 
potentially recover a significant portion of lost leads across the 
funnel.
*/
