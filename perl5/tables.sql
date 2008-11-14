CREATE DATABASE `iTunesConnect`;
use `iTunesConnect`;

DROP TABLE IF EXISTS `dailySalesSummary`;
CREATE TABLE `dailySalesSummary` (
  `ID` INT UNSIGNED NOT NULL auto_increment, -- Primary Key
  `Provider` TINYTEXT NOT NULL,
  `ProviderCountry` TINYTEXT NOT NULL,
  `VendorIdentifier` TINYTEXT NOT NULL,
  `UPC` TINYTEXT,
  `ISRC` TINYTEXT,
  `ArtistShow`  TINYTEXT NOT NULL,
  `TitleEpisodeSeason` TINYTEXT NOT NULL,
  `LabelStudioNetwork` TINYTEXT,
  `ProductTypeIdentifier` TINYINT UNSIGNED NOT NULL,
  `Units` INT UNSIGNED,
  `RoyaltyPrice` DECIMAL(10,2) UNSIGNED NOT NULL,
  `BeginDate` DATE NOT NULL,
  `EndDate` DATE NOT NULL,
  `CustomerCurrency` TINYTEXT NOT NULL,
  `CountryCode` TINYTEXT NOT NULL,
  `RoyaltyCurrency` TINYTEXT NOT NULL,
  `Preorder` TINYTEXT,
  `SeasonPass` TINYTEXT,
  `ISAN` TINYTEXT,
  `AppleIdentifier` TINYTEXT NOT NULL,
  `CustomerPrice` DECIMAL(10,2) UNSIGNED NOT NULL,
  `CMA` TINYTEXT,
  `AssetContentFlavor` TINYTEXT,
  PRIMARY KEY `ID` (`ID`),
  UNIQUE KEY `VID_PTI_BeginDate_CountryCode` (`VendorIdentifier`(255),`ProductTypeIdentifier`,`BeginDate`,`CountryCode`(2))
) COMMENT='Daily Sales/Trend Summary Reports' AUTO_INCREMENT=1;

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
