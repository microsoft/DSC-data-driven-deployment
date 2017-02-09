
CREATE PROCEDURE [dbo].[NewNodeConfiguration] @nodeName NVARCHAR(128)
	,@ParentConfigurationName NVARCHAR(128)
	,@Payload NVARCHAR(max)
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRANSACTION

	DECLARE @NodeConfigurationId BIGINT;
	DECLARE @ParentConfigurationID BIGINT;
	DECLARE @DefaultNodePayload NVARCHAR(max);

	BEGIN TRY

		IF @ParentConfigurationName IS NULL
		BEGIN
			/*We Want the default which is the first record in the table added from setup*/
			SELECT @ParentConfigurationId = ParentConfigurationId
			FROM ParentConfiguration
			WHERE ParentConfigurationId =1
		END
		ELSE 
		BEGIN
			SELECT @ParentConfigurationId = ParentConfigurationId
			FROM ParentConfiguration
			WHERE ParentConfigurationName = @ParentConfigurationName
		END
			
		INSERT INTO [dbo].[NodeConfiguration] (
			NodeName
			,Payload
			,CreateDate
			)
		VALUES (
			@nodename
			,isnull(@Payload, @DefaultNodePayload)
			,getdate()
			);

		SELECT @NodeConfigurationId = SCOPE_IDENTITY();
		SELECT @NodeConfigurationId = NodeConfigurationId
		FROM [dbo].[NodeConfiguration]
		WHERE NodeName = @NodeName

		INSERT INTO [dbo].[ParentNodeConfiguration] (
			NodeConfigurationId
			,ParentConfigurationId
			,CreateDate
			)
		VALUES (
			@NodeConfigurationId
			,@ParentConfigurationID
			,GetDate()
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