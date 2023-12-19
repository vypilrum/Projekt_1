-- Projekt SQL

-- tvorba tabulky t_Jan_Pospisil_project_SQL_primary_final


-- zkoumání zdrojových dat 
select *
from czechia_price cp ;

select *
from czechia_price_category cpc ;

select *
from czechia_price cp
group by category_code; -- 27 položek - odpovídá czechia price category code

select *
from czechia_payroll cp;


select *
from czechia_payroll_calculation cpc ;  -- 100 fyzický
									 	-- 200 přepočtený

select *
from czechia_payroll_industry_branch ; -- code A - zemědělství, B - Těžba a dobývání,  C.. ,  D..,  atd.... 19 položek


select *
from czechia_payroll_unit;  -- pouze jednotka 200 Kč , 80 403 tis. osob, 2 položky


select *
from czechia_payroll_value_type; -- 316 Průměrný počet zaměstnaných osob 
								 -- 5 958 Průměrná hrubá mzda na zaměstnance 
 

select *
from czechia_payroll cp
where value is not null 
	  and value_type_code = 5958
	  and unit_code = 200;

-- dále potřeba udělat průměr hodnot z jednotlivých kvartálů pro každý rok 

create or replace view jan_pospisil_avg_pay_by_year AS
SELECT 
	id ,
	round(AVG (value), 0) as avg_pay,
	industry_branch_code ,
	payroll_year 
from czechia_payroll cp
where value is not null 
	  and value_type_code = 5958
	  and unit_code = 200
	  and calculation_code = 100
	  and industry_branch_code is not null  
group by payroll_year, industry_branch_code
order by industry_branch_code, payroll_year;

select *
from jan_pospisil_avg_pay_by_year
order by industry_branch_code, payroll_year;

-- testování lagged

SELECT 
	     id ,
	     LAG(avg_pay) OVER (ORDER by industry_branch_code, payroll_year)  AS lag_avg_pay,
	     industry_branch_code 
FROM jan_pospisil_avg_pay_by_year jpapby ;


