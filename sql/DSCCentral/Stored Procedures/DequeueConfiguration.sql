
CREATE PROCEDURE [dbo].[DequeueConfiguration] (@BatchSize INT)
AS
SET NOCOUNT ON;

-- New approach, process claims batch of 1 or more rows responsible for updating the
-- status of each message as complete successfully, complete needs retry, complete
-- and done retrying (max retries).
--ProcessId = 1 - New Messages
--ProcessId = 2 - In Process
--ProcessId = 3 - Message needs retry
--ProcessId = 4 - Complete (Success)
--ProcessId = 5 - Complete (Failure, max retry, poison message)
UPDATE TOP (@BatchSize) [ConfigurationQueue]
SET DateAquired = SYSUTCDATETIME()
	,ProcessStatus = 2
	,-- In Process
	RetryCount = RetryCount + 1
OUTPUT inserted.ConfigurationQueueID
	,inserted.Configuration
WHERE ProcessStatus IN (
		1,
		2,
		3
		)
AND (DateAquired is null OR DATEDIFF(MINUTE,DateAquired,SYSUTCDATETIME()) > 8) and RetryCount < 4

UPDATE [ConfigurationQueue]
SET ProcessStatus = 5 
WHERE RetryCount > = 4