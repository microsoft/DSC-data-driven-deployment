CREATE TABLE [dbo].[ConfigurationQueue] (
    [ConfigurationQueueID] BIGINT         IDENTITY (1, 1) NOT NULL,
    [Configuration]        NVARCHAR (MAX) NOT NULL,
    [ProcessStatus]        INT            CONSTRAINT [DF_NodeConfigQueue_ProcessStatus] DEFAULT ((1)) NOT NULL,
    [RetryCount]           INT            CONSTRAINT [DF_NodeConfigQueue_RetryCount] DEFAULT ((-1)) NOT NULL,
    [DateAquired]          DATETIME2 (7)  NULL,
    CONSTRAINT [PK_NodeConfigQueue] PRIMARY KEY CLUSTERED ([ConfigurationQueueID] ASC)
);

