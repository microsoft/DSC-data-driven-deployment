CREATE TABLE [dbo].[ParentConfigurationCredential] (
    [ParentConfigurationID] BIGINT        NOT NULL,
    [CredentialID]          INT           NOT NULL,
    [CreateDate]            DATETIME2 (7) NOT NULL,
    CONSTRAINT [PK_ConfigurationCredential] PRIMARY KEY CLUSTERED ([ParentConfigurationID] ASC, [CredentialID] ASC),
    CONSTRAINT [FK_ConfigurationCredential_Configuration] FOREIGN KEY ([ParentConfigurationID]) REFERENCES [dbo].[ParentConfiguration] ([ParentConfigurationID]),
    CONSTRAINT [FK_ConfigurationCredential_Credential] FOREIGN KEY ([CredentialID]) REFERENCES [dbo].[Credential] ([CredentialID])
);

