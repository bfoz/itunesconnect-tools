CREATE DATABASE `iTunesConnect`;
use `iTunesConnect`;

-- Units and CustomerPrice must support signed numbers, which indicate refunds/returns
DROP TABLE IF EXISTS `dailySalesSummary`;
CREATE TABLE `dailySalesSummary` (
  `ID` INT UNSIGNED NOT NULL auto_increment, -- Primary Key
  `Provider` VARCHAR(255) NOT NULL,
  `ProviderCountry` CHAR(2) NOT NULL,
  `VendorIdentifier` VARCHAR(255) NOT NULL,
  `UPC` CHAR(1),		-- Not used
  `ISRC` CHAR(1),		-- Not used
  `ArtistShow`  VARCHAR(255) NOT NULL,
  `TitleEpisodeSeason` VARCHAR(255) NOT NULL,
  `LabelStudioNetwork` CHAR(1),
  `ProductTypeIdentifier` TINYINT UNSIGNED NOT NULL,
  `Units` INT,
  `RoyaltyPrice` DECIMAL(10,2) UNSIGNED NOT NULL,
  `BeginDate` DATE NOT NULL,
  `EndDate` DATE NOT NULL,
  `CustomerCurrency` CHAR(3) NOT NULL,
  `CountryCode` CHAR(2) NOT NULL,
  `RoyaltyCurrency` CHAR(3) NOT NULL,
  `Preorder` CHAR(1),		-- Not used
  `SeasonPass` CHAR(1),		-- Not used
  `ISAN` CHAR(1),
  `AppleIdentifier` VARCHAR(255) NOT NULL,
  `CustomerPrice` DECIMAL(10,2) NOT NULL,
  `CMA` CHAR(1),		-- Not used
  `AssetContentFlavor` CHAR(1),	-- Not used
  PRIMARY KEY `ID` (`ID`),
  UNIQUE KEY `VID_PTI_BeginDate_CountryCode` (`VendorIdentifier`(255),`ProductTypeIdentifier`,`BeginDate`,`CountryCode`(2))
) COMMENT='Daily Sales/Trend Summary Reports' AUTO_INCREMENT=1;

CREATE OR REPLACE VIEW dailyTotalSales AS SELECT BeginDate, sum(Units) as numSales FROM dailySalesSummary WHERE ProductTypeIdentifier=1 GROUP BY BeginDate;

CREATE OR REPLACE VIEW dailyTotalUpdates AS SELECT BeginDate, sum(Units) as numUpdates FROM dailySalesSummary WHERE ProductTypeIdentifier=7 GROUP BY BeginDate;

-- This would be a lot easier if MySQL supported FULL OUTER JOIN
-- CREATE OR REPLACE VIEW dailyTotals AS SELECT BeginDate, numSales, numUpdates FROM dailyTotalSales FULL OUTER JOIN dailyTotalUpdates USING(BeginDate);

-- Units and CustomerPrice must support signed numbers, which indicate refunds/returns
DROP TABLE IF EXISTS `weeklySalesSummary`;
CREATE TABLE `weeklySalesSummary` (
  `Provider` VARCHAR(255) NOT NULL,
  `ProviderCountry` CHAR(2) NOT NULL,
  `VendorIdentifier` VARCHAR(255) NOT NULL,
  `UPC` CHAR(1),		-- Not used
  `ISRC` CHAR(1),		-- Not used
  `ArtistShow` VARCHAR(255) NOT NULL,
  `TitleEpisodeSeason` VARCHAR(255) NOT NULL,
  `LabelStudioNetwork` CHAR(1),
  `ProductTypeIdentifier` TINYINT UNSIGNED NOT NULL,
  `Units` INT,
  `RoyaltyPrice` DECIMAL(10,2) UNSIGNED NOT NULL,
  `BeginDate` DATE NOT NULL,
  `EndDate` DATE NOT NULL,
  `CustomerCurrency` CHAR(3) NOT NULL,
  `CountryCode` CHAR(2) NOT NULL,
  `RoyaltyCurrency` CHAR(3) NOT NULL,
  `Preorder` CHAR(1),		-- Not used
  `SeasonPass` CHAR(1),		-- Not used
  `ISAN` CHAR(1),		-- Not used
  `AppleIdentifier` VARCHAR(255) NOT NULL,
  `CustomerPrice` DECIMAL(10,2) NOT NULL,
  `CMA` CHAR(1),		-- Not used
  `AssetContentFlavor` CHAR(1),	-- Not used
  UNIQUE KEY `VID_PTI_BeginDate_CountryCode` (`VendorIdentifier`(255),`ProductTypeIdentifier`,`BeginDate`,`CountryCode`(2))
) COMMENT='Weekly Sales/Trend Summary Reports';

