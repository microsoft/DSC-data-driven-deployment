
CREATE PROCEDURE [dbo].[GetNodeConfiguration] @nodeName NVARCHAR(128)
	,@ParentConfigurationName NVARCHAR(128)
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRANSACTION

	DECLARE @ParamPayload NVARCHAR(MAX);

	BEGIN TRY
		SELECT @ParamPayload = Payload
		FROM [dbo].[NodeConfiguration]
		WHERE Nodename = @nodeName

		IF @ParamPayload IS NULL
		BEGIN
			DECLARE @return_value INT

			EXEC @return_value = dbo.NewNodeConfigurationfromDefault @NodeName = @nodeName
				,@ParentConfigurationName = @ParentConfigurationName
				,@NodeConfigurationName = NULL
				,@Payload = NULL
		END

		SELECT Payload
		FROM [dbo].[NodeConfiguration]
		WHERE Nodename = @nodeName
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