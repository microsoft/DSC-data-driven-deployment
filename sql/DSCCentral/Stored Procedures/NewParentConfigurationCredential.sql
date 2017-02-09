
CREATE PROCEDURE [dbo].[NewParentConfigurationCredential] @ParentConfigurationName NVARCHAR(128)
	,@CredentialName Varchar(50)
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRANSACTION

	DECLARE @CredentialID INT,
			@ParentConfigurationID INT

	SELECT @ParentConfigurationID = ParentConfigurationID
	FROM dbo.ParentConfiguration 
	WHERE ParentConfigurationName = @ParentConfigurationName
	
	SELECT @CredentialID = CredentialID
	FROM dbo.Credential
	WHERE CredentialName = @CredentialName

	BEGIN TRY
		INSERT INTO [dbo].[ParentConfigurationCredential] (
			ParentConfigurationID
			,CredentialID
			,CreateDate
			)
		VALUES (
			@ParentConfigurationID
			,@CredentialID
			,getdate()
			);
	END TRY

	BEGIN CATCH
		SELECT ERROR_NUMBER() AS ErrorNumber
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