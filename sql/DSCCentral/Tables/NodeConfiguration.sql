CREATE TABLE [dbo].[NodeConfiguration] (
    [NodeConfigurationId] BIGINT         IDENTITY (1, 1) NOT NULL,
    [NodeName]            NVARCHAR (128) NOT NULL,
    [Payload]             NVARCHAR (MAX) NULL,
    [CreateDate]          DATETIME2 (7)  NULL,
    CONSTRAINT [PK_Node] PRIMARY KEY CLUSTERED ([NodeConfigurationId] ASC)
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [NC_NodeName]
    ON [dbo].[NodeConfiguration]([NodeName] ASC);

