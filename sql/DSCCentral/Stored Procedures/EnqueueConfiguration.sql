
CREATE PROCEDURE [dbo].[EnqueueConfiguration] @Configuration NVARCHAR(MAX)
AS
SET NOCOUNT ON;

INSERT INTO [dbo].[ConfigurationQueue] (Configuration)
VALUES (@Configuration)