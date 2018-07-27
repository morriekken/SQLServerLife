------------------------------------------------------------------------------------------------------------------------
-- Rafal Ziolkowski - 19.07.2018
-- license:mit
------------------------------------------------------------------------------------------------------------------------
CREATE SCHEMA [Life]
GO

CREATE TABLE [Life].[Map](
	[MapId] [int] IDENTITY(1,1) NOT NULL,
	[GameId] [int] NOT NULL,
	[X] [int] NOT NULL,
	[Y] [int] NOT NULL,
	[StateId] [int] NOT NULL,
 CONSTRAINT [PK_Map] PRIMARY KEY CLUSTERED 
(
	[MapId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE PROCEDURE [Life].[InitEmptyGame]
	@GameId INT,
	@Size INT
AS
BEGIN
    -- Create empty square shaped map @Size sized for a new game
    -- We are using recursive CTE in order to create iterator from 1 to @Size
    WITH it AS ( SELECT 1 i UNION ALL SELECT i+1 FROM it WHERE i<@Size )
    INSERT INTO Life.Map (GameId, X, Y, StateId)
    SELECT @GameId, x.i x, y.i y, 0 StateId FROM it x CROSS JOIN it y
    -- By default sql server limits maximum recursive iterations to 100
    -- We are going to take off this cap and set it to unlimited
    OPTION (MAXRECURSION 0)
END
GO

CREATE FUNCTION [Life].[CountNeighbours] (
    @GameId INT,
    @X INT,
    @Y INT
) RETURNS INT
BEGIN
    DECLARE @result INT
    -- X,Y neighbours
    SELECT @result = SUM(StateId) FROM Life.Map 
    WHERE 
	   (
		  (X=@X-1 AND Y=@Y-1) OR (X=@X AND Y=@Y-1) OR (X=@X+1 AND Y=@Y-1) OR
		  (X=@X-1 AND Y=@Y) OR  (X=@X+1 AND Y=@Y) OR
		  (X=@X-1 AND Y=@Y+1) OR (X=@X AND Y=@Y+1) OR (X=@X+1 AND Y=@Y+1)
	   ) AND GameId=@GameId;

	   RETURN @result;
END
GO
		     
CREATE PROCEDURE [Life].[IterateGame]
    @GameId INT
AS 
BEGIN
    -- Get current state and count neighbours
    IF OBJECT_ID('tempdb..#MapCache') IS NOT NULL DROP TABLE #MapCache
    SELECT m.*, Life.CountNeighbours(GameId, X, Y) Neighbours INTO #MapCache FROM Life.Map m WHERE GameId=@GameId

    -- Apply rules
    -- We could do everything in 1 query however for clarity and performance sake we will perform 3 updates for 3 scenarios

    -- Rule 1: Any live cell with fewer than two live neighbors dies, as if by under population.
    UPDATE m SET StateId=0
    FROM Life.Map m INNER JOIN #MapCache mc ON m.MapId=mc.MapId
    WHERE m.GameId=@GameId AND m.StateId=1 AND mc.Neighbours<2;
    
    -- Rule 2: Any live cell with more than three live neighbors dies, as if by overpopulation.
    UPDATE m SET StateId=0
    FROM Life.Map m INNER JOIN #MapCache mc ON m.MapId=mc.MapId
    WHERE m.GameId=@GameId AND m.StateId=1 AND mc.Neighbours>3;

    -- Rule 3: Any dead cell with exactly three live neighbors becomes a live cell, as if by reproduction.
    UPDATE m SET StateId=1
    FROM Life.Map m INNER JOIN #MapCache mc ON m.MapId=mc.MapId
    WHERE m.GameId=@GameId AND m.StateId=0 AND mc.Neighbours=3;

    -- Rule 4: Any live cell with two or three live neighbors lives on to the next generation.
    -- This rule doesn't require any changes to the data
END
GO

CREATE PROCEDURE [Life].[ShowGame]
    @GameId INT
AS
BEGIN
    DECLARE 
	   @columns NVARCHAR(MAX), 
	   @pcolumns NVARCHAR(MAX),
	   @sql NVARCHAR(MAX)

    SET @columns = N''
    SET @pcolumns = N''
    -- This way we can accumulate and concatenate multiple Y values in a variable
    SELECT 
	   @columns += N', MAX(p.' + QUOTENAME(Y) + ') '+ QUOTENAME(Y), 
	   @pcolumns += N', '  + QUOTENAME(Y) 
    FROM Life.Map WHERE GameId=@GameId GROUP BY Y
    
    -- Use dynamic sql to create query for variable size game maps
    -- We are also using PIVOT function to represent Y rows as columns
    -- MAX(StateId) is just for sake of any aggregation function since we are grouping by X
    SET @sql = N' SELECT X, ' + STUFF(@columns, 1, 2, '') + N' FROM Life.Map m PIVOT (MAX(StateId) FOR Y IN (' + STUFF(@pcolumns, 1, 2, '') + N')) p WHERE GameId=@GameId GROUP BY X ORDER BY X';
    
    -- Notice using parameter in dynamic sql in order to avoid sqlinjection attack
    DECLARE @params NVARCHAR(MAX)
    SET @params = '@GameId INT'

    EXEC sp_executesql @sql, @params, @GameId=@GameId;
END
GO
