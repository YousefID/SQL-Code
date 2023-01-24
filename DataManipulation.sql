-- Shows all Orders table columns
Select Customer_ID,Order_ID,Product,Units_Sold,Date,Revenue,Cost 
From Orders
order by 2,3


-- Shows total Units_Sold vs Product
Select Product,sum(Units_Sold) as total_sold_units
From Orders
group by Product
order by total_sold_units desc

-- Shows Customers table columns
Select Customer_ID,[Name],Phone,Address,City,State,Zip,Country
From Customers


-- Shows Revenue vs Products vs Year
Select Product,sum(Revenue) as total_revenue,datepart(YEAR,Date) as Fyear 
From Orders
group by Product,datepart(YEAR,Date)
order by 1,3

-- Shows products vs year vs max Sold_units 
Select Product,max(cast(Units_Sold as int)) as max_sold_units,datepart(YEAR,Date) as Fyear  
From Orders a join Customers b on a.Customer_ID=b.Customer_ID
group by Product,datepart(YEAR,Date) 
order by 1,3

-- Shows products vs city vs total Sold_units 
Select City,Product,sum(Units_Sold) as total_sold_units 
From Orders a join Customers b on a.Customer_ID=b.Customer_ID
group by Product,City
order by 1,2


-- Shows average Units_Sold vs Product vs year
Select Product,avg(Units_Sold) as average_sold_units,datepart(YEAR,Date) as Fyear  
From Orders
group by Product,datepart(YEAR,Date)
order by Product,Fyear


-- USE CTE
-- Shows Sales per products vs year vs city vs total sold units 
With Sales (product,total_Sold_units,City,Fyear)
as
(
Select Product,sum(Units_Sold) total_sold_units,City,datepart(YEAR,Date) as Fyear  
From Orders a join Customers b on a.Customer_ID=b.Customer_ID
group by Product,city,datepart(YEAR,Date) 
)
Select avg(total_Sold_units) as avg_sold_units
From Sales


-- TEMP TABLE
Drop Table if exists #TempSales
Create Table #TempSales
(
product nvarchar(255),
total_sold_units Numeric,
city	nvarchar(255),
Fyear nvarchar(255)
)

Insert into #TempSales
Select Product,sum(Units_Sold) total_sold_units,City,datepart(YEAR,Date) as Fyear  
From Orders a join Customers b on a.Customer_ID=b.Customer_ID
group by Product,city,datepart(YEAR,Date) 

Select *
From #TempSales


-- Creating Views to use them for data visualization
Create View SalesByCity as 
Select City,Product,sum(Units_Sold) as total_sold_units 
From Orders a join Customers b on a.Customer_ID=b.Customer_ID
group by Product,City


-- Creatin view Total Rvenue 
Create View SalesTotalRevenue as
Select Product,sum(Revenue) as total_revenue,datepart(YEAR,Date) as Fyear 
From Orders
group by Product,datepart(YEAR,Date)



