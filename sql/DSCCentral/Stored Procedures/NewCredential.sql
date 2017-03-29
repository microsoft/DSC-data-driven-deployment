
CREATE PROCEDURE [dbo].[NewCredential] @CredentialName VARCHAR(MAX)
	,@UserName VARCHAR(MAX)
	,@Password VARCHAR(MAX)
AS
BEGIN
	INSERT INTO dbo.[Credential]
	VALUES (
		@CredentialName
		,@UserName
		,@Password
		,getdate()
		)
END