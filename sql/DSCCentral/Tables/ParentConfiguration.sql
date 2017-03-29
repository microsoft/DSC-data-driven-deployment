CREATE TABLE [dbo].[ParentConfiguration] (
    [ParentConfigurationID]   BIGINT         IDENTITY (1, 1) NOT NULL,
    [ParentConfigurationName] NVARCHAR (128) NOT NULL,
    [Payload]                 NVARCHAR (MAX) NOT NULL,
    [CreateDate]              DATETIME2 (7)  NOT NULL,
    [ScriptName]              NVARCHAR (128) NULL,
    [ScriptPath]              NVARCHAR (255) NULL,
    CONSTRAINT [PK_Configuration] PRIMARY KEY CLUSTERED ([ParentConfigurationID] ASC)
);

