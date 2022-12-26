
DELIMITER $$
DROP PROCEDURE IF EXISTS API1 $$
CREATE PROCEDURE API1 (IN CANDIDATE CHAR(5), IN TIMESTAMPP CHAR(19), IN PRECINCT VARCHAR(100))
proc : BEGIN

	DECLARE EXIT HANDLER FOR 1525
	BEGIN
        SELECT DISTINCT 'incorrect timestamp' Exception;
	END;
    SET @WRONGT := (SELECT DISTINCT p.Timestamp FROM Penna p WHERE p.Timestamp = TIMESTAMPP LIMIT 1);

	IF (CANDIDATE != 'Trump' AND CANDIDATE != 'Biden') THEN
		BEGIN
			SELECT DISTINCT 'incorrect candidate' Exception;
            LEAVE proc;
        END;
    END IF;
    
    SET @PRECINCT_EXISTS := (EXISTS(SELECT DISTINCT p.precinct FROM Penna p WHERE p.precinct = PRECINCT));
    IF (@PRECINCT_EXISTS = FALSE) THEN
		BEGIN
			SELECT DISTINCT 'incorrect precinct' Exception;
            LEAVE proc;
        END;
    END IF;

	SET @T_MIN := (SELECT DISTINCT p.Timestamp FROM Penna p WHERE p.precinct = PRECINCT ORDER BY p.Timestamp ASC LIMIT 1);
	
    IF (TIMESTAMPP < @T_MIN) THEN
		BEGIN
			SELECT DISTINCT 0 Votes;
			LEAVE proc;
		END;
    END IF;

	SET @T_APPEARS := (EXISTS(SELECT DISTINCT p.Timestamp FROM Penna p WHERE p.precinct = PRECINCT AND p.Timestamp = TIMESTAMPP));
    
	IF (@T_APPEARS = FALSE) THEN
		SET TIMESTAMPP := (SELECT DISTINCT p.Timestamp FROM Penna p WHERE p.precinct = PRECINCT AND p.Timestamp < TIMESTAMPP ORDER BY p.Timestamp DESC LIMIT 1);
	END IF;
    
    SET @PREPARED := CONCAT("SELECT DISTINCT p.", CANDIDATE, " FROM Penna p WHERE p.Timestamp = '", TIMESTAMPP, "' AND p.precinct = '", PRECINCT, "'");
    
    PREPARE statement FROM @PREPARED;
    EXECUTE statement;
    DEALLOCATE PREPARE statement;

END; $$
DELIMITER ;



DELIMITER $$
DROP PROCEDURE IF EXISTS API2 $$
CREATE PROCEDURE API2 (IN DATEE CHAR(10))
proc : BEGIN

	DECLARE EXIT HANDLER FOR 1525
	BEGIN
		SELECT DISTINCT 'incorrect date' Exception;
	END;
    SET @TEMPVAR := CONCAT(DATEE, " 00:00:00");
    SET @WRONGT := (SELECT DISTINCT p.Timestamp FROM Penna p WHERE p.Timestamp = @TEMPVAR LIMIT 1);

	SET @LIKES := CONCAT(DATEE, "%");
    SET @LAST_TIME_EXISTS := (EXISTS(SELECT DISTINCT p.Timestamp FROM Penna p WHERE p.Timestamp LIKE @LIKES ORDER BY p.Timestamp DESC LIMIT 1));
    
    IF (@LAST_TIME_EXISTS = FALSE) THEN
		BEGIN
			SELECT DISTINCT 'date does not exist' Exception;
            LEAVE proc;
        END;
    END IF;
    
	SET @LAST_TIMESTAMP := (SELECT DISTINCT p.Timestamp FROM Penna p WHERE p.Timestamp LIKE @LIKES ORDER BY p.Timestamp DESC LIMIT 1);
    SELECT DISTINCT SUM(p.Trump), SUM(p.Biden) INTO @TRUMP, @BIDEN FROM Penna p WHERE p.Timestamp = @LAST_TIMESTAMP;
    
    IF (@TRUMP >= @BIDEN) THEN
		SELECT DISTINCT "Trump" Candidate, @TRUMP Votes;
	ELSE
		SELECT DISTINCT "Biden" Candidate, @BIDEN Votes;
	END IF;

END; $$
DELIMITER ;



