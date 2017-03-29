
CREATE PROCEDURE [dbo].[ConfigurationProcessedWithFailure] (@ConfigurationQueueID BIGINT)
AS
SET NOCOUNT ON;

DECLARE @MaxRetry INT = 3

UPDATE [dbo].[ConfigurationQueue]
SET ProcessStatus = CASE 
		WHEN RetryCount < @MaxRetry
			THEN 3 -- Needs retry
		ELSE 5 -- Retries exhausted
		END
WHERE ConfigurationQueueID = @ConfigurationQueueID