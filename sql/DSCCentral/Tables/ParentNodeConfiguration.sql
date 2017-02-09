CREATE TABLE [dbo].[ParentNodeConfiguration] (
    [NodeConfigurationId]   BIGINT        NOT NULL,
    [ParentConfigurationId] BIGINT        NOT NULL,
    [CreateDate]            DATETIME2 (7) NULL,
    CONSTRAINT [PK_ServerConfiguration] PRIMARY KEY CLUSTERED ([NodeConfigurationId] ASC, [ParentConfigurationId] ASC),
    CONSTRAINT [FK_ServerConfiguration_Configuration1] FOREIGN KEY ([ParentConfigurationId]) REFERENCES [dbo].[ParentConfiguration] ([ParentConfigurationID])
);