DELIMITER $$
DROP PROCEDURE IF EXISTS API3 $$
CREATE PROCEDURE API3 (IN CANDIDATE CHAR(5))
proc : BEGIN

	IF (CANDIDATE != 'Trump' AND CANDIDATE != 'Biden') THEN
		BEGIN
			SELECT DISTINCT 'incorrect candidate' Exception;
            LEAVE proc;
        END;
    END IF;

	SET @ULTIMATE := (SELECT DISTINCT p.Timestamp FROM Penna p ORDER BY p.Timestamp DESC LIMIT 1);
    
    SET @PREPARED := CONCAT("SELECT DISTINCT p.precinct, p.totalvotes FROM Penna p WHERE p.Timestamp = '", @ULTIMATE, "' AND p.", CANDIDATE, " > (p.totalvotes - p.", CANDIDATE, ") ORDER BY p.totalvotes DESC LIMIT 10");

	PREPARE statement FROM @PREPARED;
    EXECUTE statement;
    DEALLOCATE PREPARE statement;

END; $$
DELIMITER ;



DELIMITER $$
DROP PROCEDURE IF EXISTS API4 $$
CREATE PROCEDURE API4 (IN PRECINCT VARCHAR(100))
proc : BEGIN

	SET @ULTIMATE := (SELECT DISTINCT p.Timestamp FROM Penna p ORDER BY p.Timestamp DESC LIMIT 1);
    
    SET @PRECINCT_EXISTS := (EXISTS(SELECT DISTINCT p.precinct FROM Penna p WHERE p.Timestamp = @ULTIMATE AND p.precinct = PRECINCT));
    IF (@PRECINCT_EXISTS = FALSE) THEN
		BEGIN
			SELECT DISTINCT 'incorrect precinct' Exception;
            LEAVE proc;
        END;
    END IF;
    
    SELECT DISTINCT p.Trump, p.Biden, p.totalvotes INTO @TRUMP, @BIDEN, @TOTAL FROM Penna p WHERE p.Timestamp = @ULTIMATE AND p.precinct = PRECINCT;
    
    IF (@TRUMP >= @BIDEN) THEN
		SELECT DISTINCT "Trump" Winner, (@TRUMP / @TOTAL) * 100 Percentage;
	ELSE
		SELECT DISTINCT "Biden" Winner, (@BIDEN / @TOTAL) * 100 Percentage;
    END IF;

END; $$
DELIMITER ;



DELIMITER $$
DROP PROCEDURE IF EXISTS API5 $$
CREATE PROCEDURE API5 (IN STRINGG VARCHAR(100))
proc : BEGIN

	SET @ULTIMATE := (SELECT DISTINCT p.Timestamp FROM Penna p ORDER BY p.Timestamp DESC LIMIT 1);
    
    SET @SUBSTRING_EXISTS := (EXISTS(SELECT DISTINCT p.precinct FROM Penna p WHERE LOCATE(STRINGG, p.precinct) > 0 AND p.Timestamp = @ULTIMATE));
    
    IF (@SUBSTRING_EXISTS = FALSE) THEN
		BEGIN
			SELECT DISTINCT 'incorrect substring' Exception;
            LEAVE proc;
        END;
    END IF;

	SELECT DISTINCT SUM(p.Trump), SUM(p.Biden) INTO @TRUMP, @BIDEN FROM Penna p WHERE LOCATE(STRINGG, p.precinct) > 0 AND p.Timestamp = @ULTIMATE;
    
    IF (@TRUMP >= @BIDEN) THEN
		SELECT DISTINCT "Trump" Winner, @TRUMP Votes;
	ELSE
		SELECT DISTINCT "Biden" Winner, @BIDEN Votes;
    END IF;

END; $$
DELIMITER ;



