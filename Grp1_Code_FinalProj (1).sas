%web_drop_table(WORK.IMPORT);


FILENAME REFFILE '/home/u64032493/sasuser.v94/ASDS5301-Final-Grp1/garments_worker_productivity.csv';

PROC IMPORT DATAFILE=REFFILE
	DBMS=CSV
	OUT=PROD;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=PROD; RUN;
/*
date			:	Date in MM-DD-YYYY
day			:	Day of the Week
quarter			:	A portion of the month. A month was divided into four quarters
department		:	Associated department with the instance
team_no			:	Associated team number with the instance
no_of_workers		:	Number of workers in each team
no_of_style_change	:	Number of changes in the style of a particular product
targeted_productivity	:	Targeted productivity set by the Authority for each team for each day.
smv			:	Standard Minute Value, it is the allocated time for a task
wip			:	Work in progress. Includes the number of unfinished items for products
over_time		:	Represents the amount of overtime by each team in minutes
incentive		:	Represents the amount of financial incentive (in BDT) that enables or motivates a particular course of action.
idle_time		:	The amount of time when the production was interrupted due to several reasons
idle_men		:	The number of workers who were idle due to production interruption
actual_productivity	:	The actual % of productivity that was delivered by the workers. It ranges from 0-1.
*/

/* Data Cleaning */

/* Renaming the ambiguous variables */
DATA PROD;
	SET PROD;
	RENAME wip = work_in_progress;
	RENAME smv = standard_minute_value;
RUN;

/* Dropping the redundant columns from the dataset */
DATA PROD;
	SET PROD;
	DROP date;
RUN;

/* Checking the missing values for all our variables */
PROC MEANS DATA=PROD N NMISS;
RUN;
/* Only the variable wip has missing values (506) */

/* Checking correlations of work_in_progress with other features for imputation */
PROC CORR DATA=PROD;
	/*VAR work_in_progress over_time incentive idle_time actual_productivity standard_minute_value;*/
RUN;

/* MI Imputation on the work_in_progress column */ 
PROC MI DATA=PROD nimpute=1 OUT=IMPUTED_DATA;
	VAR work_in_progress incentive; /* Predicting the missing values of work_in_progress with the help of incentive */
RUN;

PROC MEANS DATA=IMPUTED_DATA N NMISS;
RUN;
/* As you can see the missing values are imputed */

PROC MEANS DATA=IMPUTED_DATA;
RUN;

proc sgplot data=IMPUTED_DATA;
    vbox work_in_progress;
    title "Boxplots for Each Variable";
run;
proc sgplot data=IMPUTED_DATA;
    vbox targeted_productivity / boxwidth=0.5;
    title "Boxplots for Each Variable";
run;
proc sgplot data=IMPUTED_DATA;
    vbox standard_minute_value / boxwidth=0.5;
    title "Boxplots for Each Variable";
run;

/* Calculate IQR and create a dataset with Q1 and Q3 */
PROC UNIVARIATE DATA=IMPUTED_DATA NOPRINT;
    VAR work_in_progress;
    OUTPUT OUT=IQR_wip Q1=Q1 Q3=Q3;
RUN;
/* Identify Outliers Using IQR */
DATA IMPUTED_DATA;
    SET IMPUTED_DATA;
    /* Merge IQR values */
    IF _N_ = 1 THEN SET IQR_wip;
    IQR = Q3 - Q1;
    LOWER_BOUND = Q1 - 1.5 * IQR;
    UPPER_BOUND = Q3 + 1.5 * IQR;
    /* Remove Outliers */
    IF actual_productivity < LOWER_BOUND OR actual_productivity > UPPER_BOUND THEN 
        DELETE;
RUN;



DATA IMPUTED_DATA;
    SET IMPUTED_DATA;
    IF actual_productivity >= targeted_productivity THEN success = 1;
    ELSE IF actual_productivity < targeted_productivity THEN success = 0;
RUN;


/*
Null Hypothesis: The mean of actual productivity is equal to the mean of targeted_productivity.
Alternate Hypothesis: The mean of actual productivity is more than the mean of targeted_productivity.
*/

/*
Independence: As it is a real world dataset of worker productivity, we need to assume that one's productivity does not impact the other in any way
*/
/* Normality: Q-Q plot (or) Histogram */
PROC UNIVARIATE DATA=IMPUTED_DATA NORMAL;
    CLASS success;
    VAR work_in_progress;
    QQPLOT work_in_progress / NORMAL(MU=EST SIGMA=EST);
    TITLE "Q-Q Plot of work_in_progress by success";
RUN;


/*
PROC TTEST DATA=IMPUTED_DATA ALPHA=.05;
	TITLE "Two sample T-Test";
	CLASS success;
	VAR work_in_progress;
RUN;
*/

PROC TTEST DATA=IMPUTED_DATA ALPHA=.05 SIDES=U;
	TITLE "Paired T-Test";
	PAIRED actual_productivity*targeted_productivity;
RUN;