DROP TABLE IF EXISTS `FinancialReport`;
CREATE TABLE `FinancialReport` (
  `ReportID` CHAR(6) NOT NULL,  -- YYYYMM, Not in the report, generated from the report filename
  `RegionCode` CHAR(2) NOT NULL,    -- Not in the report, generated from the report filename
  `StartDate` DATE NOT NULL,
  `EndDate` DATE NOT NULL,
  `VendorIdentifier` VARCHAR(255) NOT NULL,
  `UPC` CHAR(1),			-- Not used
  `ISRC` CHAR(1),			-- Not used
  `Quantity` INT,
  `PartnerShare` DECIMAL(10,2) NOT NULL,
  `ExtendedPartnerShare` DECIMAL(10,2) NOT NULL,
  `PartnerShareCurrency` CHAR(3) NOT NULL,
  `SaleOrReturn` CHAR(1) NOT NULL,
  `AppleIdentifier` VARCHAR(255) NOT NULL,
  `ArtistShowDeveloper` VARCHAR(255) NOT NULL,
  `Title` VARCHAR(255) NOT NULL,
  `LabelStudioNetwork` CHAR(1),		-- Not used
  `ProductTypeIdentifier` TINYINT UNSIGNED NOT NULL,
  `Side` CHAR(1),			-- Not used
  `AccountIdentifier` VARCHAR(255) NOT NULL,
  `CountryOfSale` VARCHAR(255) NOT NULL,
  `PreorderFlag` CHAR(1),		-- Not used
  `Prepaid` CHAR(1),			-- Not used
  `PrepaidType` CHAR(1),		-- Not used
  `ISANOtherIdentifier` CHAR(1),	-- Not used
  `CMAFlag` CHAR(1),			-- Not used
  `CustomerPrice` DECIMAL(10,2) NOT NULL,
  `CustomerCurrency` CHAR(3) NOT NULL,
  UNIQUE KEY `RID_RC_VID_PTI_CountryOfSale` (`ReportID`,`RegionCode`,`ProductTypeIdentifier`,`VendorIdentifier`(100),`CountryOfSale`(100),`CustomerPrice`)
) COMMENT='Monthly Financial Reports' AUTO_INCREMENT=1;

DROP TABLE IF EXISTS `applications`;
CREATE TABLE `applications` (
  `ID` INT UNSIGNED NOT NULL auto_increment, -- Primary Key
  `VendorIdentifier` TINYTEXT NOT NULL,	-- Foreign key for dailySalesSummary
  `TitleEpisodeSeason` TINYTEXT NOT NULL,
  `numDays` INT UNSIGNED,		-- Number of daily reports
  `numSales` INT UNSIGNED,		-- Lifetime number of units sold
  `numUpdates` INT UNSIGNED,		-- Lifetime number of updates
  `avgDailySales` FLOAT,		-- Lifetime average of units sold per day
  `avgDailyUpdates` FLOAT,		-- Lifetime average of updates per day
  PRIMARY KEY `ID` (`ID`),
  UNIQUE KEY `VID` (`VendorIdentifier`(255))
) COMMENT='Per-Application statistics';
