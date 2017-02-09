
CREATE PROCEDURE [dbo].[GetCredentialsforParentConfiguration]
	@ParentConfigurationName NVARCHAR(128)
AS
BEGIN
	SET NOCOUNT ON;

	SELECT CredentialName
		,UserName
		,[Password]
	FROM dbo.[Credential] c
	JOIN ParentConfigurationCredential pcc ON c.CredentialID = pcc.CredentialID
	JOIN ParentConfiguration pc ON pcc.ParentConfigurationID = pc.ParentConfigurationID
	WHERE ParentConfigurationName = @ParentConfigurationName
END