-- použít partition by industry type ?? 
-- funkce LAG - začátek druhé hodiny - minulá lekce 11
-- AVG() (PARTITION BY country ORDER by date rows between 2 precending and 2 following předchozí 2 následující
-- COALESCE (confirmed, 0) AS confirmed -- missing VALUES dej nulu

-- ÚKOL 1
-- tvorba celého scriptu -- výsledkem je tabulka meziročních růstů či poklesů mezd, rok 2000 odfiltrován- nejsou data za 1999, není možné určit meziroční růst. 
-- Z tabulky jsem dále vytřídil jen ty roky a odvětví, které jasně dokazují, ve kterých letech a odvětvích mzdy klesaly. 

-- první select
with avg_pay_by_year as (
	SELECT 
		id ,
		round(AVG (value), 0) as avg_pay,
		industry_branch_code ,
		payroll_year 
	from czechia_payroll cp
	where value is not null 
		  and value_type_code = 5958
		  and unit_code = 200
		  and calculation_code = 100
		  and industry_branch_code is not null  
	group by payroll_year, industry_branch_code
	order by industry_branch_code, payroll_year
), -- druhý select
lagged_avg_pay_by_year AS (
	SELECT 
		     id ,
		     avg_pay,
		     LAG(avg_pay) OVER (ORDER by industry_branch_code, payroll_year)  AS lag_avg_pay,
		     industry_branch_code,
		     payroll_year
	FROM avg_pay_by_year 
), -- třetí select - tabulka růstů a poklesů
vysledny_rust as (
	SELECT 
		 id,
		 ROUND((avg_pay/lag_avg_pay - 1)*100,1) AS growth_perc,
		 industry_branch_code,
		 payroll_year
	FROM lagged_avg_pay_by_year
	where payroll_year != 2000 -- nejsou data za 1999, proto vyřadit
) -- výběr let a odvětví, kdy mzdy klesaly
select 
	vr.growth_perc,
	vr.payroll_year,
	cpib.name
from vysledny_rust vr
JOIN  czechia_payroll_industry_branch cpib
	ON vr. industry_branch_code = cpib.code
where growth_perc < 0
order by payroll_year, growth_perc;

-- ODPOVĚĎ -  Nedá se říct, že mzdy rostou ve všech odvětvích. V tabulce vidíme, že časté poklesy během sledovaných let jsou v odvětví těžby a dobývání.
--  v letech 2009 až 2011 a 2020 byly nejčastější poklesy v ubytování a stravonaní a pohostinství či veřejné správě a obraně. V roce 2021 se projevuje COVID a 
-- je znát pokles kulturní a zábavní činnosti.


-- úkol 2
-- funkce year
SELECT  *
FROM czechia_price cp 
WHERE category_code = 114701
GROUP BY region_code , date_from ;

-- partition by - zkouška - nakonec nepoužito
-- sesekat na roky
SELECT 
	id,
	AVG(value) OVER (PARTITION BY category_code ORDER BY date_from) AS average,
	category_code, 
	region_code,
	year(date_from) as rok_pocatku
 FROM czechia_price cp 
WHERE 1=1
 AND date_from >= '2007-05-01' 

-- jiný způsob... celý script - ODPOVĚĎ NA OTÁZKU výsledná tabulka 
WITH mleko_chleba AS (
	SELECT 
		id,
		round(AVG(value),2) AS average,
		category_code, 
		year(date_from) AS rok_sberu
	FROM czechia_price cp 
	WHERE category_code = 114201 OR category_code = 111301
	GROUP BY category_code, rok_sberu
),
prumerny_plat AS (
	SELECT
		id ,
		round(AVG (value), 0) AS avg_pay,
		payroll_year
	FROM czechia_payroll cp
	WHERE value IS NOT NULL 
		  AND value_type_code = 5958
		  AND unit_code = 200
		  AND calculation_code = 100
		  AND industry_branch_code IS NOT NULL
		  AND value_type_code 
		  AND payroll_year = 2006 OR payroll_year = 2018
	GROUP BY payroll_year
	ORDER BY payroll_year
)
SELECT 
	pp.*,
	mc.average,
	mc.category_code,
	ROUND(avg_pay/average,0) AS mnozstvi_lze_koupit
FROM prumerny_plat pp
JOIN mleko_chleba mc
	ON pp.payroll_year = mc.rok_sberu;
-- mléko 114201, chléb 111301

-- ODPOVĚĎ: V prvním sledovaném období v roce 2006 lze koupit za průměrnou výplatu 1409 litrů  mléka a 1262 kg chleba
-- V roce 2018 to bylo 1508 litrů mléka a 1233 kg chleba 


-- Úkol 3 nezapomenout seřadit !!!!
WITH kat_rust AS (	
SELECT 
		id,
		round(AVG(value),2) AS average,
		category_code, 
		year(date_from) AS rok_sberu
	FROM czechia_price cp 
	GROUP BY category_code, rok_sberu
),
kat_rust_lag AS (
SELECT
	id,
	average,
	LAG(average) OVER (ORDER by category_code, rok_sberu)  AS lag_average,
	category_code,
	rok_sberu	
FROM kat_rust
),
vysl_neserazeny AS (
	SELECT 
		average,
		lag_average,
		category_code,
		rok_sberu,
		ROUND((average/lag_average - 1)*100,1) AS growth_perc
	FROM kat_rust_lag
	WHERE rok_sberu != 2006 -- není s čím rovnat;
) -- vysledna tabulka
SELECT 
	cpc.name,
	rok_sberu, 
	growth_perc
FROM vysl_neserazeny vn
LEFT JOIN czechia_price_category cpc
	ON vn.category_code = cpc.code
GROUP BY category_code, rok_sberu
ORDER BY rok_sberu, growth_perc
;	
--  ODPOVĚĎ: výsledná tabulak seřazena po letech podle kategorií od nejnižšího po nejvyšší růtst. 
-- Vidíme, že např. mezi lety 2006 a 2007 klesla nejvíce cena jablek a nejpomaleji rostl rostlinný tuk
-- napoak nejrychleji rostla cena paprik a to o 94,8 %


-- ÚKOL č. 4
SELECT *
FROM jan_pospisil_rust_cen;

SELECT *
FROM jan_pospisil_avg_pay_by_year
ORDER BY industry_branch_code, payroll_year;

CREATE OR REPLACE VIEW jan_pospisil_rust_mezd AS -- bez ohledu na odvětví, pouze meziroční růsty
WITH avg_pay_by_year AS (
	SELECT 
		id,
		round(AVG (value), 0) as avg_pay,
		payroll_year 
	from czechia_payroll cp
	where value is not null 
		  and value_type_code = 5958
		  and unit_code = 200
		  and calculation_code = 100
		  and industry_branch_code is not null  
	group by payroll_year
	order by payroll_year
),
lagged_avg_pay_by_year AS (
	SELECT 
		     id ,
		     avg_pay,
		     LAG(avg_pay) OVER (ORDER by payroll_year)  AS lag_avg_pay,
		     payroll_year
	FROM avg_pay_by_year 
)
SELECT 
		 payroll_year,
		 ROUND((avg_pay/lag_avg_pay - 1)*100,1) AS mzdy_growth_perc
FROM lagged_avg_pay_by_year
	where payroll_year != 2000 -- nejsou data za 1999, proto vyřadit

-- tabulka meziročního růstu cen potravin bez ohledu na druh potravin, pouze průměrné ceny	
	
CREATE OR REPLACE VIEW jan_pospisil_rust_cen AS -- bez ohledu na druh zbozi
WITH kat_rust AS (	
SELECT 
		id,
		round(AVG(value),2) AS average,
		year(date_from) AS rok_sberu
	FROM czechia_price cp 
	GROUP BY rok_sberu
),
kat_rust_lag AS (
SELECT
	id,
	average,
	LAG(average) OVER (ORDER by rok_sberu)  AS lag_average,
	rok_sberu	
FROM kat_rust
),
vysl_neserazeny AS (
	SELECT 
		average,
		lag_average,
		rok_sberu,
		ROUND((average/lag_average - 1)*100,1) AS ceny_growth_perc
	FROM kat_rust_lag
	WHERE rok_sberu != 2006 -- není s čím rovnat;
) -- vysledna tabulka
SELECT 
	rok_sberu, 
	ceny_growth_perc
FROM vysl_neserazeny vn
GROUP BY rok_sberu
ORDER BY rok_sberu;
	
	
SELECT *
FROM jan_pospisil_rust_cen;	
	
SELECT *
FROM jan_pospisil_rust_mezd;

-- ODPOVĚĎ NA OTÁZKU výsledná tabulka

SELECT
	jprc.*,
	jprm.mzdy_growth_perc
FROM jan_pospisil_rust_cen	jprc
LEFT JOIN jan_pospisil_rust_mezd jprm
	ON rok_sberu = payroll_year
WHERE ceny_growth_perc - mzdy_growth_perc > 10  

-- ODPOVĚĎ : Není žádný rok, ve kterm by růst cen překračoval růst mezd o více než 10 procent. 

-- ÚKOL 5
create or replace view jan_pospisiL_GDP_rust as 
with czech_GDP as (
select 
	country,
	`year` ,
	GDP
from economies e
where country = 'Czech Republic' and GDP is not NULL
order by `year` 
),
czech_GDP_lag as (
select 
	country,
	`year` ,
	GDP,
	LAG(GDP) OVER (ORDER by `year`)  AS lag_GDP	
FROM czech_GDP
)
SELECT 
	country,
	`year` ,
	GDP,
	lag_GDP,
	ROUND((GDP/lag_GDP - 1)*100,1) AS GDP_growth_perc
FROM czech_GDP_lag
WHERE `year`!= 1990; -- není s čím rovnat;

-- z předchozího úkolu - růst cen a mezd v letech

CREATE OR REPLACE VIEW jan_pospisiL_mzdy_vs_ceny AS
SELECT
	jprc.*,
	jprm.mzdy_growth_perc
FROM jan_pospisil_rust_cen	jprc
LEFT JOIN jan_pospisil_rust_mezd jprm
	ON rok_sberu = payroll_year;



select*
from jan_pospisiL_mzdy_vs_ceny

select*
from jan_pospisiL_GDP_rust

-- srovnání 
SELECT
	jpgr.country,
	jpgr.year,
	jpgr.GDP_growth_perc,
	jpmvc.ceny_growth_perc,
	jpmvc.mzdy_growth_perc
FROM jan_pospisil_GDP_rust	jpgr
JOIN jan_pospisil_mzdy_vs_ceny jpmvc 
	on jpgr.year = jpmvc.rok_sberu;

-- ODPOVĚĎ:  Výsledné hodnoty by bylo vhodné zobrazit do grafu. Je patrné, že mzdy rostou pomaleji v letech slabších výsledků nebo poklesů HDP. 