DELIMITER $$
DROP PROCEDURE IF EXISTS newPenna $$
CREATE PROCEDURE newPenna ()
proc : BEGIN

	DECLARE TIMESTAMPP DATETIME;
    DECLARE PRECINCT VARCHAR(100);
    DECLARE NEWVOTES INT;
    DECLARE NEW_BIDEN INT;
    DECLARE NEW_TRUMP INT;
	DECLARE CURR CURSOR FOR SELECT DISTINCT p.Timestamp, p.precinct, p.totalvotes, p.Biden, p.Trump FROM Penna p;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET @FINISHED := 1;
    SET @FINISHED := 0;
	
	DROP TABLE IF EXISTS newPenna CASCADE;
    
    CREATE TABLE `newPenna` (
		`precinct` varchar(100) DEFAULT NULL,
		`Timestamp` datetime DEFAULT NULL,
		`newvotes` int DEFAULT NULL,
		`new_Biden` int DEFAULT NULL,
		`new_Trump` int DEFAULT NULL,
		KEY `indtemp` (`Timestamp`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
    
    OPEN CURR;
    
    label : LOOP
    
		FETCH CURR INTO TIMESTAMPP, PRECINCT, NEWVOTES, NEW_BIDEN, NEW_TRUMP;
        
        IF (@FINISHED = 1) THEN
			LEAVE label;
		END IF;
        
		SET @EXISTSPREVTIME := (EXISTS(SELECT DISTINCT p.Timestamp FROM Penna p WHERE p.precinct = PRECINCT AND p.Timestamp < TIMESTAMPP ORDER BY p.Timestamp DESC LIMIT 1));
        
        IF (@EXISTSPREVTIME = FALSE) THEN
			INSERT INTO newPenna (precinct, Timestamp, newvotes, new_Biden, new_Trump) VALUES (PRECINCT, TIMESTAMPP, NEWVOTES, NEW_BIDEN, NEW_TRUMP);
		ELSE
			BEGIN
				SET @PREVTIME := (SELECT DISTINCT p.Timestamp FROM Penna p WHERE p.precinct = PRECINCT AND p.Timestamp < TIMESTAMPP ORDER BY p.Timestamp DESC LIMIT 1);
				SELECT DISTINCT p.totalvotes, p.Biden, p.Trump INTO @TOTAL, @BIDEN, @TRUMP FROM Penna p WHERE p.Timestamp = @PREVTIME AND p.precinct = PRECINCT;
				INSERT INTO newPenna (precinct, Timestamp, newvotes, new_Biden, new_Trump) VALUES (PRECINCT, TIMESTAMPP, NEWVOTES - @TOTAL, NEW_BIDEN - @BIDEN, NEW_TRUMP - @TRUMP);
            END;
		END IF;

	END LOOP label;
    
    CLOSE CURR;

END; $$
DELIMITER ;



DELIMITER $$
DROP PROCEDURE IF EXISTS Switch $$
CREATE PROCEDURE Switch ()
proc : BEGIN

	DECLARE TIMESTAMPP DATETIME;
    DECLARE PRECINCT VARCHAR(100);
    DECLARE BIDEN INT;
    DECLARE TRUMP INT;
    DECLARE MAX_T DATETIME DEFAULT (SELECT DISTINCT p.Timestamp FROM Penna p ORDER BY p.Timestamp DESC LIMIT 1);
    DECLARE T_LIMIT DATETIME DEFAULT (SELECT DISTINCT p.Timestamp FROM Penna p WHERE p.Timestamp <= (MAX_T - INTERVAL 24 HOUR) ORDER BY p.Timestamp DESC LIMIT 1);
	DECLARE CURR CURSOR FOR SELECT DISTINCT p.Timestamp, p.precinct, p.Biden, p.Trump FROM Penna p WHERE p.Timestamp >= T_LIMIT AND p.Timestamp < MAX_T ORDER BY p.Timestamp DESC;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET @FINISHED := 1;
    SET @FINISHED := 0;
    
    DROP TABLE IF EXISTS Result CASCADE;
    
    CREATE TEMPORARY TABLE `Result` (
		`precinct` varchar(100) DEFAULT NULL,
		`Timestamp` datetime DEFAULT NULL,
		`fromCandidate` varchar(7) DEFAULT NULL,
		`toCandidate` varchar(7) DEFAULT NULL,
		KEY `indtemp` (`Timestamp`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
    
    OPEN CURR;
    
    label : LOOP
    
		FETCH CURR INTO TIMESTAMPP, PRECINCT, BIDEN, TRUMP;
        
        IF (@FINISHED = 1) THEN
			LEAVE label;
		END IF;
        
        SELECT DISTINCT p.Biden, p.Trump INTO @MAX_BIDEN, @MAX_TRUMP FROM Penna p WHERE p.Timestamp = MAX_T AND p.precinct = PRECINCT;
        
        SET @RESULT_HAS_PRECINCT := (EXISTS(SELECT DISTINCT r.precinct FROM Result r WHERE r.precinct = PRECINCT));
        
        IF (@MAX_TRUMP >= @MAX_BIDEN) THEN
			BEGIN
				IF (BIDEN > TRUMP) THEN
					BEGIN
						IF (@RESULT_HAS_PRECINCT = FALSE) THEN
							INSERT INTO Result (precinct, Timestamp, fromCandidate, toCandidate) VALUES (PRECINCT, TIMESTAMPP, "Biden", "Trump");
                        END IF;
                    END;
				END IF;
			END;
		ELSE
			BEGIN
				IF (TRUMP >= BIDEN) THEN
					BEGIN
						IF (@RESULT_HAS_PRECINCT = FALSE) THEN
							INSERT INTO Result (precinct, Timestamp, fromCandidate, toCandidate) VALUES (PRECINCT, TIMESTAMPP, "Trump", "Biden");
                        END IF;
                    END;
                END IF;
            END;
        END IF;

	END LOOP label;
    
    CLOSE CURR;
    
    SELECT DISTINCT * FROM Result;
    
    DROP TABLE IF EXISTS Result CASCADE;

END; $$
DELIMITER ;



DELIMITER $$
DROP PROCEDURE IF EXISTS PART_3A $$
CREATE PROCEDURE PART_3A (OUT BOO BOOLEAN)
proc : BEGIN

	SET BOO := (NOT EXISTS(SELECT DISTINCT * FROM Penna p WHERE p.Trump + p.Biden > p.totalvotes));

END; $$
DELIMITER ;



DELIMITER $$
DROP PROCEDURE IF EXISTS PART_3B $$
CREATE PROCEDURE PART_3B (OUT BOO BOOLEAN)
proc : BEGIN

	SET BOO := (NOT EXISTS(SELECT DISTINCT * FROM Penna p WHERE p.Timestamp >= '2020-11-12 00:00:00' OR p.Timestamp < '2020-11-03 00:00:00'));

END; $$
DELIMITER ;



DELIMITER $$
DROP PROCEDURE IF EXISTS PART_3C $$
CREATE PROCEDURE PART_3C (OUT BOO BOOLEAN)
proc : BEGIN

	DECLARE TIMESTAMPP DATETIME;
    DECLARE PRECINCT VARCHAR(100);
    DECLARE TOTAL INT;
	DECLARE CURR CURSOR FOR SELECT DISTINCT p.Timestamp, p.precinct, p.totalvotes FROM Penna p WHERE p.Timestamp LIKE '2020-11-05%';
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET @FINISHED := 1;
    SET @FINISHED := 0;
    
    OPEN CURR;
    
    label : LOOP
    
		FETCH CURR INTO TIMESTAMPP, PRECINCT, TOTAL;
        
        IF (@FINISHED = 1) THEN
			LEAVE label;
		END IF;
        
		SET @EXISTSPREVTIME := (EXISTS(SELECT DISTINCT p.Timestamp FROM Penna p WHERE p.precinct = PRECINCT AND p.Timestamp < TIMESTAMPP AND p.Timestamp LIKE '2020-11-05%' ORDER BY p.Timestamp DESC LIMIT 1));
        
        IF (@EXISTSPREVTIME = TRUE) THEN
			BEGIN
				SET @PREVTIME := (SELECT DISTINCT p.Timestamp FROM Penna p WHERE p.precinct = PRECINCT AND p.Timestamp < TIMESTAMPP AND p.Timestamp LIKE '2020-11-05%' ORDER BY p.Timestamp DESC LIMIT 1);
                SELECT DISTINCT p.totalvotes INTO @PREVTOTAL FROM Penna p WHERE p.Timestamp = @PREVTIME AND p.precinct = PRECINCT;
                IF (TOTAL < @PREVTOTAL) THEN
					BEGIN
						SET BOO := FALSE;
                        CLOSE CURR;
						LEAVE proc;
					END;
				END IF;
            END;
		END IF;

	END LOOP label;
    
    CLOSE CURR;
    
	SET BOO := TRUE;

END; $$
DELIMITER ;



DELIMITER $$
DROP PROCEDURE IF EXISTS TRIG $$
CREATE PROCEDURE TRIG ()
proc : BEGIN

	DROP TABLE IF EXISTS Updated_Tuples CASCADE;
    
    CREATE TABLE `Updated_Tuples` (
		`ID` int DEFAULT NULL,
		`Timestamp` datetime DEFAULT NULL,
		`state` varchar(10) DEFAULT NULL,
		`locality` varchar(100) DEFAULT NULL,
		`precinct` varchar(100) DEFAULT NULL,
		`geo` varchar(100) DEFAULT NULL,
		`totalvotes` int DEFAULT NULL,
		`Biden` int DEFAULT NULL,
		`Trump` int DEFAULT NULL,
		`filestamp` varchar(200) DEFAULT NULL,
		KEY `indtemp` (`Timestamp`)
	) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
    
    DROP TABLE IF EXISTS Inserted_Tuples CASCADE;
    
    CREATE TABLE `Inserted_Tuples` (
		`ID` int DEFAULT NULL,
		`Timestamp` datetime DEFAULT NULL,
		`state` varchar(10) DEFAULT NULL,
		`locality` varchar(100) DEFAULT NULL,
		`precinct` varchar(100) DEFAULT NULL,
		`geo` varchar(100) DEFAULT NULL,
		`totalvotes` int DEFAULT NULL,
		`Biden` int DEFAULT NULL,
		`Trump` int DEFAULT NULL,
		`filestamp` varchar(200) DEFAULT NULL,
		KEY `indtemp` (`Timestamp`)
	) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
    
    DROP TABLE IF EXISTS Deleted_Tuples CASCADE;
    
    CREATE TABLE `Deleted_Tuples` (
		`ID` int DEFAULT NULL,
		`Timestamp` datetime DEFAULT NULL,
		`state` varchar(10) DEFAULT NULL,
		`locality` varchar(100) DEFAULT NULL,
		`precinct` varchar(100) DEFAULT NULL,
		`geo` varchar(100) DEFAULT NULL,
		`totalvotes` int DEFAULT NULL,
		`Biden` int DEFAULT NULL,
		`Trump` int DEFAULT NULL,
		`filestamp` varchar(200) DEFAULT NULL,
		KEY `indtemp` (`Timestamp`)
	) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

END; $$
DELIMITER ;

CALL TRIG();

DROP TRIGGER IF EXISTS Update_Trigger;
    
CREATE TRIGGER Update_Trigger BEFORE UPDATE ON Penna
FOR EACH ROW
INSERT INTO Updated_Tuples (ID, Timestamp, state, locality, precinct, geo, totalvotes, Biden, Trump, filestamp) VALUES (
	OLD.ID,
	OLD.Timestamp,
	OLD.state,
	OLD.locality,
	OLD.precinct,
	OLD.geo,
	OLD.totalvotes,
	OLD.Biden,
	OLD.Trump,
	OLD.filestamp
);

DROP TRIGGER IF EXISTS Insert_Trigger;

CREATE TRIGGER Insert_Trigger BEFORE INSERT ON Penna
FOR EACH ROW
INSERT INTO Inserted_Tuples (ID, Timestamp, state, locality, precinct, geo, totalvotes, Biden, Trump, filestamp) VALUES (
	NEW.ID,
	NEW.Timestamp,
	NEW.state,
	NEW.locality,
	NEW.precinct,
	NEW.geo,
	NEW.totalvotes,
	NEW.Biden,
	NEW.Trump,
	NEW.filestamp
);

DROP TRIGGER IF EXISTS Delete_Trigger;

CREATE TRIGGER Delete_Trigger BEFORE DELETE ON Penna
FOR EACH ROW
INSERT INTO Deleted_Tuples (ID, Timestamp, state, locality, precinct, geo, totalvotes, Biden, Trump, filestamp) VALUES (
	OLD.ID,
	OLD.Timestamp,
	OLD.state,
	OLD.locality,
	OLD.precinct,
	OLD.geo,
	OLD.totalvotes,
	OLD.Biden,
	OLD.Trump,
	OLD.filestamp
);



DELIMITER $$
DROP PROCEDURE IF EXISTS MoveVotes $$
CREATE PROCEDURE MoveVotes (IN PRECINCT VARCHAR(100), IN TIMESTAMPP CHAR(19), IN CANDIDATE CHAR(5), IN Number_of_Moved_Votes INT)
proc : BEGIN

	DECLARE EXIT HANDLER FOR 1525
	BEGIN
        SELECT DISTINCT 'incorrect timestamp' Exception;
	END;
    SET @WRONGT := (SELECT DISTINCT p.Timestamp FROM Penna p WHERE p.Timestamp = TIMESTAMPP LIMIT 1);

	IF (CANDIDATE != 'Trump' AND CANDIDATE != 'Biden') THEN
		BEGIN
			SELECT DISTINCT 'wrong candidate name' Exception;
            LEAVE proc;
        END;
    END IF;
    
    SET @PRECINCT_EXISTS := (EXISTS(SELECT DISTINCT p.precinct FROM Penna p WHERE p.precinct = PRECINCT));
    IF (@PRECINCT_EXISTS = FALSE) THEN
		BEGIN
			SELECT DISTINCT 'wrong precinct name' Exception;
            LEAVE proc;
        END;
    END IF;
    
    SET @TIME_EXISTS_FOR_PRECINCT := (EXISTS(SELECT DISTINCT p.Timestamp FROM Penna p WHERE p.precinct = PRECINCT AND p.Timestamp = TIMESTAMPP));
    
    IF (@TIME_EXISTS_FOR_PRECINCT = FALSE) THEN
		BEGIN
			SELECT DISTINCT 'not existing timestamp' Exception;
            LEAVE proc;
        END;
    END IF;

	IF (Number_of_Moved_Votes <= 0) THEN
		BEGIN
			SELECT DISTINCT 'number of moved votes must be positive integer' Exception;
            LEAVE proc;
        END;
    END IF;
    
    IF (CANDIDATE = 'Trump') THEN
		SELECT DISTINCT p.Trump INTO @CANDIDATE_VOTES FROM Penna p WHERE p.precinct = PRECINCT AND p.Timestamp = TIMESTAMPP;
	ELSE
		SELECT DISTINCT p.Biden INTO @CANDIDATE_VOTES FROM Penna p WHERE p.precinct = PRECINCT AND p.Timestamp = TIMESTAMPP;
    END IF;
    
    IF (Number_of_Moved_Votes > @CANDIDATE_VOTES) THEN
		BEGIN
			SELECT DISTINCT 'Not enough votes' Exception;
            LEAVE proc;
        END;
    END IF;
    
	IF (CANDIDATE = "Trump") THEN
		SET @OTHER := "Biden";
	ELSE
		SET @OTHER := "Trump";
	END IF;

    SET @PREPARED := CONCAT("UPDATE Penna SET ", CANDIDATE, " = (", CANDIDATE, " - ", Number_of_Moved_Votes, "), ", @OTHER, " = (", @OTHER, " + ", Number_of_Moved_Votes, ") WHERE precinct = '", PRECINCT, "' AND Timestamp >= '", TIMESTAMPP, "'");

	PREPARE statement FROM @PREPARED;
    EXECUTE statement;
    DEALLOCATE PREPARE statement;

END; $$
DELIMITER ;



-- PART 1

-- CALL API1("Trump", "2020-11-04 03:58:36", "Adams Township - Dunlo Voting Precinct");

-- CALL API1("Trump", "2020-11-04 03:58:36", "Adams Township - Dunlo Voting People");

-- CALL API2('2020-11-04');

-- CALL API2('04-11-2020');

-- CALL API3("Trump");

-- CALL API3("Drumm");

-- CALL API4("Adams Township - Dunlo Voting Precinct");

-- CALL API4("Adams Township - Dunlo Vote Precinct");

-- CALL API5("Township");

-- CALL API5("Township YO");



-- PART 4.1

-- INSERT INTO Penna (precinct) VALUES ("ALRIGHT COOL");

-- UPDATE Penna SET precinct = "GRAND FINALE" WHERE precinct = "ALRIGHT COOL";

-- DELETE FROM Penna WHERE precinct = "GRAND FINALE";

-- INSERT INTO Penna (precinct, Timestamp, totalvotes, Biden, Trump) VALUES ("FREE STATE OF FLORIDA", '2022-11-08 00:00:00', 1100, 100, 1000);

-- UPDATE Penna SET precinct = "AWESOME" WHERE precinct = "Ashville Borough Voting Precinct";

-- DELETE FROM Penna WHERE precinct = "Allegheny Township Voting Precinct";

-- DELETE FROM Penna WHERE precinct = 'FREE STATE OF FLORIDA';



-- PART 4.2

-- CALL MoveVotes('Adams Township - Dunlo Voting Precinct', '2020-11-04 03:58:36', 'Biden', 10);

-- CALL MoveVotes('Adams Township - Dunlo Voting Precinct', '11-2020-04 03:58:36', 'Biden', 10);

-- CALL MoveVotes('Adams Township - Dunlo Voting Precinct', '2020-11-04 03:58:36', 'Bhide', 10);

-- CALL MoveVotes('Adams Township - Dunlo Voting P', '2020-11-04 03:58:36', 'Biden', 10);

-- CALL MoveVotes('Adams Township - Dunlo Voting Precinct', '2020-11-04 03:57:36', 'Biden', 10);

-- CALL MoveVotes('Adams Township - Dunlo Voting Precinct', '2020-11-04 03:58:36', 'Biden', -1);

-- CALL MoveVotes('Adams Township - Dunlo Voting Precinct', '2020-11-04 03:58:36', 'Biden', 1000000);




