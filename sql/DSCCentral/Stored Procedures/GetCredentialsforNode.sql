
CREATE PROCEDURE [dbo].[GetCredentialsforNode]
	@ParentConfigurationName NVARCHAR(128)
	,@NodeName NVARCHAR(128)
AS
BEGIN
	SET NOCOUNT ON;

	SELECT CredentialName
		,UserName
		,[Password]
	FROM dbo.[Credential] c
	JOIN NodeConfigurationCredential ncc ON c.CredentialID = ncc.CredentialID
	JOIN NodeConfiguration nc ON ncc.NodeConfigurationId = nc.NodeConfigurationId
	JOIN ParentNodeConfiguration pnc ON nc.NodeConfigurationId = pnc.NodeConfigurationId
	JOIN ParentConfiguration pc ON pnc.ParentConfigurationId = pc.ParentConfigurationId
	WHERE pc.ParentConfigurationName = @ParentConfigurationName
		AND nc.NodeName = @NodeName
END