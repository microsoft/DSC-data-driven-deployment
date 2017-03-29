CREATE TABLE [dbo].[NodeConfigurationDefault] (
    [DefaultID]             INT            IDENTITY (1, 1) NOT NULL,
    [NodeConfigurationName] NVARCHAR (128) NOT NULL,
    [Payload]               NVARCHAR (MAX) NOT NULL,
    CONSTRAINT [PK_Defaults] PRIMARY KEY CLUSTERED ([DefaultID] ASC)
);

