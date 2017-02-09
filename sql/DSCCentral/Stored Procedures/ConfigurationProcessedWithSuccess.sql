
CREATE PROCEDURE [dbo].[ConfigurationProcessedWithSuccess] (@ConfigurationQueueID BIGINT)
AS
SET NOCOUNT ON;

UPDATE [dbo].[ConfigurationQueue]
SET ProcessStatus = 4
WHERE ConfigurationQueueID = @ConfigurationQueueID