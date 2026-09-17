-- ======================================================================
-- 題目一：訂單資料表設計與分區 (Table Partitioning) 腳本
-- 策略：以 CreatedAt 按月分區
-- ======================================================================

-- 建立 Partition Function
-- 這裡採用 RANGE RIGHT，以每月 1 號為邊界
CREATE PARTITION FUNCTION pf_OrderDate_Monthly (DATETIME2(0))
AS RANGE RIGHT FOR VALUES (
    '2024-01-01', '2024-02-01', '2024-03-01', 
    '2024-04-01', '2024-05-01', '2024-06-01'
    -- 實務上會預先建立未來數個月份的邊界
);
GO

-- 建立 Partition Scheme (分區配置：定義切塊後的資料「放哪裡」)
-- 因測試環境限制，統一放於 PRIMARY 檔案群組
CREATE PARTITION SCHEME ps_OrderDate_Monthly
AS PARTITION pf_OrderDate_Monthly
ALL TO ([PRIMARY]);
GO

-- 建立訂單資料表 (Orders)
-- 應用分區配置，並優化資料型別
CREATE TABLE dbo.Orders (
    OrderId     BIGINT IDENTITY(1,1) NOT NULL,
    OrderNo     VARCHAR(20) NOT NULL,
    MemberId    BIGINT NOT NULL,
    TotalAmount DECIMAL(10, 2) NOT NULL,
    Status      TINYINT NOT NULL,           -- 使用 TINYINT 節省空間 (對應程式端 Enum)
    CreatedAt   DATETIME2(0) NOT NULL,      -- 精確到秒即可，節省空間
    
    -- 注意：要讓資料表分區對齊 (Partition Alignment)，PK 必須包含分區鍵 (Partition Column)
    CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED (OrderId, CreatedAt)
) ON ps_OrderDate_Monthly(CreatedAt);
GO

-- 針對常用的 MemberId 查詢建立非叢集索引 (Aligned Index)
CREATE NONCLUSTERED INDEX IX_Orders_MemberId 
ON dbo.Orders (MemberId)
ON ps_OrderDate_Monthly(CreatedAt);
GO