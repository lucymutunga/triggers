--Books table
CREATE TABLE Books(
	BookID INT PRIMARY KEY,
	Title VARCHAR(100) NOT NULL,
	Author VARCHAR(100) NOT NULL,
	PublicationYear INT,
	Status VARCHAR(20) NOT NULL
	);
INSERT INTO Books (BookID, Title, Author, PublicationYear, Status)
VALUES (1, 'Book 1', 'Author 1', 2020, 'Available'),
       (2, 'Book 2', 'Author 2', 2018, 'Available'),
       (3, 'Book 3', 'Author 3', 2019, 'Available'),
       (4, 'Book 4', 'Author 4', 2021, 'Available');

-- Members table
CREATE TABLE Members (
	MemberID INT PRIMARY KEY,
	Name VARCHAR(100) NOT NULL,
	Address VARCHAR(100),
	ContactNumber VARCHAR(20) NOT NULL
	);
INSERT INTO Members (MemberID, Name, Address, ContactNumber)
VALUES (1, 'Member 1', 'Address 1', '1234567890'),
       (2, 'Member 2', 'Address 2', '9876543210'),
       (3, 'Member 3', 'Address 3', '4567891230');
--Loans table
CREATE TABLE Loans(
	LoanID INT PRIMARY KEY,
	BookID INT NOT NULL,
	MemberID INT NOT NULL,
	LoanDate DATE NOT NULL,
	ReturnDate DATE,
	FOREIGN KEY (BOOKID) REFERENCES Books (BookID),
	FOREIGN KEY (MemberID) REFERENCES Members (MemberID)
	);

INSERT INTO Loans (LoanID, BookID, MemberID, LoanDate, ReturnDate)
VALUES (1, 1, 1, '2023-06-01', '2023-06-10'),
       (2, 2, 1, '2023-06-03', '2023-06-12'),
       (3, 3, 1, '2023-06-05', NULL),
       (4, 4, 2, '2023-06-02', '2023-06-09');

-- A trigger that automatically updates the status column in the books table whenever a book is loaned or returned 

-- Create the book_audits table
CREATE TABLE book_audits (
    audit_id INT IDENTITY(1,1) PRIMARY KEY,
    book_id INT,
    title VARCHAR(100),
    author VARCHAR(100),
    publication_year INT,
    status VARCHAR(50),
    updated_at DATETIME,
    operation VARCHAR(3)
);


-- Create the trigger
CREATE TRIGGER trg_book_audit
	ON Books
	AFTER INSERT, UPDATE, DELETE
	AS
BEGIN
    SET NOCOUNT ON;

    -- Insert audit records for inserted books
    INSERT INTO book_audits (book_id, title, author, publication_year, status, updated_at, operation)
    SELECT BookID, Title, Author, PublicationYear, Status, GETDATE(), 'INS'
    FROM inserted;

    -- Insert audit records for updated books
    INSERT INTO book_audits (book_id, title, author, publication_year, status, updated_at, operation)
    SELECT BookID, Title, Author, PublicationYear, Status, GETDATE(), 'UPD'
    FROM inserted
    WHERE EXISTS (
        SELECT 1
        FROM deleted
        WHERE deleted.BookID = inserted.BookID
    );

    -- Insert audit records for deleted books
    INSERT INTO book_audits (book_id, title, author, publication_year, status, updated_at, operation)
    SELECT BookID, Title, Author, PublicationYear, Status, GETDATE(), 'DEL'
    FROM deleted;
END;

  

--CTE that retrieves the names of all members who have borrowed at least three books.
WITH MemberBorrowCounts AS (
    SELECT MemberID, COUNT(*) AS BorrowCount
    FROM Loans
    GROUP BY MemberID
    HAVING COUNT(*) >= 3
)
SELECT m.Name
	FROM Members m
	JOIN MemberBorrowCounts c ON m.MemberID = c.MemberID;

--user-defined function that calculates the overdue days for a given loan.
CREATE FUNCTION dbo.CalculateOverdueDays (@LoanID INT)
	RETURNS INT
	AS
	BEGIN
    DECLARE @OverdueDays INT;
    
    SELECT @OverdueDays = DATEDIFF(DAY, LoanDate, GETDATE())
    FROM Loans
    WHERE LoanID = @LoanID;
    
    
    IF @OverdueDays IS NULL OR @OverdueDays <= 0
        SET @OverdueDays = 0;
    
    RETURN @OverdueDays;
END;

--view that displays the details of all overdue loans, including the book title, member name, and number of overdue days.
CREATE VIEW dbo.OverdueLoansView AS
	SELECT B.Title AS BookTitle, M.Name AS MemberName, DATEDIFF(DAY, L.LoanDate, GETDATE()) AS OverdueDays
	FROM Loans L
	JOIN Books B ON L.BookID = B.BookID
	JOIN Members M ON L.MemberID = M.MemberID
	WHERE L.ReturnDate IS NULL AND GETDATE() > L.ReturnDate;

SELECT *
	FROM dbo.OverdueLoansView;


--trigger that prevents a member from borrowing more than three books at a time.
CREATE TRIGGER trg_PreventExcessiveBorrowing
	ON Loans
	INSTEAD OF INSERT
AS
	BEGIN
    -- Calculate the total number of books already borrowed by the member
    DECLARE @MemberID INT;
    DECLARE @BorrowedCount INT;

    SELECT @MemberID = MemberID
    FROM inserted;

    SELECT @BorrowedCount = COUNT(*)
    FROM Loans
    WHERE MemberID = @MemberID;

    -- Check if the member is trying to borrow more than three books
    IF (@BorrowedCount + (SELECT COUNT(*) FROM inserted)) > 3
    BEGIN
        RAISERROR ('The member already has three books on loan. Cannot borrow more.', 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END;

    -- If the member is not exceeding the limit, proceed with the insert
    INSERT INTO Loans (BookID, MemberID, LoanDate, ReturnDate)
    SELECT BookID, MemberID, LoanDate, ReturnDate
    FROM inserted;
END;

