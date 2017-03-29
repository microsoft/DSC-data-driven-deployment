
CREATE PROCEDURE [dbo].[GetConfigurationScript] 
	@ParentConfigurationName nvarchar(128)
AS
BEGIN

	SET NOCOUNT ON;
	BEGIN TRANSACTION 
	DECLARE @ParamPayload nvarchar(MAX);
	DECLARE @ConfigID int
	BEGIN TRY
		SELECT ScriptName,ScriptPath from [dbo].[ParentConfiguration]
		WHERE ParentConfigurationName =@ParentConfigurationName

	END TRY
	BEGIN CATCH
		SELECT 
        ERROR_NUMBER() AS ErrorNumber
        ,ERROR_SEVERITY() AS ErrorSeverity
        ,ERROR_STATE() AS ErrorState
        ,ERROR_PROCEDURE() AS ErrorProcedure
        ,ERROR_LINE() AS ErrorLine
        ,ERROR_MESSAGE() AS ErrorMessage;
		IF @@TRANCOUNT > 0
       ROLLBACK TRANSACTION;
	END CATCH;
	IF @@TRANCOUNT > 0
	COMMIT TRANSACTION 
END