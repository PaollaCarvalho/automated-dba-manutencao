



CREATE OR ALTER PROCEDURE dbo.procAtualiza_Indices
AS
BEGIN

    SET NOCOUNT ON; -- desliga mensagem de contagem de linha

    IF CAST(GETDATE() AS TIME) > '06:00:00' -- verificação do horário
    BEGIN
        RETURN
    END

    DECLARE							-- declaração de variaveis
        @SchemaName     NVARCHAR(128),
        @TableName      NVARCHAR(128),
        @IndexName      NVARCHAR(128),
        @SQL            NVARCHAR(MAX),
        @Fragmentation  FLOAT,
        @PageCount      INT;


    DECLARE cursorInd CURSOR FOR	-- declaração do cursor
        SELECT
            s.name  AS SchemaName,
            o.name  AS TableName,
            i.name  AS IndexName,
            ps.avg_fragmentation_in_percent,
            ps.page_count
        FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'LIMITED') ps
            INNER JOIN sys.indexes i ON ps.object_id = i.object_id AND ps.index_id  = i.index_id
            INNER JOIN sys.objects o ON ps.object_id = o.object_id
            INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
        WHERE ps.database_id = DB_ID()
            AND i.name IS NOT NULL
            AND ps.page_count > 200;

    OPEN cursorInd;				-- abre cursor

    FETCH NEXT FROM cursorInd
        INTO @SchemaName, @TableName, @IndexName, @Fragmentation, @PageCount;

    WHILE @@FETCH_STATUS = 0   -- loop que percorre todos os índices retornados
    BEGIN

        IF CAST(GETDATE() AS TIME) > '06:00:00'
        BEGIN
            BREAK
        END

        IF @Fragmentation BETWEEN 5 AND 30		-- se a fragmentação estiver entre 5% e 30%  REORGANIZZE
        BEGIN
            SET @SQL = 'ALTER INDEX [' + @IndexName + '] ON [' + @SchemaName + '].[' + @TableName + '] REORGANIZE';
            PRINT @SQL;
            EXEC (@SQL);
        END

        IF @Fragmentation > 30				-- se a fragmentação estiver > 30%  REBUILD
        BEGIN
            SET @SQL = 'ALTER INDEX [' + @IndexName + '] ON [' + @SchemaName + '].[' + @TableName + '] REBUILD';
            PRINT @SQL;
            EXEC (@SQL);
        END

        FETCH NEXT FROM cursorInd
            INTO @SchemaName, @TableName, @IndexName, @Fragmentation, @PageCount;

    END

    CLOSE cursorInd;			-- fecha cursor
    DEALLOCATE cursorInd;
END
GO