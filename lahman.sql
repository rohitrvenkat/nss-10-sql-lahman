-- ## Lahman Baseball Database Exercise
-- - this data has been made available [online](http://www.seanlahman.com/baseball-archive/statistics/) by Sean Lahman
-- - you can find a data dictionary [here](http://www.seanlahman.com/files/database/readme2016.txt)

-- 1. Find all players in the database who played at Vanderbilt University. Create a list showing each player's first and last names as well as the total salary they earned in the major leagues. Sort this list in descending order by the total salary earned. Which Vanderbilt player earned the most money in the majors?
SELECT 
	namefirst, 
	namelast,
	SUM(salary::numeric::money) AS total_salary
FROM people
INNER JOIN salaries
USING (playerid)
WHERE playerid IN (
	SELECT 
		playerid
	FROM collegeplaying
	WHERE schoolid = 'vandy' )
GROUP BY namefirst, namelast
ORDER BY total_salary DESC;


-- 2. Using the fielding table, group players into three groups based on their position: label players with position OF as "Outfield", those with position "SS", "1B", "2B", and "3B" as "Infield", and those with position "P" or "C" as "Battery". Determine the number of putouts made by each of these three groups in 2016.
SELECT 
	CASE
		WHEN pos = 'OF' THEN 'Outfield'
		WHEN pos IN ('SS', '1B', '2B', '3B') THEN 'Infield'
		WHEN pos IN ('P', 'C') THEN 'Battery'
	END AS position,
	SUM(po) AS putouts
FROM fielding
WHERE yearid = 2016
GROUP BY position
ORDER BY putouts DESC;


-- 3. Find the average number of strikeouts per game by decade since 1920. Round the numbers you report to 2 decimal places. Do the same for home runs per game. Do you see any trends? (Hint: For this question, you might find it helpful to look at the **generate_series** function (https://www.postgresql.org/docs/9.1/functions-srf.html). If you want to see an example of this in action, check out this DataCamp video: https://campus.datacamp.com/courses/exploratory-data-analysis-in-sql/summarizing-and-aggregating-numeric-data?ex=6)
SELECT 
	yearid - MOD(yearid, 10) AS decade,
	ROUND(SUM(so) * 2.0 / SUM(g), 2) AS strikeouts_per_game,
	ROUND(SUM(hr) * 2.0 / SUM(g), 2) AS homeruns_per_game
FROM teams
GROUP BY decade
ORDER BY decade DESC;


-- 4. Find the player who had the most success stealing bases in 2016, where __success__ is measured as the percentage of stolen base attempts which are successful. (A stolen base attempt results either in a stolen base or being caught stealing.) Consider only players who attempted _at least_ 20 stolen bases. Report the players' names, number of stolen bases, number of attempts, and stolen base percentage.
SELECT 
	namefirst || ' ' || namelast AS full_name,
	sb AS stolen_bases,
	sb + cs AS stealing_attempts,
	ROUND(sb::numeric / (sb + cs), 2) AS stealing_success_pct
FROM batting
INNER JOIN people
USING (playerid)
WHERE yearid = 2016 
	AND (sb + cs) >= 20
ORDER BY stealing_success_pct DESC;


-- 5. From 1970 to 2016, what is the largest number of wins for a team that did not win the world series? What is the smallest number of wins for a team that did win the world series? Doing this will probably result in an unusually small number of wins for a world series champion; determine why this is the case. Then redo your query, excluding the problem year. How often from 1970 to 2016 was it the case that a team with the most wins also won the world series? What percentage of the time?
SELECT * 
FROM teams
WHERE yearid BETWEEN 1970 AND 2016
	AND wswin = 'N'
ORDER BY w DESC;


SELECT * 
FROM teams
WHERE yearid BETWEEN 1970 AND 2016
	AND wswin = 'Y'
ORDER BY w;


SELECT * 
FROM teams
WHERE yearid BETWEEN 1970 AND 2016
	AND yearid != 1981
	AND wswin = 'Y'
ORDER BY w;


SELECT 
	SUM(CASE WHEN wswin = 'Y' THEN 1 END) AS world_series_wins,
	ROUND(SUM(CASE WHEN wswin = 'Y' THEN 1 END)::numeric / COUNT(*), 3) AS world_series_win_pct
FROM teams
INNER JOIN (
	SELECT yearid, MAX(w) AS w
	FROM teams
	WHERE yearid BETWEEN 1970 AND 2016
	AND wswin IS NOT NULL
	GROUP BY yearid ) AS most_wins_by_year
USING (yearid, w);


-- 6. Which managers have won the TSN Manager of the Year award in both the National League (NL) and the American League (AL)? Give their full name and the teams that they were managing when they won the award.
SELECT
	namefirst || ' ' || namelast AS full_name,
	yearid,
	name AS team,
	lgid
FROM awardsmanagers
INNER JOIN (
	SELECT 
		playerid
	FROM awardsmanagers
	WHERE awardid = 'TSN Manager of the Year'
		AND lgid IN ('AL', 'NL')
	GROUP BY playerid
	HAVING COUNT(DISTINCT lgid) = 2 ) AS both_leagues
USING (playerid)
INNER JOIN people
USING(playerid)
INNER JOIN managers
USING (playerid, yearid, lgid)
INNER JOIN teams
USING (yearid, lgid, teamid)
ORDER BY yearid;


-- 7. Which pitcher was the least efficient in 2016 in terms of salary / strikeouts? Only consider pitchers who started at least 10 games (across all teams). Note that pitchers often play for more than one team in a season, so be sure that you are counting all stats for each player.
SELECT
	namefirst || ' ' || namelast AS full_name,
	SUM(salary)::numeric::money AS salary,
	SUM(so) AS strikeouts,
	SUM(salary)::numeric::money / SUM(so) AS dollars_per_strikeout
FROM pitching
FULL JOIN salaries
USING (playerid, yearid, teamid)
INNER JOIN people
USING (playerid) 
WHERE yearid = 2016
GROUP BY full_name
HAVING SUM(gs) >= 10 
	AND SUM(salary) IS NOT NULL
ORDER BY dollars_per_strikeout DESC;


-- 8. Find all players who have had at least 3000 career hits. Report those players' names, total number of hits, and the year they were inducted into the hall of fame (If they were not inducted into the hall of fame, put a null in that column.) Note that a player being inducted into the hall of fame is indicated by a 'Y' in the **inducted** column of the halloffame table.
SELECT 
	namefirst || ' ' || namelast AS full_name,
	SUM(h) AS career_hits,
	inducted
FROM batting
INNER JOIN people
USING (playerid)
LEFT JOIN (
	SELECT
		playerid,
		yearid AS inducted
	FROM halloffame
	WHERE inducted = 'Y' ) AS hall_of_fame
USING (playerid)
GROUP BY full_name, inducted
HAVING SUM(h) >= 3000
ORDER BY career_hits DESC;


-- 9. Find all players who had at least 1,000 hits for two different teams. Report those players' full names.
SELECT
	namefirst || ' ' || namelast AS full_name,
	string_agg(teamid, ', ') AS teams,
	string_agg(hits::text, ', ') AS hits
FROM (
	SELECT 
		playerid, 
		teamid, 
		SUM(h) AS hits
	FROM batting
	GROUP BY playerid, teamid
	HAVING SUM(h) >= 1000 ) AS hits_by_team
INNER JOIN people
USING (playerid)
GROUP BY full_name
HAVING COUNT(DISTINCT teamid) > 1;


-- 10. Find all players who hit their career highest number of home runs in 2016. Consider only players who have played in the league for at least 10 years, and who hit at least one home run in 2016. Report the players' first and last names and the number of home runs they hit in 2016.
	SELECT 
		namefirst || ' ' || namelast AS full_name,
		hr AS homeruns
	FROM batting
	INNER JOIN (
		SELECT 
			playerid, 
			MAX(hr) AS hr
		FROM batting
		GROUP BY playerid
		HAVING COUNT(DISTINCT yearid) >= 10
		ORDER BY hr DESC ) AS most_hrs
	USING (playerid, hr)
	INNER JOIN people
	USING (playerid)
	WHERE playerid IN (
		SELECT 
			playerid
		FROM batting
		WHERE yearid = 2016 
			AND hr >= 1 )
INTERSECT 
	SELECT 
		namefirst || ' ' || namelast AS full_name,
		hr AS homeruns
	FROM batting
	INNER JOIN people
	USING (playerid)
	WHERE yearid = 2016
ORDER BY homeruns DESC;


-- After finishing the above questions, here are some open-ended questions to consider.

-- **Open-ended questions**

-- 11. Is there any correlation between number of wins and team salary? Use data from 2000 and later to answer this question. As you do this analysis, keep in mind that salaries across the whole league tend to increase together, so you may want to look on a year-by-year basis.
SELECT 
	yearid,
	ROUND(corr(w, team_salary)::numeric, 3) AS wins_salary_corr
FROM (
	SELECT
		yearid, 
		teamid, 
		w, 
		SUM(salary) AS team_salary
	FROM teams
	INNER JOIN salaries
	USING (yearid, teamid)
	WHERE yearid >= 2000
	GROUP BY yearid, teamid, w
	ORDER BY team_salary DESC ) AS wins_salary
GROUP BY yearid
ORDER BY yearid DESC;


-- 12. In this question, you will explore the connection between number of wins and attendance.

--     a. Does there appear to be any correlation between attendance at home games and number of wins?
SELECT 
	yearid,
	ROUND(corr(w, attendance)::numeric, 3) AS wins_attendance_corr
FROM (
	SELECT yearid, teamid, w, SUM(homegames.attendance) AS attendance
	FROM homegames
	INNER JOIN teams
	ON homegames.year = teams.yearid
		AND homegames.team = teams.teamid 
	WHERE year >= 2000
	GROUP BY yearid, teamid, w ) AS wins_attendance
GROUP BY yearid
ORDER BY yearid DESC;


--     b. Do teams that win the world series see a boost in attendance the following year? What about teams that made the playoffs? Making the playoffs means either being a division winner or a wild card winner.
SELECT 
	teams.yearid,
	teams.name,
	world_series_year,
	following_year,
	ROUND((following_year - world_series_year) * 100.0 / world_series_year, 2) AS percent_change
FROM teams
INNER JOIN (
	SELECT
		year AS yearid,
		team AS teamid,
		SUM(attendance) AS world_series_year
	FROM homegames 
	GROUP BY yearid, teamid ) AS world_series_year
USING (yearid, teamid)
INNER JOIN (
	SELECT
		year AS yearid,
		team AS teamid,
		SUM(attendance) AS following_year
	FROM homegames 
	GROUP BY yearid, teamid ) AS following_year
ON teams.yearid + 1 = following_year.yearid
	AND teams.teamid = following_year.teamid
WHERE teams.yearid >= 2000 
	AND wswin = 'Y'
ORDER BY teams.yearid DESC;


SELECT 
	teams.yearid,
	teams.name,
	playoff_year,
	following_year,
	ROUND((following_year - playoff_year) * 100.0 / playoff_year, 2) AS percent_change
FROM teams
INNER JOIN (
	SELECT
		year AS yearid,
		team AS teamid,
		SUM(attendance) AS playoff_year
	FROM homegames 
	GROUP BY yearid, teamid ) AS playoff_year
USING (yearid, teamid)
INNER JOIN (
	SELECT
		year AS yearid,
		team AS teamid,
		SUM(attendance) AS following_year
	FROM homegames 
	GROUP BY yearid, teamid ) AS following_year
ON teams.yearid + 1 = following_year.yearid
	AND teams.teamid = following_year.teamid
WHERE teams.yearid >= 2000 
	AND (divwin = 'Y' OR wcwin = 'Y')
ORDER BY teams.yearid DESC;


-- 13. It is thought that since left-handed pitchers are more rare, causing batters to face them less often, that they are more effective. Investigate this claim and present evidence to either support or dispute this claim. First, determine just how rare left-handed pitchers are compared with right-handed pitchers. Are left-handed pitchers more likely to win the Cy Young Award? Are they more likely to make it into the hall of fame?
SELECT
	decade,
	left_handed_pct,
	cy_young_pct,
	hall_of_fame_pct
FROM (
	SELECT
		'total' AS decade,
		ROUND(SUM(left_handed) * 100.0 / COUNT(*), 2) AS left_handed_pct
	FROM (
		SELECT
			playerid,
			CASE
				WHEN throws = 'L' THEN 1 
				ELSE 0
			END AS left_handed
		FROM pitching
		INNER JOIN people
		USING (playerid)
		GROUP BY playerid, left_handed ) AS pitching
UNION
	SELECT
		decade::text,
		ROUND(SUM(left_handed) * 100.0 / COUNT(*), 2) AS left_handed_pct
	FROM (
		SELECT
			yearid - MOD(yearid, 10) AS decade,
			playerid,
			CASE
				WHEN throws = 'L' THEN 1 
				ELSE 0
			END AS left_handed
		FROM pitching
		INNER JOIN people
		USING (playerid)
		GROUP BY decade, playerid, left_handed ) AS pitching
	GROUP BY decade ) AS left_handed_pct
FULL JOIN (
	SELECT
		'total' AS decade,
		ROUND(SUM(left_handed) * 100.0 / COUNT(*), 2) AS cy_young_pct
	FROM (
		SELECT
			playerid,
			CASE
				WHEN throws = 'L' THEN 1 
				ELSE 0
			END AS left_handed
		FROM pitching
		INNER JOIN people
		USING (playerid)
		WHERE playerid IN (
			SELECT DISTINCT playerid
			FROM awardsplayers
			WHERE awardid = 'Cy Young Award')
		GROUP BY playerid, left_handed ) AS pitching
UNION
	SELECT
		decade::text,
		ROUND(SUM(left_handed) * 100.0 / COUNT(*), 2) AS cy_young_pct
	FROM (
		SELECT
			yearid - MOD(yearid, 10) AS decade,
			playerid,
			CASE
				WHEN throws = 'L' THEN 1 
				ELSE 0
			END AS left_handed
		FROM pitching
		INNER JOIN people
		USING (playerid)
		WHERE playerid IN (
			SELECT DISTINCT playerid
			FROM awardsplayers
			WHERE awardid = 'Cy Young Award')
		GROUP BY decade, playerid, left_handed ) AS pitching
	GROUP BY decade ) AS cy_young_pct
USING (decade)
FULL JOIN (
	SELECT
		'total' AS decade,
		ROUND(SUM(left_handed) * 100.0 / COUNT(*), 2) AS hall_of_fame_pct
	FROM (
		SELECT
			playerid,
			CASE
				WHEN throws = 'L' THEN 1 
				ELSE 0
			END AS left_handed
		FROM pitching
		INNER JOIN people
		USING (playerid)
		WHERE playerid IN (
			SELECT DISTINCT playerid
			FROM halloffame
			WHERE inducted = 'Y')
		GROUP BY playerid, left_handed ) AS pitching
UNION
	SELECT
		decade::text,
		ROUND(SUM(left_handed) * 100.0 / COUNT(*), 2) AS hall_of_fame_pct
	FROM (
		SELECT
			yearid - MOD(yearid, 10) AS decade,
			playerid,
			CASE
				WHEN throws = 'L' THEN 1 
				ELSE 0
			END AS left_handed
		FROM pitching
		INNER JOIN people
		USING (playerid)
		WHERE playerid IN (
			SELECT DISTINCT playerid
			FROM halloffame
			WHERE inducted = 'Y')
		GROUP BY decade, playerid, left_handed ) AS pitching
	GROUP BY decade ) AS hall_of_fame_pct
USING (decade)
ORDER BY decade DESC;


-- In these exercises, you'll explore a couple of other advanced features of PostgreSQL. 

-- 1. In this question, you'll get to practice correlated subqueries and learn about the LATERAL keyword. Note: This could be done using window functions, but we'll do it in a different way in order to revisit correlated subqueries and see another keyword - LATERAL.

-- a. First, write a query utilizing a correlated subquery to find the team with the most wins from each league in 2016.
SELECT DISTINCT 
	lgid,
	(SELECT name
	 FROM teams AS st
	 WHERE st.lgid = t.lgid
	 	AND yearid = 2016
	 ORDER BY w DESC
	 LIMIT 1)
FROM teams AS t
WHERE yearid = 2016;


-- b. One downside to using correlated subqueries is that you can only return exactly one row and one column. This means, for example that if we wanted to pull in not just the teamid but also the number of wins, we couldn't do so using just a single subquery. (Try it and see the error you get). Add another correlated subquery to your query on the previous part so that your result shows not just the teamid but also the number of wins by that team.
SELECT DISTINCT 
	lgid,
	(SELECT name
	 FROM teams AS st
	 WHERE st.lgid = t.lgid
	 	AND yearid = 2016
	 ORDER BY w DESC
	 LIMIT 1),
	(SELECT w
	 FROM teams AS st
	 WHERE st.lgid = t.lgid
	 	AND yearid = 2016
	 ORDER BY w DESC
	 LIMIT 1)	 
FROM teams AS t
WHERE yearid = 2016;


-- c. If you are interested in pulling in the top (or bottom) values by group, you can also use the DISTINCT ON expression (https://www.postgresql.org/docs/9.5/sql-select.html#SQL-DISTINCT). Rewrite your previous query into one which uses DISTINCT ON to return the top team by league in terms of number of wins in 2016. Your query should return the league, the teamid, and the number of wins.
SELECT 
	DISTINCT ON (lgid)
	lgid,
	name,
	w
FROM teams AS t
WHERE yearid = 2016
ORDER BY lgid, w DESC;


-- d. If we want to pull in more than one column in our correlated subquery, another way to do it is to make use of the LATERAL keyword (https://www.postgresql.org/docs/9.4/queries-table-expressions.html#QUERIES-LATERAL). This allows you to write subqueries in FROM that make reference to columns from previous FROM items. This gives us the flexibility to pull in or calculate multiple columns or multiple rows (or both). Rewrite your previous query using the LATERAL keyword so that your result shows the teamid and number of wins for the team with the most wins from each league in 2016. 
SELECT *
FROM (
	SELECT 
		DISTINCT lgid 
		FROM teams
	  	WHERE yearid = 2016) AS leagues,
	  		LATERAL (
				SELECT
					name,
					w
			  	FROM teams AS t
			  	WHERE leagues.lgid = t.lgid
			   		AND yearid = 2016
			  	ORDER BY w DESC
			  	LIMIT 1 ) as top_teams;


-- If you want a hint, you can structure your query as follows:

-- SELECT *
-- FROM (SELECT DISTINCT lgid 
-- 	  FROM teams
-- 	  WHERE yearid = 2016) AS leagues,
-- 	  LATERAL ( <Fill in a subquery here to retrieve the teamid and number of wins> ) as top_teams;
	  
-- e. Finally, another advantage of the LATERAL keyword over using correlated subqueries is that you return multiple result rows. (Try to return more than one row in your correlated subquery from above and see what type of error you get). Rewrite your query on the previous problem sot that it returns the top 3 teams from each league in term of number of wins. Show the teamid and number of wins.


-- 2. Another advantage of lateral joins is for when you create calculated columns. In a regular query, when you create a calculated column, you cannot refer it it when you create other calculated columns. This is particularly useful if you want to reuse a calculated column multiple times. For example,

-- SELECT 
-- 	teamid,
-- 	w,
-- 	l,
-- 	w + l AS total_games,
-- 	w*100.0 / total_games AS winning_pct
-- FROM teams
-- WHERE yearid = 2016
-- ORDER BY winning_pct DESC;

-- results in the error that "total_games" does not exist. However, I can restructure this query using the LATERAL keyword.

-- SELECT
-- 	teamid,
-- 	w,
-- 	l,
-- 	total_games,
-- 	w*100.0 / total_games AS winning_pct
-- FROM teams t,
-- LATERAL (
-- 	SELECT w + l AS total_games
-- ) AS tg
-- WHERE yearid = 2016
-- ORDER BY winning_pct DESC;

-- a. Write a query which, for each player in the player table, assembles their birthyear, birthmonth, and birthday into a single column called birthdate which is of the date type.

-- b. Use your previous result inside a subquery using LATERAL to calculate for each player their age at debut and age at retirement. (Hint: It might be useful to check out the PostgreSQL date and time functions https://www.postgresql.org/docs/8.4/functions-datetime.html).

-- c. Who is the youngest player to ever play in the major leagues?

-- d. Who is the oldest player to player in the major leagues? You'll likely have a lot of null values resulting in your age at retirement calculation. Check out the documentation on sorting rows here https://www.postgresql.org/docs/8.3/queries-order.html about how you can change how null values are sorted.

-- 3. For this question, you will want to make use of RECURSIVE CTEs (see https://www.postgresql.org/docs/13/queries-with.html). The RECURSIVE keyword allows a CTE to refer to its own output. Recursive CTEs are useful for navigating network datasets such as social networks, logistics networks, or employee hierarchies (who manages who and who manages that person). To see an example of the last item, see this tutorial: https://www.postgresqltutorial.com/postgresql-recursive-query/. 
-- In the next couple of weeks, you'll see how the graph database Neo4j can easily work with such datasets, but for now we'll see how the RECURSIVE keyword can pull it off (in a much less efficient manner) in PostgreSQL. (Hint: You might find it useful to look at this blog post when attempting to answer the following questions: https://data36.com/kevin-bacon-game-recursive-sql/.)

-- a. Willie Mays holds the record of the most All Star Game starts with 18. How many players started in an All Star Game with Willie Mays? (A player started an All Star Game if they appear in the allstarfull table with a non-null startingpos value).

-- b. How many players didn't start in an All Star Game with Willie Mays but started an All Star Game with another player who started an All Star Game with Willie Mays? For example, Graig Nettles never started an All Star Game with Willie Mayes, but he did star the 1975 All Star Game with Blue Vida who started the 1971 All Star Game with Willie Mays.

-- c. We'll call two players connected if they both started in the same All Star Game. Using this, we can find chains of players. For example, one chain from Carlton Fisk to Willie Mays is as follows: Carlton Fisk started in the 1973 All Star Game with Rod Carew who started in the 1972 All Star Game with Willie Mays. Find a chain of All Star starters connecting Babe Ruth to Willie Mays. 

-- d. How large a chain do you need to connect Derek Jeter to Willie Mays?