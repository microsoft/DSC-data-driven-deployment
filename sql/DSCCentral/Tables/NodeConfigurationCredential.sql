CREATE TABLE [dbo].[NodeConfigurationCredential] (
    [NodeConfigurationId] BIGINT NOT NULL,
    [CredentialID]        INT    NOT NULL,
    CONSTRAINT [PK_NodeConfigurationCredential] PRIMARY KEY CLUSTERED ([NodeConfigurationId] ASC, [CredentialID] ASC),
    CONSTRAINT [FK_NodeConfigurationCredential_Credential] FOREIGN KEY ([CredentialID]) REFERENCES [dbo].[Credential] ([CredentialID]),
    CONSTRAINT [FK_NodeConfigurationCredential_Node] FOREIGN KEY ([NodeConfigurationId]) REFERENCES [dbo].[NodeConfiguration] ([NodeConfigurationId])
);

