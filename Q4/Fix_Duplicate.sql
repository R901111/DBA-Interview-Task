-- ======================================================================
-- 題目四：高併發下的資料一致性 (清理重複資料與建立唯一約束)
-- 說明：解決 Race Condition (TOCTOU) 造成的重複報名問題
-- ======================================================================

-- 利用 CTE 找出並刪除重複的報名紀錄
-- 保留每位會員在同一場活動中「最早報名」的那一筆紀錄
WITH DuplicateData AS (
    SELECT 
        MemberId,
        EventId,
        ROW_NUMBER() OVER (
            PARTITION BY MemberId, EventId 
            ORDER BY JoinedAt ASC
        ) AS RowNum
    FROM dbo.EventJoin
)
DELETE FROM DuplicateData 
WHERE RowNum > 1;
GO

-- 資料清理完畢後，加上「唯一約束 (Unique Constraint)」
-- 將防護責任交給資料庫底層，確保未來並發寫入時 100% 不會產生重複資料
ALTER TABLE dbo.EventJoin
ADD CONSTRAINT UQ_EventJoin_Member_Event UNIQUE (MemberId, EventId);
GO