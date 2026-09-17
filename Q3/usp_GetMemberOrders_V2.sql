/* ==========================================================
   題目三　環境建置腳本
   ----------------------------------------------------------
   生產環境實際狀況：
     dbo.Orders   約 8,000 萬筆，每日新增約 8 萬筆
                  尖峰時段約每秒 20-30 筆寫入，同時有狀態更新
     dbo.Members  約 300 萬筆
   本腳本只建立結構，不含任何資料。
   ========================================================== */

CREATE TABLE dbo.Members
(
    MemberId      BIGINT        IDENTITY(1,1) NOT NULL,
    MemberNo      VARCHAR(20)   NOT NULL,
    MemberName    NVARCHAR(50)  NOT NULL,
    Phone         NVARCHAR(20)  NULL,
    Email         NVARCHAR(100) NULL,
    PasswordHash  VARBINARY(64) NOT NULL,
    Status        TINYINT       NOT NULL,
    RegisteredAt  DATETIME2(0)  NOT NULL,
    LastLoginAt   DATETIME2(0)  NULL,
    LastQueryAt   DATETIME2(0)  NULL,
    CONSTRAINT PK_Members PRIMARY KEY CLUSTERED (MemberId)
);
GO

CREATE TABLE dbo.Orders
(
    OrderId          BIGINT        IDENTITY(1,1) NOT NULL,
    OrderNo          VARCHAR(30)   NOT NULL,
    MemberId         BIGINT        NOT NULL,
    Status           TINYINT       NOT NULL,   -- 1 待付款 2 已付款 3 已出貨 4 已完成 9 已取消
    PaymentMethod    TINYINT       NOT NULL,
    TotalAmount      DECIMAL(12,2) NOT NULL,
    DiscountAmount   DECIMAL(12,2) NOT NULL,
    ShippingFee      DECIMAL(12,2) NOT NULL,
    TaxAmount        DECIMAL(12,2) NOT NULL,
    CouponCode       VARCHAR(30)   NULL,
    ReceiverName     NVARCHAR(50)  NOT NULL,
    ReceiverPhone    NVARCHAR(20)  NOT NULL,
    ReceiverZipCode  VARCHAR(10)   NULL,
    ReceiverAddress  NVARCHAR(200) NULL,
    ShippingProvider NVARCHAR(30)  NULL,
    TrackingNo       VARCHAR(40)   NULL,
    InvoiceType      TINYINT       NULL,
    BuyerNote        NVARCHAR(500) NULL,
    InternalNote     NVARCHAR(500) NULL,
    SourceChannel    TINYINT       NOT NULL,
    IsGift           BIT           NOT NULL,
    CreatedAt        DATETIME2(0)  NOT NULL,
    PaidAt           DATETIME2(0)  NULL,
    ShippedAt        DATETIME2(0)  NULL,
    CompletedAt      DATETIME2(0)  NULL,
    CancelledAt      DATETIME2(0)  NULL,
    UpdatedAt        DATETIME2(0)  NULL,
    CONSTRAINT PK_Orders PRIMARY KEY CLUSTERED (OrderId)
);
GO

-- Orders 表上除主鍵之外沒有任何索引，Members 表亦同。
-- 兩張表之間目前沒有建立外鍵。
GO
CREATE OR ALTER PROCEDURE dbo.usp_GetMemberOrders
    @MemberId   BIGINT,          -- 修正：對齊資料表型別 BIGINT
    @StartDate  DATE,            -- 修正：改用 DATE 型別
    @EndDate    DATE,            -- 修正：改用 DATE 型別
    @StatusList VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON; 

    -- 執行核心查詢 (直接 JOIN，不使用 Temp 表)
    SELECT 
        o.OrderId, o.OrderNo, o.Status, o.TotalAmount, o.CreatedAt, 
        m.MemberName, m.Phone, m.Email
    FROM dbo.Orders o
    LEFT JOIN dbo.Members m ON m.MemberId = o.MemberId
    WHERE o.MemberId = @MemberId
      -- 修正：SARGable 時間區間寫法
      AND o.CreatedAt >= CAST(@StartDate AS DATETIME2(0))
      AND o.CreatedAt <  DATEADD(DAY, 1, CAST(@EndDate AS DATETIME2(0)))
      -- 修正：利用 STRING_SPLIT 處理狀態陣列
      AND (@StatusList IS NULL OR CAST(o.Status AS VARCHAR) IN (SELECT value FROM STRING_SPLIT(@StatusList, ',')))
    ORDER BY o.CreatedAt DESC;

    -- 獨立更新最後查詢時間 (移除不必要的 TRANSACTION)
    UPDATE dbo.Members
    SET LastQueryAt = SYSUTCDATETIME() 
    WHERE MemberId = @MemberId;
END
GO

-- 新增涵蓋索引以支撐上述的查詢與排序
GO
CREATE NONCLUSTERED INDEX IX_Orders_MemberId_CreatedAt 
ON dbo.Orders (MemberId, CreatedAt DESC)
INCLUDE (Status, TotalAmount, OrderNo);
GO