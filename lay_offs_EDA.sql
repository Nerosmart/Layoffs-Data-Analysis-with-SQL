-- Data Cleaning
-- Staging the Database
CREATE TABLE layoffs_staging
LIKE layoffs;

INSERT layoffs_staging
SELECT *
FROM layoffs;

-- 1. Remove Duplicates
WITH CTE_duplicate AS(
SELECT *, 
	ROW_NUMBER() OVER(
    PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) as row_num
FROM layoffs_staging2)

SELECT * 
FROM CTE_duplicate
WHERE row_num > 1;

CREATE TABLE `layoffs_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

SELECT * 
FROM layoffs_staging2;

INSERT layoffs_staging2
SELECT *, 
	ROW_NUMBER() OVER(
    PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) as row_num
FROM layoffs_staging;

DELETE 
FROM layoffs_staging2
WHERE row_num > 1;

-- 2. Standardize the Data
-- Trim the Company Column
UPDATE layoffs_staging2
SET company = trim(company);


SELECT *
FROM layoffs_staging2
WHERE industry LIKE 'Crypto%';

-- Standardize all Crypto Currency industries to Crypto
UPDATE layoffs_staging2
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- Standardize United States
UPDATE layoffs_staging2
SET country = 'United States'
WHERE country LIKE 'United States%';

-- Standardize the Date column from Text to date
UPDATE layoffs_staging2
SET `date` = str_to_date(`date`, '%m/%d/%Y');

ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

-- 3. Null Values or blank values
-- Populating the missing values in the industry column
UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';

UPDATE layoffs_staging2 as t1
	JOIN layoffs_staging2 as t2
    ON t1.company = t2.company
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
	AND t2.industry IS NOT NULL
;

-- Deleting rows with missing values in both total laid off and percentage laid off column
DELETE
FROM layoffs_staging2
WHERE total_laid_off IS NULL
	AND percentage_laid_off IS NULL;

SELECT *
FROM layoffs_staging2
WHERE industry IS NULL 
	OR industry = ''
ORDER BY company;

-- Dropping the row_num column
ALTER TABLE layoffs_staging2
DROP COLUMN row_num;


-- Exploratory Data Analysis
-- Highest Total Laid off and Highest Percentage laid off
SELECT MAX(total_laid_off), MAX(percentage_laid_off)
FROM layoffs_staging2;

-- Companies with 100% laid off -- They absolutely went under
SELECT *
FROM layoffs_staging2
WHERE percentage_laid_off = 1
ORDER BY total_laid_off DESC
;

-- Companies with Highest laid off
SELECT company, SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY company
ORDER BY SUM(total_laid_off) DESC;

-- Most Affected Industries
SELECT industry, SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY industry
ORDER BY SUM(total_laid_off) DESC;

-- Most Affected Countries
SELECT country, SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY country
ORDER BY SUM(total_laid_off) DESC;

-- By year
SELECT YEAR(`date`) as year, SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY YEAR(`date`)
HAVING year IS NOT NULL
ORDER BY YEAR(`date`) DESC;

-- By Stage
SELECT stage, SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY stage
HAVING stage IS NOT NULL
ORDER BY 2 DESC;

-- Checking the Progression of laying offs
WITH rolling_sum AS(
	SELECT SUBSTRING(`date`, 1, 7) AS `MONTH`, 
		SUM(total_laid_off) AS total_laidoff
	FROM layoffs_staging2
	GROUP BY `MONTH`
	HAVING `MONTH` IS NOT NULL
	ORDER BY `MONTH`)

SELECT `MONTH`,
	total_laidoff,
	SUM(total_laidoff) OVER(ORDER BY `MONTH`) AS rolling_total
FROM rolling_sum;

-- Checking the Top 5 companies with the most laid off in each year 
WITH company_year (company, years, total_laid_off) AS 
(
	SELECT company, 
    YEAR(`date`), 
	SUM(total_laid_off) AS total_laid_off
	FROM layoffs_staging2
	GROUP BY company, YEAR(`date`)
),
company_rank AS
(
SELECT *, DENSE_RANK() OVER(PARTITION BY years ORDER BY total_laid_off DESC) AS ranking
FROM company_year
WHERE years IS NOT NULL
)
SELECT *
FROM company_rank
WHERE ranking <= 5;

    