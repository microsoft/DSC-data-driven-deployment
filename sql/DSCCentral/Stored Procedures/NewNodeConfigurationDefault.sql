CREATE PROCEDURE [dbo].[NewNodeConfigurationDefault]
	@NodeConfigurationName NVARCHAR(128)
	,@Payload NVARCHAR(max)
AS
BEGIN
		INSERT INTO [dbo].[NodeConfigurationDefault] (
			NodeConfigurationName
			,Payload
			)
		VALUES (
			@NodeConfigurationName
			,@Payload
			);
END