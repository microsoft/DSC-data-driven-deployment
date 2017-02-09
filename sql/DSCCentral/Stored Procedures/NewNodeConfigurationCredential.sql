
CREATE PROCEDURE [dbo].[NewNodeConfigurationCredential] @NodeName Varchar(128)
	,@CredentialName Varchar(50)
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRANSACTION
	DECLARE @NodeConfigurationId INT,
			@CredentialID INT

	SELECT @NodeConfigurationId = NodeConfigurationId 
	FROM dbo.NodeConfiguration 
	WHERE NodeName = @NodeName

	SELECT @CredentialID = CredentialID
	FROM dbo.Credential
	WHERE CredentialName = @CredentialName

	BEGIN TRY
		INSERT INTO [dbo].[NodeConfigurationCredential] (
			NodeConfigurationId
			,CredentialID
			)
		VALUES (
			@NodeConfigurationId
			,@CredentialID
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