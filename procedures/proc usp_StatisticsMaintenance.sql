CREATE OR ALTER PROCEDURE dbo.usp_StatisticsMaintenance
(
      @MinRows BIGINT = 5000
    , @ExecuteUpdate BIT = 1
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Inicio DATETIME = GETDATE();

    /*
    IF CAST(GETDATE() AS TIME) > '06:00:00'
    BEGIN
        RAISERROR(
            'Execução bloqueada. Permitido apenas até 06:00.',
            10,
            1
        );
        RETURN;
    END
    */

    CREATE TABLE #Resultado
    (
          SchemaName            SYSNAME
        , TableName             SYSNAME
        , StatisticName         SYSNAME
        , RowsCount             BIGINT
        , ModificationCount     BIGINT
        , MinModificationCount  BIGINT
        , Percentual            DECIMAL(10,2)
        , LimiteUtilizado       DECIMAL(10,2)
        , Acao                  VARCHAR(20)
        , DataExecucao          DATETIME
    );

    DECLARE
          @SchemaName SYSNAME
        , @TableName SYSNAME
        , @StatisticName SYSNAME
        , @Rows BIGINT
        , @ModificationCounter BIGINT
        , @MinModificationCounter BIGINT
        , @Percentual DECIMAL(10,2)
        , @Limite DECIMAL(10,2)
        , @SQL NVARCHAR(MAX)
        , @TotalEstatisticas INT = 0
        , @TotalAtualizadas INT = 0;

    DECLARE curStats CURSOR LOCAL FAST_FORWARD FOR

    SELECT
          SCHEMA_NAME(o.schema_id)
        , o.name
        , s.name
        , sp.rows
        , sp.modification_counter
    FROM sys.stats s
    INNER JOIN sys.objects o
        ON o.object_id = s.object_id
    CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) sp
    WHERE
            o.type = 'U'
        AND sp.rows >= @MinRows;

    OPEN curStats;

    FETCH NEXT FROM curStats
    INTO
          @SchemaName
        , @TableName
        , @StatisticName
        , @Rows
        , @ModificationCounter;

    WHILE @@FETCH_STATUS = 0
    BEGIN

        SET @TotalEstatisticas += 1;

        SET @Percentual =
            CASE
                WHEN @Rows = 0 THEN 0
                ELSE (@ModificationCounter * 100.0) / @Rows
            END;

        SET @Limite =
            CASE
                WHEN @Rows <= 100000 THEN 25
                WHEN @Rows <= 1000000 THEN 10
                ELSE 5
            END;

        SET @MinModificationCounter =
            CASE
                WHEN @Rows <= 100000 THEN 5000
                WHEN @Rows <= 1000000 THEN 10000
                ELSE 50000
            END;

        IF @Percentual >= @Limite
           AND @ModificationCounter >= @MinModificationCounter
        BEGIN

            IF @ExecuteUpdate = 1
            BEGIN

                SET @SQL =
                    N'UPDATE STATISTICS '
                    + QUOTENAME(@SchemaName)
                    + N'.'
                    + QUOTENAME(@TableName)
                    + N' '
                    + QUOTENAME(@StatisticName)
                    + N' WITH RESAMPLE';

                EXEC sp_executesql @SQL;

            END;

            INSERT INTO #Resultado
            (
                  SchemaName
                , TableName
                , StatisticName
                , RowsCount
                , ModificationCount
                , MinModificationCount
                , Percentual
                , LimiteUtilizado
                , Acao
                , DataExecucao
            )
            VALUES
            (
                  @SchemaName
                , @TableName
                , @StatisticName
                , @Rows
                , @ModificationCounter
                , @MinModificationCounter
                , @Percentual
                , @Limite
                , CASE
                    WHEN @ExecuteUpdate = 1
                        THEN 'ATUALIZADA'
                    ELSE 'SIMULACAO'
                  END
                , GETDATE()
            );

            SET @TotalAtualizadas += 1;

        END;

        FETCH NEXT FROM curStats
        INTO
              @SchemaName
            , @TableName
            , @StatisticName
            , @Rows
            , @ModificationCounter;

    END;

    CLOSE curStats;
    DEALLOCATE curStats;

    PRINT '================================================';
    PRINT 'MANUTENCAO DE ESTATISTICAS';
    PRINT '================================================';
    PRINT 'Estatisticas analisadas : '
          + CAST(@TotalEstatisticas AS VARCHAR(20));

    PRINT 'Estatisticas atualizadas: '
          + CAST(@TotalAtualizadas AS VARCHAR(20));

    PRINT 'Tempo total (segundos): '
          + CAST(DATEDIFF(SECOND, @Inicio, GETDATE()) AS VARCHAR(20));

    PRINT '================================================';

    SELECT
          SchemaName
        , TableName
        , StatisticName
        , RowsCount
        , ModificationCount
        , MinModificationCount
        , Percentual
        , LimiteUtilizado
        , Acao
        , DataExecucao
    FROM #Resultado
    ORDER BY Percentual DESC;

END;
GO

////////// EXECUTAR

EXEC dbo.usp_StatisticsMaintenance
     @ExecuteUpdate = 1;