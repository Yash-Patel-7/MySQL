SET GLOBAL local_infile=1;
LOAD DATA LOCAL INFILE '//Users//yash//Desktop//Database//Election//Penna.csv'
INTO TABLE Penna
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES



