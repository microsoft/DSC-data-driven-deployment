
CREATE PROCEDURE [dbo].[NewParentConfiguration] @ParentConfigurationName NVARCHAR(128)
	,@Payload NVARCHAR(MAX)
	,@ScriptName NVARCHAR(128)
	,@ScriptPath NVARCHAR(255)
AS
BEGIN
		INSERT INTO ParentConfiguration (
			ParentConfigurationName
			,Payload
			,ScriptName
			,ScriptPath
			,CreateDate
			)
		VALUES (
			@ParentConfigurationName
			,@Payload
			,@ScriptName
			,@ScriptPath
			,GETDATE()
			);
END