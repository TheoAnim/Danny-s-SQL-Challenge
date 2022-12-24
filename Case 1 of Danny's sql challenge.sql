--1. Total Amount each customer spent at the restaurant
select customer_id, sum(menu.price) as Total_Amt
from sales join menu  on sales.product_id = menu.product_id
group by customer_id
order by Total_Amt desc


--How many days each customer visted the restaurant
select customer_id, count( distinct order_date) as Days_Visited
from sales
group by customer_id
order by Days_Visited desc
--count distinct is necessary, it's possible a customer made different orders in one visit

--What was the first item from the menu purchased by each customer
select * 
from
(
select S.customer_id
	 ,S.order_date
	 ,min(order_date) over (partition by customer_id) first_day
	 ,S.product_id
	 ,M.product_name
from sales S join menu M on S.product_id=M.product_id
) AS First
where First.order_date = First.first_day;


--alternative solution, use partition by and rank the order date by customer_id
with order_rank_cte
as
(
select S.customer_id
	 ,S.order_date
	 ,dense_rank() over (partition by customer_id order by order_date) Rank_Item
	 ,S.product_id
	 ,M.product_name
from sales S join menu M on S.product_id=M.product_id
)
select * 
from order_rank_cte
where Rank_Item = 1

-- What is the most purchased item on the menu and how many times was it purchased by all customers
select sales.product_id
	,menu.product_name
	,count (sales.product_id) Purchase_Count
from sales
join menu on sales.product_id = menu.product_id
group by sales.product_id, menu.product_name
order by Purchase_Count desc


-- What item was the most popular for each customer

with popular_cte 
as
(
select
	 S.customer_id
	,S.product_id
	,product_name
	,count(S.product_id) as Purchase_Count
from sales S join menu M on S.product_id = M.product_id
group by S.customer_id, S.product_id, M.product_name
)

Select 
		A.customer_id
		,A.product_id
		,A.product_name
		,A.Purchase_Count
from 
(select 
		customer_id 
		,product_id
		,product_name
		,Purchase_Count
		,dense_rank () over (partition by customer_id order by Purchase_Count desc) as Pur_Ct_Rank
	from popular_cte) as A
where A.Pur_Ct_Rank = 1


--Which item was purchased first by the customer after they became a member
with first_pur_CTE
as
	(select 
		S.customer_id
		,S.product_id
		,S.order_date
		,M.join_date
	from sales S
	join members M on S.customer_id = M.customer_id
	where S.order_date >= M.join_date
	)

select 
	  D.customer_id
	 ,D.order_date
	 ,D.product_id
	 ,M.product_name
from
(select 
	 customer_id
	,product_id
	,join_date
	,order_date
	,dense_rank() over (partition by customer_id order by order_date)  as Date_Rank
from first_pur_CTE) as D
join menu M on D.product_id = M.product_id
where D.Date_Rank = 1


-- Which item was purchased just before the customer became a member
with bf_mem_CTE
as
	(select 
		S.customer_id
		,S.product_id
		,S.order_date
		,M.join_date
	from sales S
	join members M on S.customer_id = M.customer_id
	where S.order_date < M.join_date
	)

select 
	  D.customer_id
	 ,D.order_date
	 ,D.product_id
	 ,M.product_name
from
(select 
	 customer_id
	,product_id
	,join_date
	,order_date
	,dense_rank() over (partition by customer_id order by order_date desc)  as Date_Rank
from bf_mem_CTE) as D
join menu M on D.product_id = M.product_id
where D.Date_Rank = 1


--What is the total items and amount spent for each customer before they became a member
select 
	 S.customer_id
	,count(M.product_name) as Total_Items
	,sum(M.price) as Amount
from sales S join members MB on S.customer_id = MB.customer_id 
			 join menu M on S.product_id = M.product_id
where S.order_date < MB.join_date
group by S.customer_id


-- If each $1 spent equates to 10points and sushi has a 2x points multiplier- how many points would each customer have? 

--create a temp table and update it with the corresponding points 

drop table if exists #points_tab
select 
	 S.customer_id
	,S.product_id
	,M.product_name
	,M.price
into #points_tab
from sales S join menu M on S.product_id= M.product_id

alter table #points_tab
add points integer

update #points_tab
set #points_tab.points = 20*#points_tab.price				
where product_name = 'sushi'

update #points_tab
set #points_tab.points = 10*#points_tab.price
where #points_tab.points is null


--sum the points and group by customer_id
select 
	 customer_id
	,sum(points) as Total_Points
from #points_tab 
group by customer_id


--much simplier to use case statement--

with point_cte 
as 	
	(select 
		 S.customer_id
		,M.product_name
		,M.price
		,case	
			 when M.product_name = 'sushi' 
				 then M.price*20
			 else M.price *10
	     end as Points
	from sales S join menu M on S.product_id = M.product_id
	) 
 select 
		 customer_id
		,sum(Points) as Total_Points
from point_cte 
group by customer_id


-- In the first week after a customer joins the program(including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January

with cust_join_cte 
as
	(select 
	  S.customer_id
	 ,S.product_id
	 ,M.product_name
	 ,S.order_date
	 ,MB.join_date
	 ,M.price
	 ,case	
		  when M.product_name = 'sushi'
			   then M.price * 20
		  when M.product_name <> 'sushi' 
				and S.order_date between MB.join_date and dateadd(day, 6, MB.join_date) 
				then M.price * 20
		  else M.price * 10
		  end as Points
	from sales S join menu M on S.product_id = M.product_id
		     join members MB on S.customer_id = MB.customer_id
	where S.order_date <= '2021-01-31' 
	) 

select 
	   customer_id
	  ,sum(Points) as Total_Points
from cust_join_cte
group by customer_id


--Bonus Questions: Join all tables

select 
	 S.customer_id
	,S.order_date
	,M.product_name
	,M.price
	,case	
		when S.order_date < MB.join_date
			then 'N'
		when MB.join_date is null
			then 'N'
		else 'Y'
	 end as member
	,case 
from Sales S join menu M on S.product_id = M.product_id 
		     left join members MB on S.customer_id = MB.customer_id



--Bonus Question: Rank all the things
select 
	 L.customer_id
    ,L.order_date
	,L.product_name
	,L.price
	,L.member
	,case
		when L.member = 'N'
			then null
		else dense_rank() over (partition by L.customer_id, L.member order by L.order_date)
	end as ranking
from 
	(select 
		 S.customer_id
		,S.order_date
		,M.product_name
		,M.price
		,case	
			when S.order_date < MB.join_date
				then 'N'
			when MB.join_date is null
			then 'N'
			else 'Y'
		end as member
	from Sales S join menu M on S.product_id = M.product_id 
		     left join members MB on S.customer_id = MB.customer_id ) L

