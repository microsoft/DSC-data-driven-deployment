CREATE TABLE [dbo].[Credential] (
    [CredentialID]   INT           IDENTITY (1, 1) NOT NULL,
    [CredentialName] VARCHAR (50)  NOT NULL,
    [UserName]       VARCHAR (MAX) NOT NULL,
    [Password]       VARCHAR (MAX) NOT NULL,
    [CreateDate]     DATETIME2 (7) NULL,
    CONSTRAINT [PK_Cred] PRIMARY KEY CLUSTERED ([CredentialID] ASC)
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [NC_CredentialName]
    ON [dbo].[Credential]([CredentialName] ASC);

