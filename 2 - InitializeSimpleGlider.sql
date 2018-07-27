-- Create empty map
EXEC Life.InitEmptyGame 1, 20

-- Create simple glider in left top corner
UPDATE Life.Map SET
    StateId=1
WHERE (X=2 AND Y=2) OR (X=3 AND Y=3) OR (X=3 AND Y=4) OR (X=4 AND Y=2) OR (X=4 AND Y=3)