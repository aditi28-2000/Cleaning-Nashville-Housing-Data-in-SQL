select * from NashvilleHousing;
UPDATE NashvilleHousing
SET
    ParcelID = NULLIF(ParcelID, ''),
    LandUse = NULLIF(LandUse, ''),
    PropertyAddress = NULLIF(PropertyAddress, '');
    
    UPDATE NashvilleHousing
    SET
    LegalReference = NULLIF(LegalReference, ''),
    SoldAsVacant = NULLIF(SoldAsVacant, ''),
    OwnerName = NULLIF(OwnerName, ''),
    OwnerAddress = NULLIF(OwnerAddress, ''),
    TaxDistrict = NULLIF(TaxDistrict, '');
    
-- Check for same UniqueID or ParcelID values
SELECT UniqueID, Count(UniqueID) FROM NashvilleHousing GROUP BY UniqueID HAVING Count(UniqueID)>1;
SELECT ParcelID,Count(ParcelID) FROM NashvilleHousing GROUP BY ParcelID HAVING Count(ParcelID)>1;

-- Check the addresses which have same parcelID
SELECT UniqueID,PropertyAddress,ParcelID,Count(ParcelID) OVER (PARTITION BY ParcelID) 
AS ParcelIDCount FROM NashvilleHousing;

-- Populate the Property Addresses based on the ParcelID
SELECT a.UniqueID,a.ParcelID,a.PropertyAddress,b.UniqueID,b.ParcelID,b.PropertyAddress FROM NashvilleHousing a 
JOIN NashvilleHousing b on a.ParcelID=b.ParcelID and a.UniqueID != b.UniqueID;

SELECT a.ParcelID,a.PropertyAddress,b.ParcelID,b.PropertyAddress, IFNULL(a.PropertyAddress,b.PropertyAddress)
FROM NashvilleHousing a JOIN NashvilleHousing b 
on a.ParcelID=b.ParcelID and a.UniqueID != b.UniqueID WHERE a.PropertyAddress is NULL;

UPDATE NashvilleHousing a JOIN NashvilleHousing b 
on a.ParcelID=b.ParcelID and a.UniqueID != b.UniqueID 
SET a.PropertyAddress= IFNULL(a.PropertyAddress,b.PropertyAddress);

-- Can also use below query to populate Property Addresses
UPDATE a SET a.PropertyAddress= IFNULL(a.PropertyAddress,b.PropertyAddress) 
FROM NashvilleHousing a JOIN NashvilleHousing b 
on a.ParcelID=b.ParcelID and a.UniqueID != b.UniqueID WHERE a.PropertyAddress is NULL;

-- Separate the Property Address as Address and city and add the tables

SELECT SUBSTRING(PropertyAddress, 1, CHAR_LENGTH(PropertyAddress) - LOCATE(' ', REVERSE(TRIM(PropertyAddress)))) AS Address, 
SUBSTRING_INDEX(TRIM(PropertyAddress), ' ', -1) AS City
FROM NashvilleHousing;

ALTER TABLE NashvilleHousing 
ADD HousingAddress varchar(255), ADD HousingCity varchar(255);

UPDATE NashvilleHousing 
SET HousingAddress=SUBSTRING(PropertyAddress, 1, CHAR_LENGTH(PropertyAddress) - LOCATE(' ', REVERSE(TRIM(PropertyAddress)))),
HousingCity = SUBSTRING_INDEX(TRIM(PropertyAddress), ' ', -1);

-- Split the Owner Address to local address, city and state
SELECT SUBSTRING_INDEX(TRIM(OwnerAddress),' ',-1) FROM NashvilleHousing;
SELECT SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(OwnerAddress),' ',-2),' ',1) FROM NashvilleHousing;
SELECT SUBSTRING(OwnerAddress,1,CHAR_LENGTH(OwnerAddress)-CHAR_LENGTH(SUBSTRING_INDEX(TRIM(OwnerAddress),' ',-2))) 
FROM NashvilleHousing;

ALTER Table NashvilleHousing 
ADD OwnerAddressSplit varchar(255),
ADD OwnerAddressCity varchar(255),
ADD OwnerAddressState varchar(255); 

UPDATE NashvilleHousing
SET OwnerAddressSplit= SUBSTRING(OwnerAddress,1,CHAR_LENGTH(OwnerAddress)-CHAR_LENGTH(SUBSTRING_INDEX(TRIM(OwnerAddress),' ',-2))),
OwnerAddressCity= SUBSTRING_INDEX(SUBSTRING_INDEX(TRIM(OwnerAddress),' ',-2),' ',1),
OwnerAddressState= SUBSTRING_INDEX(TRIM(OwnerAddress),' ',-1);

-- Clean the categorical data, convert all Y and N to Yes and No respectively
SELECT DISTINCT(SoldAsVacant), COUNT(SoldAsVacant) FROM NashvilleHousing GROUP BY SoldAsVacant ORDER BY 2;

SELECT SoldAsVacant,
CASE WHEN SoldAsVacant = 'Y' THEN 'Yes'
	 WHEN SoldAsVacant = 'N' THEN 'No'
     ELSE SoldAsVacant
END
FROM NashvilleHousing

UPDATE NashvilleHousing
SET SoldAsVacant=
CASE WHEN SoldAsVacant = 'Y' THEN 'Yes'
	 WHEN SoldAsVacant = 'N' THEN 'No'
     ELSE SoldAsVacant
END;

-- Create A CTE to identify duplicate entries and remove duplicates
WITH RowNumberCTE
AS
(SELECT *,
row_number()OVER
(PARTITION BY ParcelID,PropertyAddress,SaleDate,SalePrice,LegalReference
ORDER BY UniqueID) AS RowNum
FROM NashvilleHousing)
SELECT * FROM RowNumberCTE WHERE RowNum>1;

-- delete duplicates
WITH RowNumberCTE
AS
(SELECT *,
row_number()OVER
(PARTITION BY ParcelID,PropertyAddress,SaleDate,SalePrice,LegalReference
ORDER BY UniqueID) AS RowNum
FROM NashvilleHousing)
DELETE FROM RowNumberCTE WHERE RowNum>1;

-- In case I want to delete the duplicates from the actual table I would use the below query
DELETE FROM NashvilleHousing
WHERE (ParcelID, PropertyAddress, SaleDate, SalePrice, LegalReference) IN (
    SELECT ParcelID, PropertyAddress, SaleDate, SalePrice, LegalReference
    FROM (
        SELECT ParcelID, PropertyAddress, SaleDate, SalePrice, LegalReference,
               ROW_NUMBER() OVER (PARTITION BY ParcelID, PropertyAddress, SaleDate, SalePrice, LegalReference ORDER BY UniqueID) AS row_num
        FROM NashvilleHousing
    ) AS subquery
    WHERE row_num = 2
);


-- Remove Unused Columns
ALTER TABLE NashvilleHousing
DROP COLUMN OwnerAddress,
DROP COLUMN PropertyAddress, 
DROP COLUMN TaxDistrict;

-- Finally check cleaned data
SELECT * FROM NashvilleHousing;